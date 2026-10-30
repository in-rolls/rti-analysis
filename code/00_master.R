# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 00_master.R
### This master script runs every script needed to reproduce the first-cut tables, figures and note.
### Run from the project root: Rscript code/00_master.R. See README.md first.
### 00a_refresh_raw_snapshot.R is deliberately left out: results run from the frozen snapshot.
# ----
# INSTALL PACMAN ----
if (! requireNamespace("pacman", quietly = TRUE)) {
  install.packages("pacman")
  loadNamespace("pacman")
}

# EXECUTE ALL CODE ----
# Create list of scripts

scripts <- c(
  "01_data_cleaning.R",
  "02_load_packages_and_data.R",
  "03_filing_and_balance.R",
  "04_response_descriptives.R",
  "05_reply_content.R",
  "06_regressions_legal_salience.R",
  "07_correlates.R",
  "08_compile_note.R")

# Run each script sequentially
for (script in scripts) {
  cat("Running:", script, "...\n")
  source(here::here("code", script), echo = FALSE)
}

cat("All scripts have been successfully executed.\n")
