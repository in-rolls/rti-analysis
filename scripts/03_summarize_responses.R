# Table: response at day 30 by state ----
tn_frame <- readr::read_csv(here::here("data", "derived", "tn_frame_tiers.csv"), show_col_types = FALSE)

state_row <- function(applications, label) {
  k <- sum(applications$any_30 == 100)
  n <- nrow(applications)
  ci <- compute_wilson_interval(k, n)
  format_table_row(
    label, format_count(n), format_estimate(mean(applications$any_30)), format_interval(
      ci$lo,
      ci$hi
    ), format_estimate(mean(applications$reply_30)),
    format_estimate(mean(applications$info_30))
  )
}

## Tamil Nadu weighted to its frame: tier rates times tier shares, because sub-offices are
## 97.9% of the frame but 80% of those past day 30.
tn_weighted <- eligible |>
  dplyr::filter(tn) |>
  dplyr::group_by(tier) |>
  dplyr::summarise(
    n = dplyr::n(), any = mean(any_30), reply = mean(reply_30), info = mean(info_30),
    .groups = "drop"
  ) |>
  dplyr::left_join(tn_frame, by = "tier") |>
  dplyr::mutate(w = frame_n / sum(frame_n))

weighted_any <- sum(tn_weighted$w * tn_weighted$any)
weighted_se <- sqrt(sum(
  tn_weighted$w^2 * tn_weighted$any * (100 - tn_weighted$any) / tn_weighted$n
))

body <- c(
  purrr::map_chr(state_order, \(s) {
    row <- state_row(dplyr::filter(eligible, state == s), state_labels[[s]])
    if (s != "TN") {
      return(row)
    }
    c(row, format_table_row(
      "\\quad Adjusted$^a$", "",
      format_estimate(weighted_any), format_interval(
        max(weighted_any - 1.96 * weighted_se, 0),
        weighted_any + 1.96 * weighted_se
      ),
      format_estimate(sum(tn_weighted$w * tn_weighted$reply)), format_estimate(sum(tn_weighted$w * tn_weighted$info))
    )) |>
      paste(collapse = "\n")
  }),
  "\\midrule",
  state_row(eligible, "All states"),
  state_row(dplyr::filter(eligible, state != "TG"), "All excl. Telangana")
)

save_table(
  "tab_response_state",
  "Response within 30 days of filing, by state (\\%)",
  paste0(
    "Applications filed at least 30 days earlier. Response includes transfers and fees; ",
    "reply excludes transfers. Information: full or partial reply. Missing replies, ",
    "especially in Telangana, understate outcomes. $^a$Weighted to match office-level ",
    "shares in the portal list; no adjustment for departments or filing dates. ",
    "95\\% intervals: Wilson for unadjusted rates, normal for adjusted rates."
  ),
  "lrrcrr",
  format_table_row("State", "N", "Any response", "95\\% CI", "Reply", "Information supplied"),
  body
)

## The same rates as data, for the README
rate_row <- function(applications, label) {
  dplyr::tibble(
    sample = label, n = nrow(applications), any = mean(applications$any_30), reply = mean(applications$reply_30),
    info = mean(applications$info_30)
  )
}

response_by_state <- dplyr::bind_rows(
  purrr::map_dfr(state_order, \(s) rate_row(dplyr::filter(eligible, state == s), state_labels[[s]])),
  dplyr::tibble(
    sample = "Tamil Nadu, adjusted for office level", n = NA_integer_, any = weighted_any,
    reply = sum(tn_weighted$w * tn_weighted$reply), info = sum(tn_weighted$w * tn_weighted$info)
  ),
  rate_row(eligible, "All states"),
  rate_row(dplyr::filter(eligible, state != "TG"), "All excl. Telangana")
)
readr::write_csv(response_by_state, file.path(paths$tables, "response_by_state.csv"))

# Table: response at day 30 by letter ----
letter_row <- function(applications, label) {
  p0 <- applications |> dplyr::filter(legal == 0)
  p1 <- applications |> dplyr::filter(legal == 1)
  fisher <- fisher.test(table(applications$legal, applications$any_30 == 100))$p.value
  format_table_row(
    label, format_count(nrow(p0)), format_estimate(mean(p0$any_30)), format_count(nrow(p1)),
    format_estimate(mean(p1$any_30)),
    format_estimate(mean(p1$any_30) - mean(p0$any_30)), format_p_value(fisher)
  )
}

