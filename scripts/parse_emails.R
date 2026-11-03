source("scripts/00_config.R")


raw_root <- path.expand(Sys.getenv("RTI_RAW"))
if (!nzchar(raw_root) || !dir.exists(raw_root)) stop("Set RTI_RAW to the shared Drive rti/ folder.")

manifest <- readr::read_csv(here::here("data", "raw_manifest.csv"), show_col_types = FALSE)
batches <- find_pinned_originals(raw_root, "email_tracker/raw", manifest)

# Verify and read ----
actual <- unname(tools::md5sum(file.path(raw_root, batches$path)))
if (!identical(actual, batches$md5)) stop("Raw email batches do not match data/raw_manifest.csv")

## A message re-collected after a crash appears twice; the later batch wins
records <- list()
n_lines <- 0L
for (f in sort(batches$path)) {
  for (line in readLines(file.path(raw_root, f), warn = FALSE, encoding = "UTF-8")) {
    if (!nzchar(stringr::str_trim(line))) next
    r <- jsonlite::fromJSON(line, simplifyVector = FALSE)
    records[[r$id]] <- r
    n_lines <- n_lines + 1L
  }
}

# Classify ----
to_ist <- function(x) {
  if (is.null(x) || !nzchar(x)) {
    return(as.POSIXct(NA, tz = "Asia/Kolkata"))
  }
  lubridate::with_tz(lubridate::ymd_hms(x, tz = "UTC", quiet = TRUE), "Asia/Kolkata")
}

parsed <- purrr::map(records, function(r) {
  x <- classify_email(r)
  saved <- Filter(function(a) !is.null(a$drive_id), r$attachments)
  list(
    msg_id = r$id, account = dplyr::coalesce(r$account, ""), at = to_ist(r$date_iso),
    kind = x$kind, portal_state = x$state, fields = x$fields, attachments = saved,
    sender = extract_email_sender(r$from),
    sender_name = stringr::str_trim(stringr::str_remove(dplyr::coalesce(r$from, ""), "\\s*<[^>]*>"), side = "both"),
    subject = stringr::str_sub(clean_text(r$subject), 1, 200)
  )
})

emails <- dplyr::tibble(
  msg_id = purrr::map_chr(parsed, "msg_id"),
  account = purrr::map_chr(parsed, "account"),
  at = as.POSIXct(purrr::map_dbl(parsed, \(x) as.numeric(x$at)),
    origin = "1970-01-01",
    tz = "Asia/Kolkata"
  ),
  kind = purrr::map_chr(parsed, "kind"),
  portal_state = purrr::map_chr(parsed, "portal_state"),
  sender = purrr::map_chr(parsed, "sender"),
  sender_name = purrr::map_chr(parsed, "sender_name"),
  subject = purrr::map_chr(parsed, "subject"),
  fields = purrr::map(parsed, "fields"),
  attachments = purrr::map(parsed, "attachments")
) |>
  dplyr::mutate(date = as.Date(at, tz = "Asia/Kolkata")) |>
  dplyr::arrange(at, msg_id)

## Keep messages up to the end of the data date; undated stubs cannot be placed, so they stay out
n_all <- nrow(emails)
n_undated <- sum(is.na(emails$date))
emails <- emails |> dplyr::filter(!is.na(date), date <= as_of)

dir.create(here::here("data", "private"), recursive = TRUE, showWarnings = FALSE)
readr::write_rds(emails, here::here("data", "private", "emails.rds"))

dir.create(here::here("data", "derived"), recursive = TRUE, showWarnings = FALSE)
email_audit <- dplyr::tibble(
  measure = c(
    "lines in batch files", "unique messages", "undated stubs left out",
    "after the data date, left out", "kept"
  ),
  n = c(n_lines, n_all, n_undated, n_all - n_undated - nrow(emails), nrow(emails))
)
readr::write_csv(email_audit, here::here("data", "derived", "email_audit.csv"))
print(email_audit)
print(dplyr::count(emails, kind, sort = TRUE))
