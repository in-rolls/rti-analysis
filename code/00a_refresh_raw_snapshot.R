# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 00a_refresh_raw_snapshot.R
### Freezes the live trackers into data/raw/snapshot_<date>/ so results do not move when they update.
### NOT run by 00_master.R. Run by hand only when you want a new data date, then edit SNAPSHOT in
### 02_load_packages_and_data.R and revisit the count checks at the end of 01_data_cleaning.R.
### Registration numbers, PIO contacts, filer names and free-text coder notes are dropped here.
# ----
pacman::p_load(tidyverse, here)

snapshot_date <- "2026-10-29"
out_dir <- here("data", "raw", paste0("snapshot_", snapshot_date))

## A snapshot is frozen once taken: never overwrite one. Change snapshot_date for a new data date.
if (dir.exists(out_dir)) stop("Snapshot already exists: ", out_dir, ". Set a new snapshot_date.")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Live sources ----
## RTI_DRIVE is this machine's path to the shared Drive rti/ folder. The state repos and
## rti-responses must be cloned in the home folder.
home <- path.expand("~")
drive <- path.expand(Sys.getenv("RTI_DRIVE"))
if (drive == "") stop("Set RTI_DRIVE to this machine's path to the shared Drive rti/ folder.")
src <- list(
  panel  = file.path(drive, "email_tracker/out/rti_status_panel.csv"),
  events = file.path(drive, "email_tracker/out/tracker_events.csv"),
  coded  = file.path(home, "rti-responses/responses_coded.csv"),
  tn     = file.path(drive, "assignments.csv"),
  tn_frame = file.path(drive, "tn_universe.csv"),
  tg1    = file.path(home, "rti-telangana/out/tg2026q3_02/assignments.csv"),
  tg2    = file.path(home, "rti-telangana/out/tg2026q3_03/assignments.csv"),
  ka     = file.path(home, "rti-karnataka/out/ka2026q3_01/assignments.csv"),
  dm1    = file.path(home, "rti-delhi-maharashtra/out/dm2026q3_01/assignments.csv"),
  dm2    = file.path(home, "rti-delhi-maharashtra/out/dm2026q3_02/assignments.csv"),
  tg_frame = file.path(home, "rti-telangana/data/frame_telangana.csv"),
  ka_frame = file.path(home, "rti-karnataka/data/frame_karnataka.csv"),
  dm_frame = file.path(home, "rti-delhi-maharashtra/data/frame_dl_mh.csv"))

read_chr <- function(path) read_csv(path, col_types = cols(.default = "c"), show_col_types = FALSE)

# Status panel: one row per drawn application ----
panel <- read_chr(src$panel) %>%
  select(-any_of(c("reg_no", "new_reg_nos", "sheet_person")))

# Events: dates and kinds only ----
events <- read_chr(src$events) %>%
  filter(!is.na(app_id), app_id != "") %>%
  select(date, kind, app_id, method, confidence)

# Coded replies: everything except the free-text notes ----
coded <- read_chr(src$coded) %>%
  select(-any_of("notes"))

# Assignments ----
assign_tn <- read_chr(src$tn) %>%
  transmute(application_id, batch_id, treatment, assigned_ra, tier,
            stratum = randomization_stratum, dept = tree_department,
            office_name, template_version)

assign_other <- map_dfr(c(src$tg1, src$tg2, src$ka, src$dm1, src$dm2), read_chr) %>%
  transmute(application_id, batch_id, treatment, assigned_ra, tier = NA_character_,
            stratum = dept_group, dept = dept_group, office_name, template_version)

# Frame sizes ----
tn_tiers <- read_chr(src$tn_frame) %>%
  count(tier = level_label, name = "frame_n")

dm_frame <- read_chr(src$dm_frame)
state_col <- intersect(c("State", "state"), names(dm_frame))[1]
frame_sizes <- tibble(
  state = c("TN", "TG", "KA", "DL", "MH"),
  frame_n = c(sum(tn_tiers$frame_n),
              nrow(read_chr(src$tg_frame)),
              nrow(read_chr(src$ka_frame)),
              sum(dm_frame[[state_col]] %in% c("Delhi", "DL")),
              sum(dm_frame[[state_col]] %in% c("Maharashtra", "MH"))))

# Write snapshot and checksums ----
outputs <- list(status_panel = panel, events = events, responses_coded = coded,
                assignments_tn = assign_tn, assignments_other = assign_other,
                tn_frame_tiers = tn_tiers, frame_sizes = frame_sizes)
iwalk(outputs, \(d, nm) write_csv(d, file.path(out_dir, paste0(nm, ".csv")), na = ""))

manifest <- tibble(
  file = paste0(names(outputs), ".csv"),
  rows = map_int(outputs, nrow),
  md5 = unname(tools::md5sum(file.path(out_dir, paste0(names(outputs), ".csv")))),
  snapshot_taken = format(Sys.time(), "%Y-%m-%d %H:%M %Z"))
write_csv(manifest, file.path(out_dir, "MANIFEST.csv"))

source_times <- tibble(source = names(src), path = unlist(src),
                       modified = format(file.mtime(unlist(src)), "%Y-%m-%d %H:%M"))
write_csv(source_times %>% mutate(path = str_replace(path, fixed(drive), "<RTI_DRIVE>"),
                                   path = str_replace(path, fixed(home), "~")),
          file.path(out_dir, "SOURCES.csv"))

print(manifest)
print(source_times %>% select(source, modified))
print(frame_sizes)