body <- c(
  purrr::map_chr(state_order, \(s) letter_row(dplyr::filter(eligible, state == s), state_labels[[s]])),
  "\\midrule",
  letter_row(eligible, "All states"),
  letter_row(dplyr::filter(eligible, state != "TG"), "All excl. Telangana")
)

header <- paste(
  "& \\multicolumn{2}{c}{Plain} & \\multicolumn{2}{c}{Legal salience} & & \\\\",
  "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
  format_table_row("State", "N", "\\%", "N", "\\%", "Difference", "Fisher $p$")
)

save_table(
  "tab_response_letter",
  "Any response within 30 days, by letter (raw comparison)",
  paste0(
    "Applications past day 30. Legal salience: the letter adds the s.7(1) ",
    "deadline and s.20 penalties to the plain request. Any response: any ",
    "office action, including a transfer or fee demand. Raw differences in ",
    "percentage points; the Tamil Nadu row is confounded with tier. Interim, ",
    "unregistered look."
  ),
  "lrrrrrr", header, body
)

# Table: speed ----
speed_cols <- c(7, 14, 21, 30, 45)

speed_row <- function(applications, label, what) {
  cells <- purrr::map_chr(speed_cols, \(h) {
    x <- applications[[paste0("any_", h)]]
    x <- x[!is.na(x)]
    if (what == "share") ifelse(length(x) >= 10, format_estimate(mean(x)), "") else format_count(length(x))
  })
  med <- if (what == "share") {
    median_days <- median(applications$days_any, na.rm = TRUE)
    format_count(as.integer(round(median_days)))
  } else {
    format_count(sum(!is.na(applications$days_any)))
  }
  format_table_row(label, cells, med)
}

speed_body <- function(what) {
  c(
    purrr::map_chr(state_order, \(s) speed_row(dplyr::filter(filed, state == s), state_labels[[s]], what)),
    speed_row(dplyr::filter(filed, state != "TG"), "All excl. Telangana", what)
  )
}

body <- c(
  format_table_panel("Panel A. Any response by this day (\\%)", 7), speed_body("share"),
  format_table_panel("Panel B. Applications exposed at least this long (N)", 7), speed_body("n")
)

header <- paste(
  "& \\multicolumn{5}{c}{Days since filing} & \\multicolumn{1}{c}{Responders:} \\\\",
  "\\cmidrule(lr){2-6}",
  format_table_row("State", speed_cols, "median days / N")
)

save_table(
  "tab_speed",
  "How fast offices respond",
  paste0(
    "All dated filings; each column uses only applications filed at least that ",
    "long ago, so shares need not rise. Any response: any office action, ",
    "including a transfer or fee demand. Blank: fewer than 10 applications. ",
    "Last column: median days (Panel A), responders (Panel B)."
  ),
  "lrrrrrr", header, body
)

# Table: tier and filing cohort ----
cut_row <- function(applications, label, h, min_n = 0) {
  n <- sum(!is.na(applications[[paste0("any_", h)]]))
  rate <- \(y) if (n < min_n) "" else format_estimate(mean(applications[[paste0(y, "_", h)]], na.rm = TRUE))
  format_table_row(label, format_count(n), rate("any"), rate("reply"), rate("info"))
}

tier_body <- purrr::map_chr(
  c("Department", "Head of Department", "Sub Office"),
  \(t) cut_row(dplyr::filter(eligible, tn, tier == t), t, 30)
)

cohort_def <- filed |>
  dplyr::filter(!is.na(filing_date), exposure >= 14) |>
  dplyr::mutate(
    cohort = dplyr::if_else(filing_month == "2026-10", "filed in October", "filed by 30 September"),
    cohort = factor(cohort, levels = c("filed by 30 September", "filed in October"))
  )

