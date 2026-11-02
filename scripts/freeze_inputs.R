source("scripts/00_config.R")


user_dir <- path.expand("~")
raw_root <- path.expand(Sys.getenv("RTI_RAW"))
if (!nzchar(raw_root) || !dir.exists(raw_root)) stop("Set RTI_RAW to the shared Drive rti/ folder.")

## The RA sheets as they stood on the data date, and the tab rules the trackers apply to them
sheets_copy <- path.expand(Sys.getenv(
  "RTI_SHEETS_COPY", file.path(user_dir, "rti-filing-tally/data/raw/2026-10-29_1012")
))
tracker_config <- path.expand(Sys.getenv(
  "RTI_TRACKER_CONFIG", file.path(user_dir, "rti-email-tracker/config.local.json")
))

freeze_dir <- file.path(raw_root, raw_freeze)
if (dir.exists(freeze_dir)) stop("Freeze already exists: ", freeze_dir)
dir.create(file.path(freeze_dir, "ra_sheets"), recursive = TRUE)

# RA sheets, tab rules and matching terms ----
config <- jsonlite::fromJSON(tracker_config, simplifyVector = FALSE)
sheet_manifest <- jsonlite::fromJSON(file.path(sheets_copy, "manifest.json"), simplifyVector = FALSE)
rule_for <- function(person) Filter(function(r) identical(r$person, person), config$ra_sheets)[[1]]

## Neutral group names, so file names in the manifest carry no filer names
sheet_rules <- purrr::imap_dfr(sheet_manifest$people, function(sheet, person) {
  rule <- rule_for(person)
  group <- if (any(stringr::str_detect(unlist(rule$count), stringr::fixed("RA1(")))) "RA1_RA3" else "RA2_RA4"
  purrr::map_dfr(sheet$tabs, function(tab) {
    use <- if (tab$tab %in% unlist(rule$ignore)) {
      "ignore"
    } else if (tab$tab %in% unlist(rule$count)) {
      "count"
    } else {
      "unrecognised"
    }
    out_file <- paste0(group, "__", stringr::str_replace_all(tab$tab, "[^A-Za-z0-9_]+", "_"), ".csv")
    if (use == "count") {
      file.copy(file.path(sheets_copy, tab$file), file.path(freeze_dir, "ra_sheets", out_file))
    }
    dplyr::tibble(group = group, person = person, tab = tab$tab, file = out_file, use = use)
  })
})
readr::write_csv(sheet_rules, file.path(freeze_dir, "ra_sheet_rules.csv"))
writeLines(unlist(config$stop_terms), file.path(freeze_dir, "stop_terms.txt"))
file.copy(file.path(raw_root, "email_tracker", "overrides.csv"), freeze_dir)

cat("Frozen RA sheets, tab rules and overrides. Now run scripts/write_manifest.R.\n")
