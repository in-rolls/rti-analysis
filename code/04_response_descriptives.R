# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 04_response_descriptives.R
### Response rates by state, letter, tier, cohort and filer group, speed, and Figures 2 to 4 and 6.
# ----
if (!exists("rti")) source(here::here("code", "02_load_packages_and_data.R"))

# Table: response at day 30 by state ----
tn_frame <- read_csv(here("data", "raw", SNAPSHOT, "tn_frame_tiers.csv"), show_col_types = FALSE)

state_row <- function(d, label) {
  k <- sum(d$any_30 == 100)
  n <- nrow(d)
  ci <- wilson(k, n)
  tab_row(
    label, f0(n), f1(mean(d$any_30)), f_ci(ci$lo, ci$hi), f1(mean(d$reply_30)),
    f1(mean(d$info_30))
  )
}

## Tamil Nadu weighted to its frame: tier rates times tier shares, because sub-offices are
## 97.9% of the frame but 80% of those past day 30.
tn_weighted <- eligible |>
  filter(tn) |>
  group_by(tier) |>
  summarise(
    n = n(), any = mean(any_30), reply = mean(reply_30), info = mean(info_30),
    .groups = "drop"
  ) |>
  left_join(tn_frame, by = "tier") |>
  mutate(w = frame_n / sum(frame_n))

weighted_any <- sum(tn_weighted$w * tn_weighted$any)
weighted_se <- sqrt(sum(
  tn_weighted$w^2 * tn_weighted$any * (100 - tn_weighted$any) / tn_weighted$n
))

body <- c(
  map_chr(STATE_ORDER, \(s) {
    row <- state_row(filter(eligible, state == s), STATE_LABELS[[s]])
    if (s != "TN") {
      return(row)
    }
    c(row, tab_row(
      "\\quad weighted to frame", "",
      f1(weighted_any), f_ci(
        max(weighted_any - 1.96 * weighted_se, 0),
        weighted_any + 1.96 * weighted_se
      ),
      f1(sum(tn_weighted$w * tn_weighted$reply)), f1(sum(tn_weighted$w * tn_weighted$info))
    )) |>
      paste(collapse = "\n")
  }),
  "\\midrule",
  state_row(eligible, "All states"),
  state_row(filter(eligible, state != "TG"), "All excl. Telangana")
)

save_table(
  "tab_response_state",
  "Response within 30 days of filing, by state (\\%)",
  paste0(
    "Applications past day 30. Any response: any office action, including a ",
    "transfer or fee demand. Reply: excludes transfers. Information supplied: ",
    "reply coded full or partial, a lower bound. Telangana is a lower bound ",
    "because its portal sends no status emails. Brackets: Wilson 95\\% ",
    "intervals."
  ),
  "lrrcrr",
  tab_row("State", "N", "Any response", "95\\% CI", "Reply", "Information supplied"),
  body
)

## The same rates as data, for the README
rate_row <- function(d, label) {
  tibble(
    sample = label, n = nrow(d), any = mean(d$any_30), reply = mean(d$reply_30),
    info = mean(d$info_30)
  )
}

response_by_state <- bind_rows(
  map_dfr(STATE_ORDER, \(s) rate_row(filter(eligible, state == s), STATE_LABELS[[s]])),
  tibble(
    sample = "Tamil Nadu, weighted to frame", n = NA_integer_, any = weighted_any,
    reply = sum(tn_weighted$w * tn_weighted$reply), info = sum(tn_weighted$w * tn_weighted$info)
  ),
  rate_row(eligible, "All states"),
  rate_row(filter(eligible, state != "TG"), "All excl. Telangana")
)
write_csv(response_by_state, file.path(PATHS$tables, "response_by_state.csv"))

# Table: response at day 30 by letter ----
letter_row <- function(d, label) {
  p0 <- d |> filter(legal == 0)
  p1 <- d |> filter(legal == 1)
  fisher <- fisher.test(table(d$legal, d$any_30 == 100))$p.value
  tab_row(
    label, f0(nrow(p0)), f1(mean(p0$any_30)), f0(nrow(p1)), f1(mean(p1$any_30)),
    f1(mean(p1$any_30) - mean(p0$any_30)), f_p(fisher)
  )
}