cohort_body <- cohort_def |>
  dplyr::distinct(state, cohort) |>
  dplyr::mutate(state = factor(state, levels = state_order)) |>
  dplyr::arrange(state, cohort) |>
  dplyr::mutate(state = as.character(state)) |>
  purrr::pmap_chr(\(state, cohort) {
    s <- state
    cut_row(dplyr::filter(cohort_def, state == s, cohort == !!cohort),
      paste0(state_labels[[s]], ", ", cohort), 14,
      min_n = 10
    )
  })

body <- c(
  format_table_panel("Panel A. Tamil Nadu by tier, by day 30", 5), tier_body,
  format_table_panel("Panel B. By filing cohort, by day 14", 5), cohort_body
)

save_table(
  "tab_cuts",
  "Response by Tamil Nadu tier and by filing cohort (\\%)",
  sprintf(
    paste0(
      "Any response: any office action, including a transfer or fee demand. ",
      "Reply: excludes transfers. Information supplied: coded full or partial. ",
      "Panel A: past day 30, from only %d of 40 departments because of filing ",
      "order. Panel B: filed at least 14 days ago; blank cells have fewer than ",
      "10 applications."
    ),
    dplyr::n_distinct(eligible$dept[eligible$tn])
  ),
  "lrrrr",
  format_table_row("Group", "N", "Any response", "Reply", "Information supplied"),
  body
)

# Table: filer group ----
## Only RA2 and RA4 could take phone calls, and they are one person, so this contrast bundles
## phone reachability with the filer's name and postal address.
filer_row <- function(applications, label) {
  model <- fixest::feols(any_30 ~ phone_filer | block, data = applications, vcov = "hetero", fixef.rm = "singleton")
  a <- applications |> dplyr::filter(phone_filer == 0)
  b <- applications |> dplyr::filter(phone_filer == 1)
  format_table_row(
    label, format_count(nrow(a)), format_estimate(mean(a$any_30)), format_count(nrow(b)),
    format_estimate(mean(b$any_30)),
    format_estimate(coef(model)[["phone_filer"]]), format_standard_error(fixest::se(model)[["phone_filer"]])
  )
}

body <- c(
  purrr::map_chr(state_order, \(s) filer_row(dplyr::filter(eligible, state == s), state_labels[[s]])),
  "\\midrule",
  filer_row(eligible, "All states"),
  filer_row(dplyr::filter(eligible, state != "TG"), "All excl. Telangana")
)

header <- paste(
  paste0(
    "& \\multicolumn{2}{c}{RA1 and RA3} & \\multicolumn{2}{c}{RA2 and RA4} & ",
    "\\multicolumn{2}{c}{Within block} \\\\"
  ),
  "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}\\cmidrule(lr){6-7}",
  format_table_row("State", "N", "\\%", "N", "\\%", "Difference", "(SE)")
)

save_table(
  "tab_filer",
  "Any response within 30 days, by filer group",
  paste0(
    "Applications past day 30. Any response: any office action, including a ",
    "transfer or fee demand. Only RA2 and RA4 could receive calls and both are ",
    "one person, so this bundles phone with name and address. Difference: ",
    "coefficient on RA2/RA4 with block fixed effects and robust SE, in ",
    "percentage points."
  ),
  "lrrrrrr", header, body
)

# Figure: Kaplan-Meier by state ----
km_state <- compute_response_curve(filed, "state_name") |>
  dplyr::mutate(group = factor(group, levels = state_labels))

fig_km_state <- ggplot2::ggplot(km_state, ggplot2::aes(day, cum, color = group, linetype = group)) +
  ggplot2::geom_vline(xintercept = 30, color = ink_2, linewidth = 0.3, linetype = "dotted") +
  ggplot2::geom_step(linewidth = 0.8) +
  ggplot2::scale_color_manual(values = state_colors) +
  ggplot2::scale_linetype_manual(values = state_lines) +
  ggplot2::scale_x_continuous(breaks = seq(0, 60, 10), limits = c(0, NA)) +
  ggplot2::scale_y_continuous(limits = c(0, NA), expand = ggplot2::expansion(mult = c(0, 0.04))) +
  ggplot2::labs(x = "Days since filing", y = "Cumulative share responding (%)") +
  theme_rti()
