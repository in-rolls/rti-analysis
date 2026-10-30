# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: raw_00_freeze.R
### Freezes the inputs that get overwritten: RA sheets and overrides go to a dated Drive folder, and
### the drawn assignment lists come into git. Everything else only ever gets added to, so
### raw_00b_manifest.R pins it by checksum where it is. Personal originals never enter git.
### Run once per data date, by hand: RTI_RAW=<Drive rti folder> Rscript code/raw_00_freeze.R
# ----
pacman::p_load(dplyr, purrr, readr, stringr, jsonlite, here)

source(here("code", "00_config.R"))
source(here("code", "raw_utils.R"))

home <- path.expand("~")
raw_root <- path.expand(Sys.getenv("RTI_RAW"))
if (!nzchar(raw_root) || !dir.exists(raw_root)) stop("Set RTI_RAW to the shared Drive rti/ folder.")

## The RA sheets as they stood on the data date, and the tab rules the trackers apply to them
sheets_copy <- path.expand(Sys.getenv(
  "RTI_SHEETS_COPY", file.path(home, "rti-filing-tally/data/raw/2026-10-29_1012")
))
tracker_config <- path.expand(Sys.getenv(
  "RTI_TRACKER_CONFIG", file.path(home, "rti-email-tracker/config.local.json")
))

freeze_dir <- file.path(raw_root, RAW_FREEZE)
if (dir.exists(freeze_dir)) stop("Freeze already exists: ", freeze_dir)
dir.create(file.path(freeze_dir, "ra_sheets"), recursive = TRUE)

# RA sheets, tab rules and matching terms ----
config <- fromJSON(tracker_config, simplifyVector = FALSE)
sheet_manifest <- fromJSON(file.path(sheets_copy, "manifest.json"), simplifyVector = FALSE)
rule_for <- function(person) Filter(function(r) identical(r$person, person), config$ra_sheets)[[1]]

## Neutral group names, so file names in the manifest carry no filer names
sheet_rules <- imap_dfr(sheet_manifest$people, function(sheet, person) {
  rule <- rule_for(person)
  group <- if (any(str_detect(unlist(rule$count), fixed("RA1(")))) "RA1_RA3" else "RA2_RA4"
  map_dfr(sheet$tabs, function(tab) {
    use <- if (tab$tab %in% unlist(rule$ignore)) {
      "ignore"
    } else if (tab$tab %in% unlist(rule$count)) {
      "count"
    } else {
      "unrecognised"
    }
    out_file <- paste0(group, "__", str_replace_all(tab$tab, "[^A-Za-z0-9_]+", "_"), ".csv")
    if (use == "count") {
      file.copy(file.path(sheets_copy, tab$file), file.path(freeze_dir, "ra_sheets", out_file))
    }
    tibble(group = group, person = person, tab = tab$tab, file = out_file, use = use)
  })
})
write_csv(sheet_rules, file.path(freeze_dir, "ra_sheet_rules.csv"))
writeLines(unlist(config$stop_terms), file.path(freeze_dir, "stop_terms.txt"))
file.copy(file.path(raw_root, "email_tracker", "overrides.csv"), freeze_dir)

## Small, non-personal originals that belong in git, byte for byte
assignment_dir <- here("data", "raw", "assignments")
dir.create(assignment_dir, recursive = TRUE, showWarnings = FALSE)
file.copy(file.path(raw_root, "assignments.csv"), file.path(assignment_dir, "tn.csv"),
  overwrite = TRUE
)
repo_lists <- c(
  tg_wave1 = "rti-telangana/out/tg2026q3_02/assignments.csv",
  tg_wave2 = "rti-telangana/out/tg2026q3_03/assignments.csv",
  ka = "rti-karnataka/out/ka2026q3_01/assignments.csv",
  dm_wave1 = "rti-delhi-maharashtra/out/dm2026q3_01/assignments.csv",
  dm_wave2 = "rti-delhi-maharashtra/out/dm2026q3_02/assignments.csv"
)
iwalk(repo_lists, function(p, nm) {
  file.copy(file.path(home, p), file.path(assignment_dir, paste0(nm, ".csv")), overwrite = TRUE)
})

cat("Frozen RA sheets, tab rules, overrides and assignment lists. Now run raw_00b_manifest.R.\n")
