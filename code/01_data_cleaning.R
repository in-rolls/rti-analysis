# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 01_data_cleaning.R
### Builds the one-row-per-application analysis file from the frozen snapshot in data/raw/.
### Stops if the key counts change, so a new snapshot cannot pass silently.
# ----
pacman::p_load(dplyr, tidyr, purrr, readr, stringr, forcats, lubridate, here)

source(here("code", "00_config.R"))
source(here("code", "00_utils.R"))

read_raw <- function(f) {
  read_csv(here("data", "raw", SNAPSHOT, f),
    col_types = cols(.default = "c"),
    show_col_types = FALSE
  )
}

# Verify the snapshot ----
## A mismatch is an error, never a silent substitution.
manifest <- read_raw("MANIFEST.csv")
actual_md5 <- unname(tools::md5sum(here("data", "raw", SNAPSHOT, manifest$file)))
if (!identical(actual_md5, manifest$md5)) {
  stop(
    "Snapshot files do not match MANIFEST.csv: ",
    paste(manifest$file[actual_md5 != manifest$md5], collapse = ", ")
  )
}

panel <- read_raw("status_panel.csv")
events <- read_raw("events.csv")
coded <- read_raw("responses_coded.csv")
assign_tn <- read_raw("assignments_tn.csv")
assign_other <- read_raw("assignments_other.csv")
corrections <- read_csv(here("data", "raw", "manual_corrections.csv"),
  col_types = cols(.default = "c"), show_col_types = FALSE
)
calls <- read_csv(here("data", "raw", "phone_calls.csv"),
  col_types = cols(.default = "c"),
  show_col_types = FALSE
)

# Hand corrections to coded replies ----
## Move a reply filed under the wrong application id
moves <- corrections |>
  filter(action == "add_coded_reply_from") |>
  select(to = app_id, from = value)

coded <- coded |>
  left_join(moves, by = c("app_id" = "from")) |>
  mutate(app_id = coalesce(to, app_id)) |>
  select(-to)

stopifnot(!any(duplicated(coded$app_id)))

# Assignments and randomization blocks ----
## Tamil Nadu: treatment balanced within department x tier, so the block is that stratum.
## Other states: the samplers shuffle over the whole batch (state x batch), so that is the block.
## Department group is a sampling stratum there, not a randomization block.
assignments <- bind_rows(assign_tn, assign_other) |>
  rename(app_id = application_id) |>
  mutate(
    state = str_sub(app_id, 1, 2),
    tn = state == "TN",
    legal = as.integer(treatment == "legal_salience"),
    block = if_else(tn, stratum, paste(state, batch_id)),
    dept_group = paste(state, dept),
    phone_filer = as.integer(assigned_ra %in% c("RA2", "RA4"))
  )

stopifnot(!any(duplicated(assignments$app_id)), nrow(assignments) == 1665)

# Government function, coded from department and office names ----
## First match wins. Tamil Nadu uses its department tree. Other states use the department group,
## and the office name only when the group alone is uninformative.
assignments <- assignments |>
  mutate(
    function_dept = code_function(dept),
    function_office = code_function(office_name),
    function_name = if_else(tn | function_dept != OTHER_FUNCTION, function_dept, function_office)
  ) |>
  select(-function_dept, -function_office)

# Tracker dates ----
first_event <- function(kinds, name) {
  events |>
    filter(kind %in% kinds) |>
    mutate(date = to_date(date)) |>
    group_by(app_id) |>
    summarise(!!name := min(date, na.rm = TRUE), .groups = "drop")
}

applications <- panel |>
  transmute(app_id,
    panel_treatment = treatment,
    filed = as.integer(filed == "True"),
    filing_date = to_date(filing_date),
    date_notice = to_date(first_response),
    transferred_on = to_date(transferred_on),
    fee_demanded_on = to_date(fee_demanded_on),
    disposed_on = to_date(disposed_on),
    returned_on = to_date(returned_on),
    rejected_on = to_date(rejected_on),
    email_response_on = to_date(email_response_on),
    fee_amount_inr = as.numeric(fee_amount_inr)
  ) |>
  left_join(first_event("transferred", "first_transfer"), by = "app_id") |>
  left_join(first_event("fee_demand", "first_fee"), by = "app_id") |>
  mutate(
    filing_date = if_else(filed == 1L, filing_date, as.Date(NA)),
    date_transfer = coalesce(first_transfer, transferred_on),
    date_fee = coalesce(first_fee, fee_demanded_on)
  )

## Portal reply recorded only in an RA note
added_notices <- corrections |>
  filter(action == "add_portal_reply") |>
  transmute(app_id, added = as.Date(value))

applications <- applications |>
  left_join(added_notices, by = "app_id") |>
  mutate(date_notice = pmin(date_notice, added, na.rm = TRUE)) |>
  select(-added)