body <- c(
  map_chr(STATE_ORDER, \(s) letter_row(filter(eligible, state == s), STATE_LABELS[[s]])),
  "\\midrule",
  letter_row(eligible, "All states"),
  letter_row(filter(eligible, state != "TG"), "All excl. Telangana")
)

header <- paste(
  "& \\multicolumn{2}{c}{Plain} & \\multicolumn{2}{c}{Legal salience} & & \\\\",
  "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
  tab_row("State", "N", "\\%", "N", "\\%", "Difference", "Fisher $p$")
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

speed_row <- function(d, label, what) {
  cells <- map_chr(speed_cols, \(h) {
    x <- d[[paste0("any_", h)]]
    x <- x[!is.na(x)]
    if (what == "share") ifelse(length(x) >= 10, f1(mean(x)), "") else f0(length(x))
  })
  med <- if (what == "share") {
    median_days <- median(d$days_any, na.rm = TRUE)
    f0(as.integer(round(median_days)))
  } else {
    f0(sum(!is.na(d$days_any)))
  }
  tab_row(label, cells, med)
}

speed_body <- function(what) {
  c(
    map_chr(STATE_ORDER, \(s) speed_row(filter(filed, state == s), STATE_LABELS[[s]], what)),
    speed_row(filter(filed, state != "TG"), "All excl. Telangana", what)
  )
}

body <- c(
  tab_panel("Panel A. Any response by this day (\\%)", 7), speed_body("share"),
  tab_panel("Panel B. Applications exposed at least this long (N)", 7), speed_body("n")
)

header <- paste(
  "& \\multicolumn{5}{c}{Days since filing} & \\multicolumn{1}{c}{Responders:} \\\\",
  "\\cmidrule(lr){2-6}",
  tab_row("State", speed_cols, "median days / N")
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
cut_row <- function(d, label, h, min_n = 0) {
  n <- sum(!is.na(d[[paste0("any_", h)]]))
  rate <- \(y) if (n < min_n) "" else f1(mean(d[[paste0(y, "_", h)]], na.rm = TRUE))
  tab_row(label, f0(n), rate("any"), rate("reply"), rate("info"))
}

tier_body <- map_chr(
  c("Department", "Head of Department", "Sub Office"),
  \(t) cut_row(filter(eligible, tn, tier == t), t, 30)
)

cohort_def <- filed |>
  filter(!is.na(filing_date), exposure >= 14) |>
  mutate(
    cohort = if_else(filing_month == "2026-10", "filed in October", "filed by 30 September"),
    cohort = factor(cohort, levels = c("filed by 30 September", "filed in October"))
  )

cohort_body <- cohort_def |>
  distinct(state, cohort) |>
  mutate(state = factor(state, levels = STATE_ORDER)) |>
  arrange(state, cohort) |>
  mutate(state = as.character(state)) |>
  pmap_chr(\(state, cohort) {
    s <- state
    cut_row(filter(cohort_def, state == s, cohort == !!cohort),
      paste0(STATE_LABELS[[s]], ", ", cohort), 14,
      min_n = 10
    )
  })

body <- c(
  tab_panel("Panel A. Tamil Nadu by tier, by day 30", 5), tier_body,
  tab_panel("Panel B. By filing cohort, by day 14", 5), cohort_body
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
    n_distinct(eligible$dept[eligible$tn])
  ),
  "lrrrr",
  tab_row("Group", "N", "Any response", "Reply", "Information supplied"),
  body
)

# Table: filer group ----
## Only RA2 and RA4 could take phone calls, and they are one person, so this contrast bundles
## phone reachability with the filer's name and postal address.
filer_row <- function(d, label) {
  m <- feols(any_30 ~ phone_filer | block, data = d, vcov = "hetero", fixef.rm = "singleton")
  a <- d |> filter(phone_filer == 0)
  b <- d |> filter(phone_filer == 1)
  tab_row(
    label, f0(nrow(a)), f1(mean(a$any_30)), f0(nrow(b)), f1(mean(b$any_30)),
    f1(coef(m)[["phone_filer"]]), f_se(se(m)[["phone_filer"]])
  )
}

body <- c(
  map_chr(STATE_ORDER, \(s) filer_row(filter(eligible, state == s), STATE_LABELS[[s]])),
  "\\midrule",
  filer_row(eligible, "All states"),
  filer_row(filter(eligible, state != "TG"), "All excl. Telangana")
)

header <- paste(
  paste0(
    "& \\multicolumn{2}{c}{RA1 and RA3} & \\multicolumn{2}{c}{RA2 and RA4} & ",
    "\\multicolumn{2}{c}{Within block} \\\\"
  ),
  "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}\\cmidrule(lr){6-7}",
  tab_row("State", "N", "\\%", "N", "\\%", "Difference", "(SE)")
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
km_state <- km_curve(filed, "state_name") |>
  mutate(group = factor(group, levels = STATE_LABELS))

fig_km_state <- ggplot(km_state, aes(day, cum, color = group, linetype = group)) +
  geom_vline(xintercept = 30, color = INK_2, linewidth = 0.3, linetype = "dotted") +
  geom_step(linewidth = 0.8) +
  scale_color_manual(values = STATE_COLORS) +
  scale_linetype_manual(values = STATE_LINES) +
  scale_x_continuous(breaks = seq(0, 60, 10), limits = c(0, NA)) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.04))) +
  labs(x = "Days since filing", y = "Cumulative share responding (%)") +
  theme_rti()
