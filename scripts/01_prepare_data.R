read_character_csv <- function(...) {
  readr::read_csv(here::here("data", ...), col_types = readr::cols(.default = "c"), show_col_types = FALSE, na = "")
}

status <- read_character_csv("derived", "status.csv")
coded <- read_character_csv("hand", "responses_coded.csv")
corrections <- read_character_csv("hand", "manual_corrections.csv")
calls <- read_character_csv("hand", "phone_calls.csv")

# Reply coding: first pass, second coding, adjudication ----
## Two coders read each reply independently. Where they disagreed, an adjudicator who could not tell
## them apart settled the field from the documents. See docs/design.md for the rules.
second <- read_character_csv("hand", "second_coding.csv")
adjudicated <- read_character_csv("hand", "coding_adjudicated.csv")

coded <- dplyr::bind_rows(
  coded,
  second |>
    dplyr::filter(!app_id %in% coded$app_id) |>
    dplyr::select(app_id, response_date, disposition, granularity, q3_sec25, fee_inr, clause_cited)
)
## A letter with no legible date keeps the first-pass date, which came from its arrival: a reply
## with an unclear date is still a reply
for (i in seq_len(nrow(adjudicated))) {
  field <- adjudicated$field[i]
  value <- adjudicated$value[i]
  if (field == "response_date" && is.na(value)) next
  coded[[field]][coded$app_id == adjudicated$app_id[i]] <- value
}

## A file that turned out to hold no reply from the office is not a coded reply
not_replies <- corrections |>
  dplyr::filter(action == "not_a_reply") |>
  dplyr::pull(app_id)
coded <- coded |> dplyr::filter(!app_id %in% not_replies)

# Hand corrections to coded replies ----
## Move a reply filed under the wrong application id
moves <- corrections |>
  dplyr::filter(action == "add_coded_reply_from") |>
  dplyr::select(to = app_id, from = value)

coded <- coded |>
  dplyr::left_join(moves, by = c("app_id" = "from")) |>
  dplyr::mutate(app_id = dplyr::coalesce(to, app_id)) |>
  dplyr::select(-to)

stopifnot(!any(duplicated(coded$app_id)))

# Assignments and randomization blocks ----
## Tamil Nadu: treatment balanced within department x tier, so the block is that stratum.
## Other states: the samplers shuffle over the whole batch (state x batch), so that is the block.
## Department group is a sampling stratum there, not a randomization block.
assignments <- read_assignments() |>
  dplyr::mutate(
    tn = state == "TN",
    legal = as.integer(treatment == "legal_salience"),
    block = dplyr::if_else(tn, stratum, paste(state, batch_id)),
    dept_group = paste(state, dept),
    phone_filer = as.integer(assigned_ra %in% c("RA2", "RA4"))
  )

stopifnot(!any(duplicated(assignments$app_id)), nrow(assignments) == 1665)

# Government function, coded from department and office names ----
## First match wins. Tamil Nadu uses its department tree. Other states use the department group,
## and the office name only when the group alone is uninformative.
assignments <- assignments |>
  dplyr::mutate(
    function_dept = code_function(dept),
    function_office = code_function(office_name),
    function_name = dplyr::if_else(tn | function_dept != other_function, function_dept, function_office)
  ) |>
  dplyr::select(-function_dept, -function_office)

# Status from the original inputs ----
applications <- status |>
  dplyr::transmute(app_id,
    filed = as.integer(filed),
    filing_date = to_date(filing_date),
    ack_date = to_date(ack_date),
    date_notice = to_date(first_response),
    first_response_kind, first_response_method, first_response_confidence,
    date_transfer = to_date(first_transfer_on),
    transferred_on = to_date(transferred_on),
    date_fee = to_date(first_fee_on),
    fee_demanded_on = to_date(fee_demanded_on),
    disposed_on = to_date(disposed_on),
    returned_on = to_date(returned_on),
    rejected_on = to_date(rejected_on),
    email_response_on = to_date(email_response_on),
    fee_amount_inr = as.numeric(fee_amount_inr),
    reg_cell,
    n_reply_pdfs = as.integer(n_reply_pdfs),
    n_receipts = as.integer(n_receipts)
  )

## Portal reply recorded only in an RA note
added_notices <- corrections |>
  dplyr::filter(action == "add_portal_reply") |>
  dplyr::transmute(app_id, added = as.Date(value))

applications <- applications |>
  dplyr::left_join(added_notices, by = "app_id") |>
  dplyr::mutate(date_notice = pmin(date_notice, added, na.rm = TRUE)) |>
  dplyr::select(-added)

# Coded replies ----
coded_clean <- coded |>
  dplyr::transmute(app_id, authority,
    coded_response_date = to_date(response_date),
    medium, disposition, granularity, q3_sec25,
    fee_inr = as.numeric(fee_inr), fee_pages = as.numeric(fee_pages), fee_channel,
    supplied_by_email = as.integer(supplied_by_email),
    clause_cited, appeal_candidate = as.integer(appeal_candidate),
    confidence
  )

# Merge ----
rti <- assignments |>
  dplyr::left_join(applications, by = "app_id") |>
  dplyr::left_join(coded_clean, by = "app_id") |>
  dplyr::mutate(
    coded = as.integer(!is.na(disposition)),
    date_doc = dplyr::if_else(coded == 1L, dplyr::coalesce(coded_response_date, date_notice), as.Date(NA))
  )

stopifnot(nrow(rti) == 1665)

