# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: raw_00b_manifest.R
### Records the size and checksum of every original in data/raw_manifest.csv. Reads every file,
### so on
### Drive this takes several minutes. RTI_HASH_CACHE can name a CSV of path and md5 already
### computed.
# ----
pacman::p_load(dplyr, purrr, readr, stringr, here)

source(here("code", "00_config.R"))
source(here("code", "raw_utils.R"))

raw_root <- path.expand(Sys.getenv("RTI_RAW"))
if (!nzchar(raw_root) || !dir.exists(raw_root)) stop("Set RTI_RAW to the shared Drive rti/ folder.")

manifest <- map_dfr(c(ORIGINAL_FOLDERS, RAW_FREEZE), function(d) list_originals(raw_root, d))

cache <- Sys.getenv("RTI_HASH_CACHE")
known <- if (nzchar(cache)) read_csv(cache, show_col_types = FALSE) else tibble(path = "", md5 = "")
manifest <- manifest |>
  left_join(select(known, path, md5), by = "path") |>
  mutate(md5 = if_else(is.na(md5), unname(tools::md5sum(file.path(raw_root, path))), md5)) |>
  arrange(folder, path_md5)

if (anyNA(manifest$md5)) stop("Some originals could not be read; is Drive synced?")
write_csv(select(manifest, folder, path_md5, bytes, md5), here("data", "raw_manifest.csv"))
cat("Manifest:", nrow(manifest), "files,", round(sum(manifest$bytes) / 1e9, 2), "GB\n")
