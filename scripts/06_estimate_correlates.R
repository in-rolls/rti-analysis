ref_function <- "Finance, industry and other"

corr_data <- eligible |>
  dplyr::mutate(
    function_name = relevel(factor(function_name), ref = ref_function),
    tier = factor(tier, levels = c("Sub Office", "Head of Department", "Department")),
    state = factor(state, levels = state_order)
  )

corr_models <- list(
  "All excl. Telangana" = fixest::feols(any_30 ~ state + function_name + phone_filer + legal,
    data = dplyr::filter(corr_data, state != "TG") |> dplyr::mutate(state = droplevels(state)), vcov = "hetero"
  ),
  "Tamil Nadu" = fixest::feols(any_30 ~ tier + function_name + phone_filer + legal,
    data = dplyr::filter(corr_data, state == "TN"), vcov = "hetero"
  ),
  "Karnataka, Delhi, Maharashtra" = fixest::feols(any_30 ~ function_name + phone_filer + legal | block,
    data = dplyr::filter(corr_data, !state %in% c("TN", "TG")), vcov = "hetero"
  )
)

corr_cell <- function(model, term) {
  if (!term %in% names(coef(model))) {
    return("")
  }
  paste0(format_estimate(coef(model)[[term]]), " ", format_standard_error(fixest::se(model)[[term]]))
}

corr_row <- function(label, term) {
  format_table_row(paste0("\\quad ", label), purrr::map_chr(corr_models, corr_cell, term = term))
}

function_levels <- dplyr::setdiff(levels(corr_data$function_name), ref_function)

body <- c(
  format_table_panel("State (relative to Tamil Nadu)", 4),
  corr_row("Karnataka", "stateKA"), corr_row("Delhi", "stateDL"), corr_row(
    "Maharashtra",
    "stateMH"
  ),
  format_table_panel("Tamil Nadu tier (relative to Sub Office)", 4),
  corr_row("Department", "tierDepartment"), corr_row(
    "Head of Department",
    "tierHead of Department"
  ),
  format_table_panel(sprintf("Function (relative to %s)", stringr::str_to_lower(ref_function)), 4),
  purrr::map_chr(function_levels, \(f) corr_row(f, paste0("function_name", f))),
  format_table_panel("Application", 4),
  corr_row("Filed by RA2 or RA4", "phone_filer"), corr_row("Legal letter", "legal"),
  "\\midrule",
  format_table_row("State $\\times$ batch FE", "No", "No", "Yes"),
  format_table_row("N", purrr::map_chr(corr_models, \(model) format_count(as.integer(nobs(model)))))
)

save_table("tab_correlates",
  "Correlates of any response within 30 days (descriptive)",
  paste0(
    "Linear probability models, applications past day 30, percentage points, ",
    "robust SEs in parentheses. Outcome: any office action, including a ",
    "transfer or fee demand. Telangana is excluded because its outcome is not ",
    "comparable. Only the letter and, within state, the filer are randomized; ",
    "the rest are associations. Blank function cells: no such offices past day ",
    "30."
  ),
  "lccc",
  format_table_row("", names(corr_models)),
  body,
  size = "\\footnotesize"
)
