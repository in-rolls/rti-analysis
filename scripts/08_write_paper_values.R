by_state <- readr::read_csv(file.path(paths$tables, "response_by_state.csv"), show_col_types = FALSE)
effects <- readr::read_csv(file.path(paths$tables, "main_effects.csv"), show_col_types = FALSE)

rate <- \(sample, y = "any") sprintf("%.1f", by_state[[y]][by_state$sample == sample])
effect <- \(sample, y) sprintf("%.1f", effects[[y]][effects$sample == sample])

display_order <- c(
  "Tamil Nadu", "Tamil Nadu, adjusted for office level", "Telangana", "Karnataka", "Delhi",
  "Maharashtra", "All states", "All excl. Telangana"
)
results_table <- c(
  "| State | Past day 30 | Any response (%) | Reply (%) | Information supplied (%) |",
  "| --- | ---: | ---: | ---: | ---: |",
  purrr::map_chr(display_order, \(s) {
    n <- by_state$n[by_state$sample == s]
    sprintf(
      "| %s | %s | %s | %s | %s |", s, ifelse(is.na(n), "", format_count(n)), rate(s), rate(s, "reply"),
      rate(s, "info")
    )
  })
)

coding_agreement <- readr::read_csv(file.path(paths$tables, "coding_agreement.csv"),
  show_col_types = FALSE
)
agree_rate <- \(model) sprintf("%.0f", coding_agreement$agree[coding_agreement$measure == model])
n_coded <- sum(rti$coded)
n_full <- sum(rti$disposition == "full", na.rm = TRUE)
n_informed <- sum(rti$disposition %in% c("full", "partial"))

fill <- c(
  n_coded = format_count(n_coded), n_full = format_count(n_full), n_informed = format_count(n_informed),
  agree_info = agree_rate("information"), agree_disp = agree_rate("disposition"),
  as_of = format(as_of, "%d %B %Y"), n_drawn = format_count(nrow(rti)), n_filed = format_count(sum(rti$filed)),
  n_past30 = format_count(sum(rti$past30)), results_table = paste(results_table, collapse = "\n"),
  any_extg = rate("All excl. Telangana"), info_extg = rate("All excl. Telangana", "info"),
  any_tn = rate("Tamil Nadu"), any_tn_w = rate("Tamil Nadu, adjusted for office level"),
  any_ka = rate("Karnataka"), any_tg = rate("Telangana"),
  b_tn = effect("Tamil Nadu", "b"), se_tn = effect("Tamil Nadu", "se"),
  mde_tn = effect("Tamil Nadu", "mde"),
  b_other = effect("Other states", "b"), se_other = effect("Other states", "se"),
  mde_other = effect("Other states", "mde"),
  b_extg = effect("Excl. Telangana", "b"), se_extg = effect("Excl. Telangana", "se"),
  mde_extg = effect("Excl. Telangana", "mde")
)

readme <- readLines(here::here("docs", "README.md.in"))
for (key in names(fill)) readme <- gsub(paste0("@@", key, "@@"), fill[[key]], readme, fixed = TRUE)
writeLines(readme, here::here("README.md"))

write_macros(fill[names(fill) != "results_table"], here::here("tabs", "macros.tex"))

packages <- c("R", names(jsonlite::read_json(here::here("renv.lock"))$Packages))
versions <- vapply(packages, function(package) {
  if (package == "R") as.character(getRversion()) else as.character(utils::packageVersion(package))
}, character(1))
readr::write_csv(
  data.frame(package = packages, version = versions),
  here::here("other", "r_packages_info.csv")
)
