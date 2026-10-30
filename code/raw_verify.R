# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: raw_verify.R
### Checks every original against data/raw_manifest.csv. A mismatch is an error, never a silent
### substitution. Reads all the files, so on Drive this takes several minutes.
# ----
pacman::p_load(dplyr, purrr, readr, stringr, here)

source(here("code", "00_config.R"))
source(here("code", "raw_utils.R"))

raw_root <- path.expand(Sys.getenv("RTI_RAW"))
if (!nzchar(raw_root) || !dir.exists(raw_root)) stop("Set RTI_RAW to the shared Drive rti/ folder.")

manifest <- read_csv(here("data", "raw_manifest.csv"), show_col_types = FALSE)
found <- map_dfr(unique(manifest$folder), function(d) list_originals(raw_root, d)) |>
  mutate(actual = unname(tools::md5sum(file.path(raw_root, path))))

joined <- manifest |> left_join(select(found, path_md5, actual), by = "path_md5")
missing_files <- sum(is.na(joined$actual))
changed <- sum(!is.na(joined$actual) & joined$actual != joined$md5)

cat("Files in manifest:", nrow(manifest), "\n")
cat("Missing:", missing_files, "; changed:", changed, "\n")
if (missing_files > 0 || changed > 0) quit(status = 1)
cat(
  "All originals match. New files since the freeze are ignored:",
  nrow(found) - sum(found$path_md5 %in% manifest$path_md5), "\n"
)
