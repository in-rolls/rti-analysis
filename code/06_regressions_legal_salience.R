# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 06_regressions_legal_salience.R
### Effect of the legal-salience letter. Tamil Nadu and other states are always estimated separately,
### because the randomization block differs: department x tier in Tamil Nadu, state x batch elsewhere.
# ----
if (!exists("rti")) source(here::here("code", "02_load_packages_and_data.R"))

RI_DRAWS <- 2000

# Estimation helpers ----
fit_lpm <- function(d, y, fe = NULL, extra = NULL) {
  rhs <- paste(c("legal", extra), collapse = " + ")
  fml <- if (is.null(fe)) paste(y, "~", rhs) else paste(y, "~", rhs, "|", fe)
  d <- d %>% filter(!is.na(.data[[y]]))
  m <- feols(as.formula(fml), data = d, vcov = "hetero", fixef.rm = "singleton")
  used <- d[obs(m), ]
  list(b = coef(m)[["legal"]], se = se(m)[["legal"]], p = fixest::pvalue(m)[["legal"]],
       n = nobs(m), plain_mean = mean(used[[y]][used$legal == 0]), mde = 2.8 * se(m)[["legal"]])
}

## Randomization inference: reshuffle the letter within blocks, holding each block's arm counts fixed
ri_pvalue <- function(d, y, block = "block", draws = RI_DRAWS) {
  d <- d %>% filter(!is.na(.data[[y]]))
  d <- d %>% group_by(.data[[block]]) %>% filter(n() > 1) %>% ungroup()
  yy <- d[[y]]; dd <- d$legal; g <- as.integer(factor(d[[block]]))
  gmean <- ave(dd, g)
  denom <- sum((dd - gmean)^2)
  obs_b <- sum((dd - gmean) * yy) / denom
  idx <- split(seq_along(dd), g)
  perm_b <- replicate(draws, {
    p <- dd
    for (i in idx) if (length(i) > 1) p[i] <- sample(dd[i])
    sum((p - gmean) * yy) / denom
  })
  mean(abs(perm_b) >= abs(obs_b) - 1e-12)
}

## Same test for the columns that add department-group fixed effects: reshuffle within
## block x department-group cells, partialling out both sets of fixed effects each draw.
ri_pvalue_fe <- function(d, y, draws = RI_DRAWS) {
  d <- d %>% filter(!is.na(.data[[y]]))
  m <- feols(as.formula(paste(y, "~ legal | block + dept_group")), data = d, fixef.rm = "singleton")
  u <- d[obs(m), ]
  fe <- as.data.frame(u[, c("block", "dept_group")])
  y_tilde <- fixest::demean(u[[y]], fe)
  slope <- function(dv) {
    dv_tilde <- fixest::demean(dv, fe)
    if (sum(dv_tilde^2) < 1e-10) return(NA_real_)
    sum(dv_tilde * y_tilde) / sum(dv_tilde^2)
  }
  obs_b <- slope(u$legal)
  idx <- split(seq_len(nrow(u)), paste(u$block, u$dept_group))
  perm_b <- replicate(draws, {
    p <- u$legal
    for (i in idx) if (length(i) > 1) p[i] <- sample(u$legal[i])
    slope(p)
  })
  mean(abs(perm_b) >= abs(obs_b) - 1e-12, na.rm = TRUE)
}

# Main table ----
specs <- list(
  list(sample = "Tamil Nadu", fe = NULL, ri = FALSE),
  list(sample = "Tamil Nadu", fe = "block", ri = TRUE),
  list(sample = "Other states", fe = "block", ri = TRUE),
  list(sample = "Other states", fe = "block + dept_group", ri = TRUE),
  list(sample = "Excl. Telangana", fe = "block", ri = TRUE),
  list(sample = "Excl. Telangana", fe = "block + dept_group", ri = TRUE))

