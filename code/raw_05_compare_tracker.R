# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: raw_05_compare_tracker.R
### Compares the rebuilt status with what the email tracker reported on the data date, field by
### field
### and application by application. Two independent builds that disagree mean one of them has a
### mistake, so every difference is listed for review.
# ----
pacman::p_load(dplyr, purrr, readr, stringr, tidyr, here)

source(here("code", "00_config.R"))

status <- read_csv(here("data", "derived", "status.csv"),
  col_types = cols(.default = "c"), show_col_types = FALSE, na = ""
)
tracker <- read_csv(here("data", "validation", TRACKER_CHECK, "status_panel.csv"),
  col_types = cols(.default = "c"), show_col_types = FALSE, na = ""
) |>
  mutate(filed = if_else(filed == "True", "1", "0"))

fields <- c(
  "filed", "filing_date", "ack_date", "transferred_on", "fee_demanded_on", "disposed_on",
  "returned_on", "rejected_on", "email_response_on", "first_response"
)

stopifnot(setequal(status$app_id, tracker$app_id))
long <- function(d, value) {
  d |>
    select(app_id, all_of(fields)) |>
    pivot_longer(-app_id, names_to = "field", values_to = value)
}

differences <- long(status, "rebuilt") |>
  inner_join(long(tracker, "tracker"), by = c("app_id", "field")) |>
  filter(coalesce(rebuilt, "") != coalesce(tracker, ""))

write_csv(differences, here("data", "derived", "tracker_differences.csv"), na = "")

summary_table <- tibble(field = fields) |>
  left_join(count(differences, field, name = "differ"), by = "field") |>
  mutate(differ = coalesce(differ, 0L), agree = nrow(status) - differ)
write_csv(summary_table, here("data", "derived", "tracker_agreement.csv"))

print(summary_table)
cat("Applications with any difference:", n_distinct(differences$app_id), "\n")
