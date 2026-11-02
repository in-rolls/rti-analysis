fetch_pinned <- function(pin, dest_dir) {
  dest <- file.path(dest_dir, paste0(pin$ref, "_", basename(pin$path)))
  if (!file.exists(dest)) {
    dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
    url <- sprintf("https://raw.githubusercontent.com/%s/%s/%s", pin$repo, pin$ref, pin$path)
    utils::download.file(url, dest, quiet = TRUE, mode = "wb")
  }
  if (unname(tools::md5sum(dest)) != pin$md5) {
    stop("Pinned file does not match its checksum: ", pin$repo, "/", pin$path)
  }
  dest
}

find_upstream_file <- function(name, root = here::here()) {
  pins <- utils::read.csv(file.path(root, "data", "upstream.csv"), colClasses = "character")
  pin <- pins[pins$name == name, ]
  if (nrow(pin) != 1) stop("No upstream pin named ", name)
  ## Each commit gets its own folder, because several pinned files share a base name
  fetch_pinned(as.list(pin), file.path(root, "data", "upstream", pin$name))
}

# Assignment lists ----
## The six lists as drawn, in one shape. Tamil Nadu has a department tree and tiers; the others have
## a flat roster, so their department group stands in for the department.
read_assignments <- function(root = here::here()) {
  read_one <- function(name) {
    readr::read_csv(find_upstream_file(name, root),
      col_types = readr::cols(.default = "c"), show_col_types = FALSE, na = ""
    )
  }
  tn <- read_one("tn") |>
    dplyr::transmute(
      app_id = application_id, batch_id, treatment, assigned_ra, tier,
      stratum = randomization_stratum, dept = tree_department, office_name, template_version
    )
  others <- purrr::map_dfr(c("tg_wave1", "tg_wave2", "ka", "dm_wave1", "dm_wave2"), read_one) |>
    dplyr::transmute(
      app_id = application_id, batch_id, treatment, assigned_ra, tier = NA_character_,
      stratum = dept_group, dept = dept_group, office_name, template_version
    )
  dplyr::bind_rows(tn, others) |> dplyr::mutate(state = stringr::str_sub(app_id, 1, 2))
}
