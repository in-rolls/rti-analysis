# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: check_privacy.R
### Fails if git would publish an email, a phone number, a registration number, a column that
### should have been dropped at snapshot, or a term listed in the gitignored .private_terms file.
### Base R only, so the pre-push hook runs without restoring packages.
# ----
TEXT_FILES <- "\\.(csv|R|md|in|tex|yml|yaml|json|cff)$|^(DESCRIPTION|Makefile|\\.gitignore)$"
## These hold the patterns themselves, public portal addresses and made-up examples
SKIP_FILES <- paste0(
  "^renv/|^renv\\.lock$|^code/check_privacy\\.R$|^code/raw_utils\\.R$|",
  "^tests/testthat/test-privacy\\.R$|^tests/testthat/test-raw-utils\\.R$"
)

PATTERNS <- c(
  email = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
  phone = "(^|[^0-9A-Za-z.])([6-9][0-9]{9}|0[0-9]{10})([^0-9A-Za-z]|$)",
  registration = "TGRTI/|/R/20[0-9]{2}/|RTI/APP"
)

## A column may exist if it is empty: the drawn assignment lists carry blank tracking columns
FORBIDDEN_COLUMNS <- c(
  "reg_no", "new_reg_nos", "registration_number", "sheet_person", "filed_by", "pio_name",
  "pio_email", "pio_phone", "payment_ref", "payment_reference"
)

## Public senders of the portals' own mail, needed to recognise their templates
ALLOWED_ADDRESSES <- c(
  "rtisupport@tn.gov.in", "rtionline-kar@nic.in", "tsrtinoreply@gmail.com",
  "noreply-rtimh@mah.gov.in", "noreply-dopt@gov.in"
)

## Which pattern labels match these lines
scan_text <- function(lines, patterns = PATTERNS) {
  names(patterns)[vapply(patterns, function(p) any(grepl(p, lines, perl = TRUE)), logical(1))]
}

forbidden_in_header <- function(header) {
  intersect(tolower(trimws(strsplit(header, ",", fixed = TRUE)[[1]])), FORBIDDEN_COLUMNS)
}

## Forbidden columns that actually hold values
forbidden_filled <- function(path) {
  d <- utils::read.csv(path,
    colClasses = "character", check.names = FALSE,
    na.strings = character()
  )
  names(d) <- tolower(trimws(names(d)))
  Filter(function(col) any(nzchar(trimws(d[[col]]))), intersect(names(d), FORBIDDEN_COLUMNS))
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
    for (allowed in ALLOWED_ADDRESSES) lines <- gsub(allowed, "", lines, fixed = TRUE)
    hits <- unique(scan_text(lines, patterns))
    if (grepl("\\.csv$", f) && length(lines) > 0 && length(forbidden_in_header(lines[1])) > 0) {
      hits <- c(hits, sprintf("column %s", forbidden_filled(f)))
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
