# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: raw_master.R
### Rebuilds the derived data from the original inputs. Needs RTI_RAW set to the shared Drive rti
### folder, plus poppler and tesseract. Run it with `make rebuild`, then `make analysis`.
# ----
if (!requireNamespace("pacman", quietly = TRUE)) {
  install.packages("pacman")
  loadNamespace("pacman")
}

scripts <- c(
  "raw_01_parse_emails.R",
  "raw_02_read_ra_sheets.R",
  "raw_03_match_events.R",
  "raw_04_build_status.R",
  "raw_05_compare_tracker.R"
)

for (script in scripts) {
  cat("Running:", script, "...\n")
  source(here::here("code", script), echo = FALSE)
}

cat("Rebuilt data/derived/ from the original inputs.\n")