save_fig(fig_km_state, "fig_km_state")

save_fig_note(
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
    f0(sum(!is.na(filed$km_time))), format(AS_OF, "%d %B")
  )
)

# Figure: Kaplan-Meier by letter ----
km_letter <- imap_dfr(SAMPLES, \(f, nm) {
  f(filed) |>
    mutate(arm = factor(if_else(legal == 1L, "Legal salience", "Plain"),
      levels = names(ARM_COLORS)
    )) |>
    km_curve("arm") |>
    mutate(panel = nm)
}) |>
  mutate(
    panel = factor(panel, levels = names(SAMPLES)),
    group = factor(group, levels = names(ARM_COLORS))
  )

fig_km_letter <- ggplot(km_letter, aes(day, cum, color = group, linetype = group, fill = group)) +
  geom_vline(xintercept = 30, color = INK_2, linewidth = 0.3, linetype = "dotted") +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.10, color = NA) +
  geom_step(linewidth = 0.7) +
  facet_wrap(~panel, nrow = 1) +
  scale_color_manual(values = ARM_COLORS) +
  scale_fill_manual(values = ARM_COLORS) +
  scale_linetype_manual(values = ARM_LINES) +
  scale_x_continuous(breaks = seq(0, 60, 20)) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.04))) +
  labs(x = "Days since filing", y = "Cumulative share responding (%)") +
  theme_rti()
save_fig(fig_km_letter, "fig_km_letter", height = 3.0)