main_panel <- function(y, title) {
  res <- map(specs, \(s) {
    d <- SAMPLES[[s$sample]](eligible)
    out <- fit_lpm(d, y, s$fe)
    out$ri <- if (!s$ri) NA_real_ else if (s$fe == "block") ri_pvalue(d, y) else ri_pvalue_fe(d, y)
    out
  })
  pull <- \(nm) map_dbl(res, nm)
  c(tab_panel(title, 7),
    tab_row("Legal letter", f1(pull("b"))),
    tab_row("", f_se(pull("se"))),
    tab_row("Plain-letter mean", f1(pull("plain_mean"))),
    tab_row("Detectable effect (2.8 $\\times$ SE)", f1(pull("mde"))),
    tab_row("Randomization-inference $p$", ifelse(is.na(pull("ri")), "", sprintf("%.3f", pull("ri")))),
    tab_row("N", f0(as.integer(pull("n")))))
}

both_letters <- function(d) {
  d %>% group_by(dept_group) %>% filter(n_distinct(legal) == 2) %>% ungroup() %>% nrow()
}
n_both_other <- both_letters(SAMPLES[["Other states"]](eligible))
n_both_extg <- both_letters(SAMPLES[["Excl. Telangana"]](eligible))

body <- c(main_panel("any_30", "Panel A. Any response by day 30"),
          main_panel("reply_30", "Panel B. Reply by day 30"),
          main_panel("info_30", "Panel C. Information supplied by day 30"),
          "\\midrule",
          tab_row("Randomization-block FE", "No", "Yes", "Yes", "Yes", "Yes", "Yes"),
          tab_row("Department-group FE", "No", "No", "No", "Yes", "No", "Yes"))

header <- paste(
  "& \\multicolumn{2}{c}{Tamil Nadu} & \\multicolumn{2}{c}{Other states} & \\multicolumn{2}{c}{Excl. Telangana} \\\\",
  "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}\\cmidrule(lr){6-7}",
  tab_row("", "(1)", "(2)", "(3)", "(4)", "(5)", "(6)"))

save_table("tab_main",
  "Effect of the legal-salience letter",
  sprintf("Linear probability models, applications past day 30, percentage points, robust SEs. Legal letter: cites the s.7(1) deadline and s.20 penalties. Any response includes transfers and fee demands; reply excludes them; information: coded full or partial. Blocks: department $\\times$ tier (Tamil Nadu), state $\\times$ batch (others). Columns (4), (6) rest on %d, %d applications in department groups with both letters.",
          n_both_other, n_both_extg),
  "lrrrrrr", header, body)

# Robustness table ----
## Cox hazard ratio on all filings, using the applications not yet at day 30. Not in the design
## document, which specifies linear probability models for the arms.
fit_cox <- function(d) {
  m <- coxph(Surv(km_time, km_event) ~ legal + strata(block), data = d, robust = TRUE)
  s <- summary(m)
  list(hr = s$coefficients[, "exp(coef)"], se = s$coefficients[, "exp(coef)"] * s$coefficients[, "robust se"],
       n = m$n, events = m$nevent)
}

robust_cell <- function(f) {
  r <- tryCatch(f(), error = function(e) NULL)
  if (is.null(r)) return(c("", ""))
  c(paste0(f1(r$b), " ", f_se(r$se)), f0(as.integer(r$n)))
}

robust_row <- function(label, f) {
  cells <- map(names(SAMPLES), \(s) robust_cell(\() f(SAMPLES[[s]])))
  tab_row(label, unlist(cells))
}

filed_dated <- filed %>% filter(!is.na(km_time))
base_fe <- "block"

