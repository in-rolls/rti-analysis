# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: raw_01_parse_emails.R
### Reads every raw message collected from the three filing inboxes, keeps those up to the data
### date, and classifies each one. Output stays in data/private/ because bodies hold personal data.
# ----
pacman::p_load(dplyr, purrr, readr, stringr, lubridate, jsonlite, here)

source(here("code", "00_config.R"))
source(here("code", "raw_utils.R"))

raw_root <- path.expand(Sys.getenv("RTI_RAW"))
if (!nzchar(raw_root) || !dir.exists(raw_root)) stop("Set RTI_RAW to the shared Drive rti/ folder.")

manifest <- read_csv(here("data", "raw_manifest.csv"), show_col_types = FALSE)
batches <- pinned_originals(raw_root, "email_tracker/raw", manifest)

# Verify and read ----
actual <- unname(tools::md5sum(file.path(raw_root, batches$path)))
if (!identical(actual, batches$md5)) stop("Raw email batches do not match data/raw_manifest.csv")

## A message re-collected after a crash appears twice; the later batch wins
records <- list()
n_lines <- 0L
for (f in sort(batches$path)) {
  for (line in readLines(file.path(raw_root, f), warn = FALSE, encoding = "UTF-8")) {
    if (!nzchar(str_trim(line))) next
    r <- fromJSON(line, simplifyVector = FALSE)
    records[[r$id]] <- r
    n_lines <- n_lines + 1L
  }
}

# Classify ----
to_ist <- function(x) {
  if (is.null(x) || !nzchar(x)) {
    return(as.POSIXct(NA, tz = "Asia/Kolkata"))
  }
  with_tz(ymd_hms(x, tz = "UTC", quiet = TRUE), "Asia/Kolkata")
}

parsed <- map(records, function(r) {
  x <- classify_email(r)
  saved <- Filter(function(a) !is.null(a$drive_id), r$attachments)
  list(
    msg_id = r$id, account = coalesce(r$account, ""), at = to_ist(r$date_iso),
    kind = x$kind, portal_state = x$state, fields = x$fields, attachments = saved,
    sender = email_sender(r$from),
    sender_name = str_trim(str_remove(coalesce(r$from, ""), "\\s*<[^>]*>"), side = "both"),
    subject = str_sub(clean_text(r$subject), 1, 200)
  )
})

emails <- tibble(
  msg_id = map_chr(parsed, "msg_id"),
  account = map_chr(parsed, "account"),
  at = as.POSIXct(map_dbl(parsed, \(x) as.numeric(x$at)),
    origin = "1970-01-01",
    tz = "Asia/Kolkata"
  ),
  kind = map_chr(parsed, "kind"),
  portal_state = map_chr(parsed, "portal_state"),
  sender = map_chr(parsed, "sender"),
  sender_name = map_chr(parsed, "sender_name"),
  subject = map_chr(parsed, "subject"),
  fields = map(parsed, "fields"),
  attachments = map(parsed, "attachments")
) |>
  mutate(date = as.Date(at, tz = "Asia/Kolkata")) |>
  arrange(at, msg_id)

## Keep messages up to the end of the data date; undated stubs cannot be placed, so they stay out
n_all <- nrow(emails)
n_undated <- sum(is.na(emails$date))
emails <- emails |> filter(!is.na(date), date <= AS_OF)

dir.create(here("data", "private"), recursive = TRUE, showWarnings = FALSE)
write_rds(emails, here("data", "private", "emails.rds"))

dir.create(here("data", "derived"), recursive = TRUE, showWarnings = FALSE)
email_audit <- tibble(
  measure = c(
    "lines in batch files", "unique messages", "undated stubs left out",
    "after the data date, left out", "kept"
  ),
  n = c(n_lines, n_all, n_undated, n_all - n_undated - nrow(emails), nrow(emails))
)
write_csv(email_audit, here("data", "derived", "email_audit.csv"))
print(email_audit)
print(count(emails, kind, sort = TRUE))
