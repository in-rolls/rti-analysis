# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 07_correlates.R
### Which offices respond? Descriptive linear probability models, not causal estimates.
# ----
if (!exists("rti")) source(here::here("code", "02_load_packages_and_data.R"))

REF_FUNCTION <- "Finance, industry and other"

corr_data <- eligible %>%
  mutate(function_name = relevel(factor(function_name), ref = REF_FUNCTION),
         tier = factor(tier, levels = c("Sub Office", "Head of Department", "Department")),
         state = factor(state, levels = STATE_ORDER))

corr_models <- list(
  "All excl. Telangana" = feols(any_30 ~ state + function_name + phone_filer + legal,
                                data = filter(corr_data, state != "TG") %>% mutate(state = droplevels(state)), vcov = "hetero"),
  "Tamil Nadu" = feols(any_30 ~ tier + function_name + phone_filer + legal,
                       data = filter(corr_data, state == "TN"), vcov = "hetero"),
  "Karnataka, Delhi, Maharashtra" = feols(any_30 ~ function_name + phone_filer + legal | block,
                                          data = filter(corr_data, !state %in% c("TN", "TG")), vcov = "hetero"))

corr_cell <- function(m, term) {
  if (!term %in% names(coef(m))) return("")
  paste0(f1(coef(m)[[term]]), " ", f_se(se(m)[[term]]))
}

corr_row <- function(label, term) {
  tab_row(paste0("\\quad ", label), map_chr(corr_models, corr_cell, term = term))
}

function_levels <- setdiff(levels(corr_data$function_name), REF_FUNCTION)

body <- c(
  tab_panel("State (relative to Tamil Nadu)", 4),
  corr_row("Karnataka", "stateKA"), corr_row("Delhi", "stateDL"), corr_row("Maharashtra", "stateMH"),
  tab_panel("Tamil Nadu tier (relative to Sub Office)", 4),
  corr_row("Department", "tierDepartment"), corr_row("Head of Department", "tierHead of Department"),
  tab_panel(sprintf("Function (relative to %s)", str_to_lower(REF_FUNCTION)), 4),
  map_chr(function_levels, \(f) corr_row(f, paste0("function_name", f))),
  tab_panel("Application", 4),
  corr_row("Filed by RA2 or RA4", "phone_filer"), corr_row("Legal letter", "legal"),
  "\\midrule",
  tab_row("State $\\times$ batch FE", "No", "No", "Yes"),
  tab_row("N", map_chr(corr_models, \(m) f0(as.integer(nobs(m))))))

save_table("tab_correlates",
  "Correlates of any response within 30 days (descriptive)",
  "Linear probability models, applications past day 30, percentage points, robust SEs in parentheses. Outcome: any office action, including a transfer or fee demand. Telangana is excluded because its outcome is not comparable. Only the letter and, within state, the filer are randomized; the rest are associations. Blank function cells: no such offices past day 30.",
  "lccc",
  tab_row("", names(corr_models)),
  body, size = "\\footnotesize")