# Coded replies ----
coded_clean <- coded |>
  transmute(app_id, authority,
    coded_response_date = to_date(response_date),
    medium, disposition, granularity, q3_sec25,
    fee_inr = as.numeric(fee_inr), fee_pages = as.numeric(fee_pages), fee_channel,
    supplied_by_email = as.integer(supplied_by_email),
    clause_cited, appeal_candidate = as.integer(appeal_candidate),
    confidence
  )

# Merge ----
rti <- assignments |>
  left_join(applications, by = "app_id") |>
  left_join(coded_clean, by = "app_id") |>
  mutate(
    coded = as.integer(!is.na(disposition)),
    date_doc = if_else(coded == 1L, coalesce(coded_response_date, date_notice), as.Date(NA))
  )

stopifnot(nrow(rti) == 1665, all(rti$treatment == rti$panel_treatment))

# Outcome dates ----
## Any response: earliest office action of any kind.
## Reply: the same without transfers. A document coded as a transfer is not a reply.
## Information supplied: coded full or partial, a lower bound while some replies are uncoded.
rti <- rti |>
  mutate(
    date_any = pmin(date_notice, date_transfer, date_fee, date_doc, na.rm = TRUE),
    date_reply = if_else(coalesce(disposition == "transferred", FALSE), as.Date(NA),
      pmin(date_notice, date_fee, date_doc, na.rm = TRUE)
    ),
    date_info = if_else(coalesce(disposition %in% c("full", "partial"), FALSE), date_doc,
      as.Date(NA)
    ),
    exposure = as.integer(AS_OF - filing_date),
    days_any = as.integer(date_any - filing_date),
    days_reply = as.integer(date_reply - filing_date),
    days_info = as.integer(date_info - filing_date),
    past30 = as.integer(coalesce(exposure >= 30, FALSE))
  )

## Response by each horizon, defined only for applications exposed that long
for (h in HORIZONS) {
  for (y in c("any", "reply", "info")) {
    days <- rti[[paste0("days_", y)]]
    rti[[paste0(y, "_", h)]] <- case_when(
      is.na(rti$exposure) | rti$exposure < h ~ NA_real_,
      !is.na(days) & days <= h ~ 100,
      TRUE ~ 0
    )
  }
}

# Survival time ----
## Time to first response, right-censored at the data date. A same-day reply gets half a day.
rti <- rti |>
  mutate(
    km_event = as.integer(!is.na(days_any)),
    km_time = pmax(if_else(km_event == 1L, days_any, exposure), 0.5)
  )

# Status as of the data date ----
rti <- rti |>
  mutate(
    outcome = case_when(
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
    outcome = factor(outcome, levels = OUTCOME_LEVELS)
  )

# Filing cohorts ----
rti <- rti |>
  mutate(
    filing_week = as.character(floor_date(filing_date, "week", week_start = 1)),
    filing_month = format(filing_date, "%Y-%m")
  )

# Phone calls ----
## Only RA2 and RA4 could receive calls. Calls after the data date are left out.
calls_clean <- calls |>
  mutate(call_date = to_date(call_date)) |>
  filter(is.na(call_date) | call_date <= AS_OF) |>
  transmute(app_id, call_date, call_type = type, phone_call = 1L)

rti <- rti |>
  left_join(calls_clean, by = "app_id") |>
  mutate(phone_call = coalesce(phone_call, 0L))

# Labels ----
rti <- rti |>
  mutate(
    state_name = factor(STATE_LABELS[state], levels = STATE_LABELS),
    as_of = AS_OF
  ) |>
  select(-panel_treatment, -first_transfer, -first_fee)

# Checks: stop if the numbers below move ----
stopifnot(
  sum(rti$filed) == 1000,
  sum(!is.na(rti$filing_date)) == 999,
  sum(rti$past30) == 455,
  all(table(rti$state[rti$past30 == 1]) == c(DL = 22, KA = 78, MH = 28, TG = 187, TN = 140)),
  all(is.na(rti$days_any) | rti$days_any >= 0),
  all(is.na(rti$date_any) | rti$date_any <= AS_OF),
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
dir.create(here("data", "cleaned"), showWarnings = FALSE, recursive = TRUE)
write_rds(rti, here("data", "cleaned", "analysis.rds"))
write_csv(rti, here("data", "cleaned", "analysis.csv"), na = "")

## Crosswalk so the function coding can be reviewed by hand
rti |>
  count(function_name, state, dept, name = "n_drawn") |>
  arrange(function_name, state, desc(n_drawn)) |>
  write_csv(here("data", "cleaned", "function_crosswalk.csv"))

cat(
  "Analysis file:", nrow(rti), "applications,", sum(rti$filed), "filed,", sum(rti$past30),
  "past day 30\n"
)
