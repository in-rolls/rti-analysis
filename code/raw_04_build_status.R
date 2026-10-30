# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: raw_04_build_status.R
### Builds one row per drawn application from the matched messages and the RA register, plus the
### frame sizes and document counts. Everything written here is free of personal data.
# ----
pacman::p_load(dplyr, purrr, readr, stringr, lubridate, here)

source(here("code", "00_config.R"))
source(here("code", "00_utils.R"))
source(here("code", "raw_utils.R"))

raw_root <- path.expand(Sys.getenv("RTI_RAW"))
if (!nzchar(raw_root) || !dir.exists(raw_root)) stop("Set RTI_RAW to the shared Drive rti/ folder.")

events <- read_csv(here("data", "derived", "events.csv"),
  col_types = cols(date = "D", .default = "c"), show_col_types = FALSE, na = ""
) |>
  filter(!is.na(app_id), nzchar(app_id))
register <- read_rds(here("data", "private", "ra_register.rds"))
manifest <- read_csv(here("data", "raw_manifest.csv"), show_col_types = FALSE)
assignments <- read_assignments(here("data", "raw", "assignments"))

RESPONSE_KINDS <- c("pio_email", "disposed", "returned", "rejected")

first_date <- function(kinds) {
  picked <- events |> filter(kind %in% kinds)
  if (nrow(picked) == 0) {
    return(tibble(app_id = character(), value = as.Date(character())))
  }
  picked |>
    group_by(app_id) |>
    summarise(value = min(date), .groups = "drop")
}
last_date <- function(kinds) {
  picked <- events |> filter(kind %in% kinds)
  if (nrow(picked) == 0) {
    return(tibble(app_id = character(), value = as.Date(character())))
  }
  picked |>
    group_by(app_id) |>
    summarise(value = max(date), .groups = "drop")
}
add_date <- function(d, ev, name) {
  d |>
    left_join(ev, by = "app_id") |>
    rename(!!name := value)
}

## The first acknowledgement, and which message gave the first response
ack <- events |>
  filter(kind %in% c("filing_ack", "filing_ack_tg")) |>
  group_by(app_id) |>
  slice(1) |>
  ungroup() |>
  transmute(app_id, ack_date = date, ack_method = method)

response_events <- events |> filter(kind %in% RESPONSE_KINDS)
first_any <- response_events |>
  arrange(app_id, date) |>
  group_by(app_id) |>
  slice(1) |>
  ungroup() |>
  transmute(app_id,
    first_email_response = date, first_response_kind = kind,
    first_response_method = method, first_response_confidence = confidence
  )
first_strict <- response_events |>
  filter(confidence != "low") |>
  group_by(app_id) |>
  summarise(first_email_response_strict = min(date), .groups = "drop")

fee_amount <- events |>
  filter(kind == "fee_demand") |>
  group_by(app_id) |>
  slice(1) |>
  ungroup() |>
  transmute(app_id, fee_amount_inr)

# Documents in the archive ----
LOOSE_ID <- "\\b(TN|KA|TG|DL|MH)\\b[^0-9]{0,24}?(\\d{3,4})\\b"
id_from_name <- function(path) {
  m <- str_match(str_replace_all(str_to_upper(basename(path)), "_", "-"), LOOSE_ID)
  if_else(is.na(m[, 1]), NA_character_, sprintf("%s-%03d", m[, 2], as.integer(m[, 3])))
}
count_docs <- function(folder, name) {
  pinned_originals(raw_root, folder, manifest) |>
    mutate(app_id = id_from_name(path)) |>
    filter(!is.na(app_id)) |>
    count(app_id, name = name)
}

# One row per application ----
status <- assignments |>
  transmute(app_id, state) |>
  left_join(
    register |>
      transmute(app_id, group,
        reg_cell = case_when(real_reg ~ "number", has_reg ~ "text", TRUE ~ "empty"),
        sheet_filing_date, sheet_response_date
      ),
    by = "app_id"
  ) |>
  left_join(ack, by = "app_id") |>
  add_date(first_date("transferred"), "first_transfer_on") |>
  add_date(last_date("transferred"), "transferred_on") |>
  add_date(first_date("fee_demand"), "first_fee_on") |>
  add_date(last_date("fee_demand"), "fee_demanded_on") |>
  add_date(first_date("disposed"), "disposed_on") |>
  add_date(first_date("returned"), "returned_on") |>
  add_date(first_date("rejected"), "rejected_on") |>
  add_date(first_date("pio_email"), "email_response_on") |>
  add_date(first_date("appeal_ack"), "appeal_filed_on") |>
  left_join(first_any, by = "app_id") |>
  left_join(first_strict, by = "app_id") |>
  left_join(fee_amount, by = "app_id") |>
  left_join(count_docs("rti responses", "n_reply_pdfs"), by = "app_id") |>
  left_join(count_docs("Filed_RTI", "n_receipts"), by = "app_id") |>
  mutate(
    ## Filed means a real registration number on the sheet or a portal acknowledgement.
    ## A note typed into the number cell does not count.
    filed = as.integer(coalesce(reg_cell == "number", FALSE) | !is.na(ack_date)),
    filing_date = if_else(filed == 1L, coalesce(ack_date, sheet_filing_date), as.Date(NA)),
    filing_date_source = case_when(
      filed == 0L ~ "",
      !is.na(ack_date) ~ "portal acknowledgment",
      !is.na(sheet_filing_date) ~ "RA sheet",
      TRUE ~ "missing"
    ),
    first_response = pmin(first_email_response, sheet_response_date, na.rm = TRUE),
    first_response_strict = pmin(first_email_response_strict, sheet_response_date, na.rm = TRUE),
    n_reply_pdfs = coalesce(n_reply_pdfs, 0L),
    n_receipts = coalesce(n_receipts, 0L)
  ) |>
  arrange(app_id)

stopifnot(nrow(status) == nrow(assignments), !anyDuplicated(status$app_id))
write_csv(status, here("data", "derived", "status.csv"), na = "")

# Frame sizes ----
home <- path.expand("~")
## Tamil Nadu's frame is public in in-rolls/rti. The other states' frames are in the state repos.
tn_frame <- read_csv(fetch_pinned(TN_FRAME_PIN, here("data", "private", "upstream")),
  col_types = cols(.default = "c"), show_col_types = FALSE
) |>
  filter(state == "Tamil Nadu")
tn_frame_tiers <- count(tn_frame, tier = level_label, name = "frame_n")
dm <- read_csv(file.path(home, "rti-delhi-maharashtra/data/frame_dl_mh.csv"),
  col_types = cols(.default = "c"), show_col_types = FALSE
)
state_col <- intersect(c("State", "state"), names(dm))[1]
frame_sizes <- tibble(
  state = STATE_ORDER,
  frame_n = c(
    sum(tn_frame_tiers$frame_n),
    nrow(read_csv(file.path(home, "rti-telangana/data/frame_telangana.csv"),
      col_types = cols(.default = "c"), show_col_types = FALSE
    )),
    nrow(read_csv(file.path(home, "rti-karnataka/data/frame_karnataka.csv"),
      col_types = cols(.default = "c"), show_col_types = FALSE
    )),
    sum(dm[[state_col]] %in% c("Delhi", "DL")),
    sum(dm[[state_col]] %in% c("Maharashtra", "MH"))
  )
)
write_csv(tn_frame_tiers, here("data", "derived", "tn_frame_tiers.csv"))
write_csv(frame_sizes, here("data", "derived", "frame_sizes.csv"))

print(count(status, state, filed))
print(count(filter(status, filed == 1L), filing_date_source))
print(count(status, first_response_confidence))