save_figure(fig_km_state, "fig_km_state")

save_figure_note(
  "fig_km_state",
  "Time to first response, by state",
  sprintf(
    paste0(
      "Kaplan-Meier estimates of time to any response (any office action, ",
      "including a transfer or fee demand), all %s dated filings, censored at ",
      "%s; curves stop when fewer than 10 applications remain at risk. Dotted ",
      "line: the 30-day limit in s.7(1). Telangana is a lower bound because its ",
      "portal sends no status emails."
    ),
    format_count(sum(!is.na(filed$km_time))), format(as_of, "%d %B")
  )
)

# Figure: Kaplan-Meier by letter ----
km_letter <- purrr::imap_dfr(samples, \(f, nm) {
  f(filed) |>
    dplyr::mutate(arm = factor(dplyr::if_else(legal == 1L, "Legal salience", "Plain"),
      levels = names(arm_colors)
    )) |>
    compute_response_curve("arm") |>
    dplyr::mutate(panel = nm)
}) |>
  dplyr::mutate(
    panel = factor(panel, levels = names(samples)),
    group = factor(group, levels = names(arm_colors))
  )

fig_km_letter <- ggplot2::ggplot(km_letter, ggplot2::aes(day, cum, color = group, linetype = group, fill = group)) +
  ggplot2::geom_vline(xintercept = 30, color = ink_2, linewidth = 0.3, linetype = "dotted") +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = lo, ymax = hi), alpha = 0.10, color = NA) +
  ggplot2::geom_step(linewidth = 0.7) +
  ggplot2::facet_wrap(~panel, nrow = 1) +
  ggplot2::scale_color_manual(values = arm_colors) +
  ggplot2::scale_fill_manual(values = arm_colors) +
  ggplot2::scale_linetype_manual(values = arm_lines) +
  ggplot2::scale_x_continuous(breaks = seq(0, 60, 20)) +
  ggplot2::scale_y_continuous(limits = c(0, NA), expand = ggplot2::expansion(mult = c(0, 0.04))) +
  ggplot2::labs(x = "Days since filing", y = "Cumulative share responding (%)") +
  theme_rti()
save_figure(fig_km_letter, "fig_km_letter", height = 3.0)

save_figure_note(
  "fig_km_letter",
  "Time to first response, by letter",
  paste0(
    "Kaplan-Meier estimates of time to any response (any office action, ",
    "including a transfer or fee demand) with 95\\% bands, all filings, raw, ",
    "so the Tamil Nadu panel is confounded with tier. Legal salience: the ",
    "letter adds the s.7(1) deadline and s.20 penalties. Excl. Telangana: ",
    "Karnataka, Delhi and Maharashtra. Dotted line: day 30."
  )
)

# Figure: outcomes among those past day 30 ----
outcome_colors <- c(
  "Full information" = "#155a9e", "Partial information" = "#6aa6e8", "Fee demanded" = "#eda100",
  "Denied" = "#8f2d56", "Returned" = "#eb6834", "Transferred" = "#6250d6",
  "Reply, not yet coded" = "#9a9892", "No response" = "#e8e7e3"
)

outcome_shares <- eligible |>
  dplyr::count(state_name, outcome, .drop = FALSE) |>
  dplyr::group_by(state_name) |>
  dplyr::mutate(
    share = 100 * n / sum(n), total = sum(n),
    outcome = factor(outcome, levels = names(outcome_colors))
  ) |>
  dplyr::arrange(outcome, .by_group = TRUE) |>
  dplyr::mutate(mid = cumsum(share) - share / 2) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    state_lab = sprintf("%s (%d)", state_name, total),
    state_lab = forcats::fct_rev(factor(state_lab, levels = unique(state_lab[order(state_name)])))
  )