robust_rows <- c(
  tab_panel("Linear probability, any response (percentage points)", 7),
  robust_row("Baseline, by day 30", \(s) fit_lpm(s(eligible), "any_30", base_fe)),
  robust_row("By day 35", \(s) fit_lpm(s(filed_dated), "any_35", base_fe)),
  robust_row("By day 45", \(s) fit_lpm(s(filed_dated), "any_45", base_fe)),
  robust_row("By day 14, all exposed that long", \(s) fit_lpm(s(filed_dated), "any_14", base_fe)),
  robust_row("Adding RA fixed effects", \(s) fit_lpm(s(eligible), "any_30", paste(base_fe, "+ assigned_ra"))),
  robust_row("Adding filing-week fixed effects", \(s) fit_lpm(s(eligible), "any_30", paste(base_fe, "+ filing_week"))),
  robust_row("Excluding Maharashtra (shorter letter)", \(s) {
    d <- s(eligible) %>% filter(state != "MH")
    if (all(d$state == "TN")) stop("not applicable")
    fit_lpm(d, "any_30", base_fe)
  }),
  robust_row("RA2 and RA4 filings only", \(s) fit_lpm(filter(s(eligible), phone_filer == 1L), "any_30", base_fe)),
  robust_row("RA1 and RA3 filings only", \(s) fit_lpm(filter(s(eligible), phone_filer == 0L), "any_30", base_fe)),
  tab_panel("Cox model, all filings (hazard ratio)", 7),
  {
    cox_cells <- map(names(SAMPLES), \(s) {
      r <- fit_cox(SAMPLES[[s]](filed_dated))
      c(sprintf("%.2f (%.2f)", r$hr, r$se), f0(as.integer(r$n)))
    })
    tab_row("Legal letter, stratified by block", unlist(cox_cells))
  })

header <- paste(
  "& \\multicolumn{2}{c}{Tamil Nadu} & \\multicolumn{2}{c}{Other states} & \\multicolumn{2}{c}{Excl. Telangana} \\\\",
  "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}\\cmidrule(lr){6-7}",
  tab_row("", "Coef. (SE)", "N", "Coef. (SE)", "N", "Coef. (SE)", "N"))

save_table("tab_robust",
  "Legal-salience letter: alternative specifications",
  "All rows: any response (any office action, including a transfer or fee demand), legal letter as in Table~\\ref{tab:tab_main}, block fixed effects, robust SEs. Later cutoffs and the day-14 row use applications exposed that long. Filer-group rows are exploratory. The Cox model is our addition, not in the design document; its SE is on the hazard-ratio scale.",
  "lrrrrrr", header, robust_rows, size = "\\footnotesize")

# Figure: effect by horizon ----
horizon_results <- imap_dfr(SAMPLES, \(f, nm) {
  map_dfr(c(7, 14, 21, 30, 35, 45), \(h) {
    r <- tryCatch(fit_lpm(f(filed_dated), paste0("any_", h), base_fe), error = function(e) NULL)
    if (is.null(r)) return(NULL)
    tibble(panel = nm, h = h, b = r$b, se = r$se, n = r$n)
  })
}) %>%
  mutate(panel = factor(panel, levels = names(SAMPLES)),
         lo = b - 1.96 * se, hi = b + 1.96 * se,
         lab = fct_reorder(sprintf("%d\n(%d)", h, n), h))

fig_horizon <- ggplot(horizon_results, aes(lab, b)) +
  geom_hline(yintercept = 0, color = INK_2, linewidth = 0.3) +
  geom_linerange(aes(ymin = lo, ymax = hi), color = "#2a78d6", linewidth = 0.6) +
  geom_point(color = "#2a78d6", size = 1.8) +
  facet_wrap(~panel, nrow = 1, scales = "free_x") +
  labs(x = "Days since filing (N in parentheses)", y = "Effect of legal letter (percentage points)") +
  theme_rti() +
  theme(axis.text.x = element_text(size = 7, lineheight = 0.9))
save_fig(fig_horizon, "fig_horizon", height = 3.0)

save_fig_note("fig_horizon",
  "Effect of the legal-salience letter by days since filing",
  "Each point is a separate linear probability model of any response (any office action, including a transfer or fee demand) by that day on the legal letter, with randomization-block fixed effects, on applications filed at least that long ago. Bars are 95\\% intervals from robust SEs. The sample changes across horizons.")