# Outcome dates ----
## Any response: earliest office action of any kind.
## Reply: the same without transfers. A document coded as a transfer is not a reply.
## Information supplied: coded full or partial, a lower bound while some replies are uncoded.
rti <- rti |>
  dplyr::mutate(
    date_any = pmin(date_notice, date_transfer, date_fee, date_doc, na.rm = TRUE),
    date_reply = dplyr::if_else(dplyr::coalesce(disposition == "transferred", FALSE), as.Date(NA),
      pmin(date_notice, date_fee, date_doc, na.rm = TRUE)
    ),
    date_info = dplyr::if_else(dplyr::coalesce(disposition %in% c("full", "partial"), FALSE), date_doc,
      as.Date(NA)
    ),
    exposure = as.integer(as_of - filing_date),
    days_any = as.integer(date_any - filing_date),
    days_reply = as.integer(date_reply - filing_date),
    days_info = as.integer(date_info - filing_date),
    past30 = as.integer(dplyr::coalesce(exposure >= 30, FALSE))
  )

## Response by each horizon, defined only for applications exposed that long
for (h in horizons) {
  for (y in c("any", "reply", "info")) {
    days <- rti[[paste0("days_", y)]]
    rti[[paste0(y, "_", h)]] <- dplyr::case_when(
      is.na(rti$exposure) | rti$exposure < h ~ NA_real_,
      !is.na(days) & days <= h ~ 100,
      TRUE ~ 0
    )
  }
}

## Bound for the robustness table: treat a first response that rests only on a low-confidence email
## match as no response, even where a reply document is on file
rti <- rti |>
  dplyr::mutate(any_strict_30 = dplyr::if_else(
    dplyr::coalesce(first_response_confidence == "low", FALSE) & !is.na(any_30), 0, any_30
  ))

# Survival time ----
## Time to first response, right-censored at the data date. A same-day reply gets half a day.
rti <- rti |>
  dplyr::mutate(
    km_event = as.integer(!is.na(days_any)),
    km_time = pmax(dplyr::if_else(km_event == 1L, days_any, exposure), 0.5)
  )

# Status as of the data date ----
rti <- rti |>
  dplyr::mutate(
    outcome = dplyr::case_when(
      filed == 0L ~ NA_character_,
      disposition == "full" ~ "Full information",
      disposition == "partial" ~ "Partial information",
      disposition == "fee_pending" ~ "Fee demanded",
      disposition == "denied" ~ "Denied",
      disposition == "returned" ~ "Returned",
      disposition == "transferred" ~ "Transferred",
      !is.na(rejected_on) ~ "Denied",
      !is.na(returned_on) ~ "Returned",
      !is.na(date_fee) ~ "Fee demanded",
      !is.na(date_notice) ~ "Reply, not yet coded",
      !is.na(date_transfer) ~ "Transferred",
      TRUE ~ "No response"
    ),
    outcome = factor(outcome, levels = outcome_levels)
  )

# Filing cohorts ----
rti <- rti |>
  dplyr::mutate(
    filing_week = as.character(lubridate::floor_date(filing_date, "week", week_start = 1)),
    filing_month = format(filing_date, "%Y-%m")
  )

# Phone calls ----
## Only RA2 and RA4 could receive calls. Calls after the data date are left out.
calls_clean <- calls |>
  dplyr::mutate(call_date = to_date(call_date)) |>
  dplyr::filter(is.na(call_date) | call_date <= as_of) |>
  dplyr::transmute(app_id, call_date, call_type = type, phone_call = 1L)

rti <- rti |>
  dplyr::left_join(calls_clean, by = "app_id") |>
  dplyr::mutate(phone_call = dplyr::coalesce(phone_call, 0L))

# Labels ----
rti <- rti |>
  dplyr::mutate(
    state_name = factor(state_labels[state], levels = state_labels),
    as_of = as_of
  )

# Checks: stop if the numbers below move ----
stopifnot(
  sum(rti$filed) == 996,
  sum(!is.na(rti$filing_date)) == 996,
  sum(rti$past30) == 455,
  all(table(rti$state[rti$past30 == 1]) == c(DL = 22, KA = 78, MH = 28, TG = 187, TN = 140)),
  all(is.na(rti$days_any) | rti$days_any >= 0),
  all(is.na(rti$date_any) | rti$date_any <= as_of),
  all(rti$filed[!is.na(rti$date_any)] == 1L),
  all(rti$phone_filer[rti$phone_call == 1L] == 1L),
  all(rti$filed[rti$phone_call == 1L] == 1L),
  sum(rti$phone_call) == 9,
  sum(rti$coded) == 104,
  is.na(rti$disposition[rti$app_id == "TG-150"]),
  rti$disposition[rti$app_id == "TG-162"] == "full",
  all(rti$legal[rti$tn] %in% c(0L, 1L))
)

# Save ----
dir.create(here::here("data", "derived"), showWarnings = FALSE, recursive = TRUE)
readr::write_rds(rti, here::here("data", "derived", "analysis.rds"))
readr::write_csv(rti, here::here("data", "derived", "analysis.csv"), na = "")

## Crosswalk so the function coding can be reviewed by hand
rti |>
  dplyr::count(function_name, state, dept, name = "n_drawn") |>
  dplyr::arrange(function_name, state, dplyr::desc(n_drawn)) |>
  readr::write_csv(here::here("data", "derived", "function_crosswalk.csv"))

cat(
  "Analysis file:", nrow(rti), "applications,", sum(rti$filed), "filed,", sum(rti$past30),
  "past day 30\n"
)
