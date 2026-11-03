compute_wilson_interval <- function(k, n, z = 1.96) {
  p <- k / n
  centre <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
  list(lo = 100 * pmax(centre - half, 0), hi = 100 * pmin(centre + half, 1))
}

# Agreement between two coders ----
compute_cohen_kappa <- function(a, b) {
  stopifnot(length(a) == length(b))
  observed <- mean(a == b)
  levels <- dplyr::union(a, b)
  chance <- sum(vapply(levels, \(l) mean(a == l) * mean(b == l), 0))
  (observed - chance) / (1 - chance)
}

fit_lpm <- function(applications, y, fe = NULL, extra = NULL) {
  rhs <- paste(c("legal", extra), collapse = " + ")
  fml <- if (is.null(fe)) paste(y, "~", rhs) else paste(y, "~", rhs, "|", fe)
  applications <- applications |> dplyr::filter(!is.na(.data[[y]]))
  model <- fixest::feols(as.formula(fml), data = applications, vcov = "hetero", fixef.rm = "singleton")
  used <- applications[fixest::obs(model), ]
  list(
    b = coef(model)[["legal"]], se = fixest::se(model)[["legal"]], p = fixest::pvalue(model)[["legal"]],
    n = nobs(model), plain_mean = mean(used[[y]][used$legal == 0]), mde = 2.8 * fixest::se(model)[["legal"]]
  )
}

## Randomization inference: reshuffle the letter within blocks, holding each block's arm counts
## fixed
compute_randomization_p <- function(applications, y, block = "block", draws = ri_draws) {
  applications <- applications |> dplyr::filter(!is.na(.data[[y]]))
  applications <- applications |>
    dplyr::group_by(.data[[block]]) |>
    dplyr::filter(dplyr::n() > 1) |>
    dplyr::ungroup()
  outcome_values <- applications[[y]]
  treatment <- applications$legal
  g <- as.integer(factor(applications[[block]]))
  block_treatment_mean <- ave(treatment, g)
  denom <- sum((treatment - block_treatment_mean)^2)
  observed_effect <- sum((treatment - block_treatment_mean) * outcome_values) / denom
  idx <- split(seq_along(treatment), g)
  permuted_effects <- replicate(draws, {
    p <- treatment
    for (i in idx) if (length(i) > 1) p[i] <- sample(treatment[i])
    sum((p - block_treatment_mean) * outcome_values) / denom
  })
  mean(abs(permuted_effects) >= abs(observed_effect) - 1e-12)
}

## Same test for the columns that add department-group fixed effects: reshuffle within
## block x department-group cells, partialling out both sets of fixed effects each draw.
compute_randomization_p_fe <- function(applications, y, draws = ri_draws) {
  applications <- applications |> dplyr::filter(!is.na(.data[[y]]))
  model <- fixest::feols(as.formula(paste(y, "~ legal | block + dept_group")),
    data = applications,
    fixef.rm = "singleton"
  )
  model_data <- applications[fixest::obs(model), ]
  fe <- as.data.frame(model_data[, c("block", "dept_group")])
  y_tilde <- fixest::demean(model_data[[y]], fe)
  slope <- function(dv) {
    dv_tilde <- fixest::demean(dv, fe)
    if (sum(dv_tilde^2) < 1e-10) {
      return(NA_real_)
    }
    sum(dv_tilde * y_tilde) / sum(dv_tilde^2)
  }
  observed_effect <- slope(model_data$legal)
  idx <- split(seq_len(nrow(model_data)), paste(model_data$block, model_data$dept_group))
  permuted_effects <- replicate(draws, {
    p <- model_data$legal
    for (i in idx) if (length(i) > 1) p[i] <- sample(model_data$legal[i])
    slope(p)
  })
  mean(abs(permuted_effects) >= abs(observed_effect) - 1e-12, na.rm = TRUE)
}

# Survival curves ----
## Cumulative share responding by day. Curves stop once fewer than 10 applications remain at risk.
compute_response_curve <- function(applications, group) {
  applications <- applications |>
    dplyr::filter(!is.na(km_time)) |>
    dplyr::mutate(grp = .data[[group]])
  groups <- if (is.factor(applications$grp)) levels(droplevels(applications$grp)) else unique(applications$grp)
  purrr::map_dfr(groups, \(g) {
    fit <- survival::survfit(survival::Surv(km_time, km_event) ~ 1, data = dplyr::filter(applications, grp == g))
    days <- 0:max(ceiling(applications$km_time))
    s <- summary(fit, times = days, extend = TRUE)
    dplyr::tibble(
      group = g, day = s$time, cum = 100 * (1 - s$surv),
      lo = 100 * (1 - s$upper), hi = 100 * (1 - s$lower), at_risk = s$n.risk
    ) |>
      dplyr::filter(at_risk >= 10 | day == 0)
  })
}