fig_outcomes <- ggplot2::ggplot(outcome_shares, ggplot2::aes(share, state_lab, fill = outcome)) +
  ggplot2::geom_col(
    width = 0.62, color = "white", linewidth = 0.4,
    position = ggplot2::position_stack(reverse = TRUE)
  ) +
  ggplot2::geom_text(
    data = dplyr::filter(outcome_shares, share >= 8), inherit.aes = FALSE,
    ggplot2::aes(
      x = mid, y = state_lab, label = sprintf("%.0f", share),
      color = outcome %in% c("Full information", "Denied", "Transferred")
    ),
    size = 2.8, family = "sans", show.legend = FALSE
  ) +
  ggplot2::scale_color_manual(values = c(`TRUE` = "white", `FALSE` = ink), guide = "none") +
  ggplot2::scale_fill_manual(values = outcome_colors, guide = ggplot2::guide_legend(nrow = 2, byrow = TRUE)) +
  ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0, 0.01))) +
  ggplot2::labs(x = "Share of applications past day 30 (%)", y = NULL) +
  theme_rti() +
  ggplot2::theme(
    panel.grid.major.y = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_line(color = grid, linewidth = 0.3),
    axis.line.x = ggplot2::element_blank(),
    legend.key.width = ggplot2::unit(0.8, "lines"), legend.key.height = ggplot2::unit(0.7, "lines")
  )
save_figure(fig_outcomes, "fig_outcomes", height = 2.9)

save_figure_note(
  "fig_outcomes",
  "What has come back so far, by state",
  sprintf(paste0(
    "Applications past day 30, status as of %s, whenever the reply came. N in ",
    "parentheses; segments of 8\\%% or more are labeled. Reply documents double-coded blind, ",
    "with disagreements adjudicated. Telangana is a lower bound because ",
    "its portal sends no status emails."
  ), format(as_of, "%d %B"))
)

# Figure: response by government function ----
function_rates <- eligible |>
  dplyr::filter(state != "TG") |>
  dplyr::group_by(function_name) |>
  dplyr::summarise(n = dplyr::n(), k = sum(any_30 == 100), rate = 100 * k / n, .groups = "drop") |>
  dplyr::mutate(
    lo = compute_wilson_interval(k, n)$lo, hi = compute_wilson_interval(k, n)$hi,
    lab = sprintf("%s (%d)", function_name, n),
    lab = forcats::fct_reorder(lab, rate)
  )

fig_function <- ggplot2::ggplot(function_rates, ggplot2::aes(rate, lab)) +
  ggplot2::geom_linerange(ggplot2::aes(xmin = lo, xmax = hi), color = "#2a78d6", linewidth = 0.6) +
  ggplot2::geom_point(color = "#2a78d6", size = 2) +
  ggplot2::scale_x_continuous(limits = c(0, NA), expand = ggplot2::expansion(mult = c(0, 0.03))) +
  ggplot2::labs(x = "Any response within 30 days (%)", y = NULL) +
  theme_rti() +
  ggplot2::theme(
    panel.grid.major.y = ggplot2::element_line(color = grid, linewidth = 0.3),
    panel.grid.major.x = ggplot2::element_line(color = grid, linewidth = 0.3)
  )
save_figure(fig_function, "fig_function", height = 3.0)

save_figure_note(
  "fig_function",
  "Any response within 30 days, by government function",
  paste0(
    "Applications past day 30, excluding Telangana. N in parentheses; bars are ",
    "Wilson 95\\% intervals. Any response: any office action, including a ",
    "transfer or fee demand. Function is keyword-coded from department and ",
    "office names (crosswalk in data/derived/). Pooled across states, so state ",
    "differences are not removed."
  )
)

# Headline numbers, for independent checking ----
## legal_any comes first: summarise() evaluates in order, and any_30 is overwritten by its count
## below
summarise_headline <- function(applications) {
  applications |> dplyr::summarise(
    n = dplyr::n(), legal_n = sum(legal), legal_any = sum(any_30 == 100 & legal == 1),
    any_30 = sum(any_30 == 100), reply_30 = sum(reply_30 == 100), info_30 = sum(info_30 == 100),
    .groups = "drop"
  )
}
headline <- dplyr::bind_rows(
  eligible |> dplyr::group_by(sample = state) |> summarise_headline(),
  eligible |> dplyr::mutate(sample = "ALL") |> dplyr::group_by(sample) |> summarise_headline()
)
readr::write_csv(headline, file.path(paths$tables, "headline_numbers.csv"))