save_fig_note(
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
OUTCOME_COLORS <- c(
  "Full information" = "#155a9e", "Partial information" = "#6aa6e8", "Fee demanded" = "#eda100",
  "Denied" = "#8f2d56", "Returned" = "#eb6834", "Transferred" = "#6250d6",
  "Reply, not yet coded" = "#9a9892", "No response" = "#e8e7e3"
)

outcome_shares <- eligible |>
  count(state_name, outcome, .drop = FALSE) |>
  group_by(state_name) |>
  mutate(
    share = 100 * n / sum(n), total = sum(n),
    outcome = factor(outcome, levels = names(OUTCOME_COLORS))
  ) |>
  arrange(outcome, .by_group = TRUE) |>
  mutate(mid = cumsum(share) - share / 2) |>
  ungroup() |>
  mutate(
    state_lab = sprintf("%s (%d)", state_name, total),
    state_lab = fct_rev(factor(state_lab, levels = unique(state_lab[order(state_name)])))
  )

fig_outcomes <- ggplot(outcome_shares, aes(share, state_lab, fill = outcome)) +
  geom_col(
    width = 0.62, color = "white", linewidth = 0.4,
    position = position_stack(reverse = TRUE)
  ) +
  geom_text(
    data = filter(outcome_shares, share >= 8), inherit.aes = FALSE,
    aes(
      x = mid, y = state_lab, label = sprintf("%.0f", share),
      color = outcome %in% c("Full information", "Denied", "Transferred")
    ),
    size = 2.8, family = "serif", show.legend = FALSE
  ) +
  scale_color_manual(values = c(`TRUE` = "white", `FALSE` = INK), guide = "none") +
  scale_fill_manual(values = OUTCOME_COLORS, guide = guide_legend(nrow = 2, byrow = TRUE)) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.01))) +
  labs(x = "Share of applications past day 30 (%)", y = NULL) +
  theme_rti() +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = GRID, linewidth = 0.3),
    axis.line.x = element_blank(),
    legend.key.width = unit(0.8, "lines"), legend.key.height = unit(0.7, "lines")
  )
save_fig(fig_outcomes, "fig_outcomes", height = 2.9)

save_fig_note(
  "fig_outcomes",
  "What has come back so far, by state",
  sprintf(paste0(
    "Applications past day 30, status as of %s, whenever the reply came. N in ",
    "parentheses; segments of 8\\%% or more are labeled. First-pass coding of ",
    "reply documents, not yet double-coded. Telangana is a lower bound because ",
    "its portal sends no status emails."
  ), format(AS_OF, "%d %B"))
)

# Figure: response by government function ----
function_rates <- eligible |>
  filter(state != "TG") |>
  group_by(function_name) |>
  summarise(n = n(), k = sum(any_30 == 100), rate = 100 * k / n, .groups = "drop") |>
  mutate(
    lo = wilson(k, n)$lo, hi = wilson(k, n)$hi,
    lab = sprintf("%s (%d)", function_name, n),
    lab = fct_reorder(lab, rate)
  )

fig_function <- ggplot(function_rates, aes(rate, lab)) +
  geom_linerange(aes(xmin = lo, xmax = hi), color = "#2a78d6", linewidth = 0.6) +
  geom_point(color = "#2a78d6", size = 2) +
  scale_x_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.03))) +
  labs(x = "Any response within 30 days (%)", y = NULL) +
  theme_rti() +
  theme(
    panel.grid.major.y = element_line(color = GRID, linewidth = 0.3),
    panel.grid.major.x = element_line(color = GRID, linewidth = 0.3)
  )
save_fig(fig_function, "fig_function", height = 3.0)

save_fig_note(
  "fig_function",
  "Any response within 30 days, by government function",
  paste0(
    "Applications past day 30, excluding Telangana. N in parentheses; bars are ",
    "Wilson 95\\% intervals. Any response: any office action, including a ",
    "transfer or fee demand. Function is keyword-coded from department and ",
    "office names (crosswalk in data/cleaned/). Pooled across states, so state ",
    "differences are not removed."
  )
)

# Headline numbers, for independent checking ----
## legal_any comes first: summarise() evaluates in order, and any_30 is overwritten by its count
## below
summarise_headline <- function(d) {
  d |> summarise(
    n = n(), legal_n = sum(legal), legal_any = sum(any_30 == 100 & legal == 1),
    any_30 = sum(any_30 == 100), reply_30 = sum(reply_30 == 100), info_30 = sum(info_30 == 100),
    .groups = "drop"
  )
}
headline <- bind_rows(
  eligible |> group_by(sample = state) |> summarise_headline(),
  eligible |> mutate(sample = "ALL") |> group_by(sample) |> summarise_headline()
)
write_csv(headline, file.path(PATHS$tables, "headline_numbers.csv"))
