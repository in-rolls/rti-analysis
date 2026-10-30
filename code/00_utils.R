# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 00_utils.R
### Pure functions shared by the pipeline and tested in tests/testthat. Nothing here reads data.
# ----
# Dates ----
to_date <- function(x) as.Date(na_if(x, ""))

# Government function, coded from department and office names ----
code_function <- function(x) {
  x <- str_to_lower(x)
  case_when(
    str_detect(x, "industrial safety|scheduled caste|scheduled tribe") ~ "Welfare, labour and food",
    str_detect(x, "transco|genco|kptcl|escom|electricity") ~ "Infrastructure and utilities",
    str_detect(x, paste0(
      "school|education|college|university|mahavidyalaya|institute of technology|",
      "polytechnic|\\bdiet\\b|public instruction|training institute|\\bbeo\\b|",
      "\\bdeo\\b|\\bddpi\\b|intermediate"
    )) ~ "Education",
    str_detect(x, paste0(
      "health|hospital|medical|ayush|ayurved|ismh|chikitsalaya|vaidya|aids ",
      "control|drugs control"
    )) ~ "Health",
    str_detect(x, paste0(
      "police|\\bhome\\b|prison|jail|\\bfire\\b|court|judge|\\blaw\\b|legal|",
      "lokayukta|excise|prohibition|vigilance"
    )) ~ "Police, justice and excise",
    str_detect(x, paste0(
      "panchayat|rural|zilla|\\brdpr|municipal|\\bdudc\\b|urban|housing|slum|",
      "town|city corporation|praja parishad|mandal parishad|development ",
      "authority|planning authority|\\bzp\\b"
    )) ~ "Local government and housing",
    str_detect(x, paste0(
      "revenue|tahsil|tehsil|collector|registration|stamps|\\bland|survey|",
      "\\bddlr\\b|\\bdr\\b|\\bsslr\\b|commercial tax|deputy commissioner|",
      "divisional commissioner|disaster"
    )) ~ "Revenue, land and registration",
    str_detect(x, paste0(
      "agri|animal|husba|veterinary|fisher|dairy|horticulture|sericulture|",
      "cooperat|co-operat|forest|environment|climate|pollution|mines|geology|",
      "natural resources|marketing|deputy registrar"
    )) ~ paste0(
      "Agriculture, cooperatives and environment"
    ),
    str_detect(x, paste0(
      "\\bpwd\\b|public works|roads|highway|irrigation|water|energy|\\bpower\\b|",
      "transport|\\brtc\\b|tgsrtc|ksrtc|\\brto\\b|minor ports|\\bcad\\b|sewerage"
    )) ~ "Infrastructure and utilities",
    str_detect(x, paste0(
      "welfare|tribal|women|child|\\bicds\\b|backward|minorit|disab|labour|",
      "\\blabor\\b|employment|skill|social|\\bsc\\b|\\bsc\\.|\\bobc\\b|\\bfcs\\b|",
      "food|civil supplies|consumer"
    )) ~ "Welfare, labour and food",
    TRUE ~ "Finance, industry and other"
  )
}

# Number formatting for tables ----
f0 <- function(x) ifelse(is.na(x), "", formatC(x, format = "d", big.mark = ","))
f1 <- function(x) {
  x <- round(x, 1)
  x[!is.na(x) & x == 0] <- 0
  ifelse(is.na(x), "", sub("^-", "$-$", sprintf("%.1f", x)))
}
f2 <- function(x) ifelse(is.na(x), "", sprintf("%.2f", x))
f_p <- function(p) ifelse(is.na(p), "", ifelse(p < 0.001, "$<$0.001", sprintf("%.3f", p)))
f_se <- function(x) ifelse(is.na(x), "", sprintf("(%.1f)", x))
f_ci <- function(lo, hi) sprintf("[%.1f, %.1f]", lo, hi)

## Wilson 95% interval for a percentage
wilson <- function(k, n, z = 1.96) {
  p <- k / n
  centre <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
  list(lo = 100 * pmax(centre - half, 0), hi = 100 * pmin(centre + half, 1))
}

# Table rows ----
tab_row <- function(...) paste0(paste(c(...), collapse = " & "), " \\\\")
tab_panel <- function(text, ncol) {
  sprintf(paste0(
    "\\addlinespace\\multicolumn{%d}{l}{\\textit{%s}} \\\\"
  ), ncol, text)
}

# Estimators ----
fit_lpm <- function(d, y, fe = NULL, extra = NULL) {
  rhs <- paste(c("legal", extra), collapse = " + ")
  fml <- if (is.null(fe)) paste(y, "~", rhs) else paste(y, "~", rhs, "|", fe)
  d <- d |> filter(!is.na(.data[[y]]))
  m <- feols(as.formula(fml), data = d, vcov = "hetero", fixef.rm = "singleton")
  used <- d[obs(m), ]
  list(
    b = coef(m)[["legal"]], se = se(m)[["legal"]], p = fixest::pvalue(m)[["legal"]],
    n = nobs(m), plain_mean = mean(used[[y]][used$legal == 0]), mde = 2.8 * se(m)[["legal"]]
  )
}

## Randomization inference: reshuffle the letter within blocks, holding each block's arm counts
## fixed
ri_pvalue <- function(d, y, block = "block", draws = RI_DRAWS) {
  d <- d |> filter(!is.na(.data[[y]]))
  d <- d |>
    group_by(.data[[block]]) |>
    filter(n() > 1) |>
    ungroup()
  yy <- d[[y]]
  dd <- d$legal
  g <- as.integer(factor(d[[block]]))
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
  d <- d |> filter(!is.na(.data[[y]]))
  m <- feols(as.formula(paste(y, "~ legal | block + dept_group")), data = d, fixef.rm = "singleton")
  u <- d[obs(m), ]
  fe <- as.data.frame(u[, c("block", "dept_group")])
  y_tilde <- fixest::demean(u[[y]], fe)
  slope <- function(dv) {
    dv_tilde <- fixest::demean(dv, fe)
    if (sum(dv_tilde^2) < 1e-10) {
      return(NA_real_)
    }
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

# Survival curves ----
## Cumulative share responding by day. Curves stop once fewer than 10 applications remain at risk.
km_curve <- function(d, group) {
  d <- d |>
    filter(!is.na(km_time)) |>
    mutate(grp = .data[[group]])
  groups <- if (is.factor(d$grp)) levels(droplevels(d$grp)) else unique(d$grp)
  map_dfr(groups, \(g) {
    fit <- survfit(Surv(km_time, km_event) ~ 1, data = filter(d, grp == g))
    days <- 0:max(ceiling(d$km_time))
    s <- summary(fit, times = days, extend = TRUE)
    tibble(
      group = g, day = s$time, cum = 100 * (1 - s$surv),
      lo = 100 * (1 - s$upper), hi = 100 * (1 - s$lower), at_risk = s$n.risk
    ) |>
      filter(at_risk >= 10 | day == 0)
  })
}
