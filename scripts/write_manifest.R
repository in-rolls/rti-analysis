source("scripts/00_config.R")


raw_root <- path.expand(Sys.getenv("RTI_RAW"))
if (!nzchar(raw_root) || !dir.exists(raw_root)) stop("Set RTI_RAW to the shared Drive rti/ folder.")

manifest <- purrr::map_dfr(
  c(original_folders, raw_freeze),
  function(applications) list_originals(raw_root, applications)
)

cache <- Sys.getenv("RTI_HASH_CACHE")
known <- if (nzchar(cache)) readr::read_csv(cache, show_col_types = FALSE) else dplyr::tibble(path = "", md5 = "")
manifest <- manifest |>
  dplyr::left_join(dplyr::select(known, path, md5), by = "path") |>
  dplyr::mutate(md5 = dplyr::if_else(is.na(md5), unname(tools::md5sum(file.path(raw_root, path))), md5)) |>
  dplyr::arrange(folder, path_md5)

if (anyNA(manifest$md5)) stop("Some originals could not be read; is Drive synced?")
readr::write_csv(dplyr::select(manifest, folder, path_md5, bytes, md5), here::here("data", "raw_manifest.csv"))
cat("Manifest:", nrow(manifest), "files,", round(sum(manifest$bytes) / 1e9, 2), "GB\n")
