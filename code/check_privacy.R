# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: check_privacy.R
### Fails if git would publish an email, a phone number, a registration number, a column that
### should have been dropped at snapshot, or a term listed in the gitignored .private_terms file.
### Base R only, so the pre-push hook runs without restoring packages.
# ----
TEXT_FILES <- "\\.(csv|R|md|in|tex|yml|yaml|json|cff)$|^(DESCRIPTION|Makefile|\\.gitignore)$"
SKIP_FILES <- "^renv/|^renv\\.lock$|^code/check_privacy\\.R$|^tests/testthat/test-privacy\\.R$"

PATTERNS <- c(
  email = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
  phone = "(^|[^0-9.])([6-9][0-9]{9}|0[0-9]{10})([^0-9]|$)",
  registration = "TGRTI/|/R/20[0-9]{2}/|RTI/APP"
)

FORBIDDEN_COLUMNS <- c(
  "reg_no", "new_reg_nos", "registration_number", "sheet_person", "filed_by", "pio_name",
  "pio_email", "pio_phone", "payment_ref", "payment_reference", "notes"
)

## Which pattern labels match these lines
scan_text <- function(lines, patterns = PATTERNS) {
  names(patterns)[vapply(patterns, function(p) any(grepl(p, lines, perl = TRUE)), logical(1))]
}

forbidden_in_header <- function(header) {
  intersect(tolower(trimws(strsplit(header, ",", fixed = TRUE)[[1]])), FORBIDDEN_COLUMNS)
}

privacy_findings <- function(root = ".") {
  old <- setwd(root)
  on.exit(setwd(old))
  files <- system2("git", c("ls-files", "--cached", "--others", "--exclude-standard"),
    stdout = TRUE
  )
  files <- files[grepl(TEXT_FILES, files) & !grepl(SKIP_FILES, files) & file.exists(files)]
  terms <- if (file.exists(".private_terms")) {
    trimws(setdiff(readLines(".private_terms", warn = FALSE), ""))
  } else {
    character()
  }
  patterns <- c(PATTERNS, setNames(sprintf("(?i)\\Q%s\\E", terms), rep(
    "private term",
    length(terms)
  )))
  findings <- character()
  for (f in files) {
    lines <- readLines(f, warn = FALSE, encoding = "UTF-8")
    hits <- unique(scan_text(lines, patterns))
    if (grepl("\\.csv$", f) && length(lines) > 0) {
      hits <- c(hits, sprintf("column %s", forbidden_in_header(lines[1])))
    }
    if (length(hits) > 0) {
      found <- paste(hits, collapse = ", ")
      findings <- c(findings, sprintf("%s: %s", f, found))
    }
  }
  findings
}

if (sys.nframe() == 0L) {
  findings <- privacy_findings()
  if (length(findings) > 0) {
    cat("Privacy check failed:\n", paste0("  ", findings, "\n"), sep = "")
    quit(status = 1)
  }
  cat("Privacy check passed.\n")
}
