frame_sizes <- readr::read_csv(here::here("data", "derived", "frame_sizes.csv"), show_col_types = FALSE)

# Table: sample and filing by state ----
sample_row <- function(applications, label, frame = NA) {
  fd <- applications |> dplyr::filter(filed == 1L, !is.na(filing_date))
  e <- applications |> dplyr::filter(past30 == 1L)
  format_table_row(
    label, format_count(frame), format_count(nrow(applications)),
    paste0(format_count(sum(applications$legal == 0)), " / ", format_count(sum(applications$legal == 1))),
    format_count(sum(applications$filed)), format_estimate(100 * mean(applications$filed)), format_count(nrow(e)),
    sprintf("%s to %s", format(min(fd$filing_date), "%d %b"), format(max(fd$filing_date), "%d %b"))
  )
}

body <- c(
  purrr::map_chr(state_order, \(s) {
    sample_row(
      dplyr::filter(rti, state == s), state_labels[[s]],
      frame_sizes$frame_n[frame_sizes$state == s]
    )
  }),
  "\\midrule", sample_row(rti, "All", sum(frame_sizes$frame_n))
)

save_table(
  "tab_sample",
  "Sample and filing by state",
  sprintf(
    paste0(
      "Data as of %s. Past day 30: filed by %s, so the 30-day limit in s.7(1) ",
      "has passed. Tamil Nadu is drawn by department $\\times$ tier quotas, ",
      "other states proportionally to department group with a cap."
    ),
    format(as_of, "%d %B %Y"), format(as_of - 30, "%d %B")
  ),
  "lrrrrrrl",
  paste0(format_table_row(
    "State", "Frame", "Drawn", "Plain / legal", "Filed", "Filed (\\%)",
    "Past day 30", "Filing window"
  )),
  body
)

# Table: does the letter predict filing or reaching day 30? ----
## Within randomization blocks. Singletons drop out with the block fixed effect.
balance_row <- function(applications, label) {
  est <- function(y) {
    ## Delhi is fully filed in both arms, so there is nothing to test there
    if (dplyr::n_distinct(applications[[y]]) == 1) {
      return(list(b = NA_real_, p = NA_real_))
    }
    model <- fixest::feols(as.formula(paste0(y, " ~ legal | block")),
      data = dplyr::mutate(applications, filed = 100 * filed, past30 = 100 * past30),
      vcov = "hetero", fixef.rm = "singleton"
    )
    list(b = coef(model)[["legal"]], p = fixest::pvalue(model)[["legal"]])
  }
  fl <- est("filed")
  pa <- est("past30")
  format_table_row(
    label, format_count(nrow(applications)),
    format_estimate(100 * mean(applications$filed[applications$legal == 0])),
    format_estimate(100 * mean(applications$filed[applications$legal == 1])), format_p_value(fl$p),
    format_estimate(100 * mean(applications$past30[applications$legal == 0])),
    format_estimate(100 * mean(applications$past30[applications$legal == 1])), format_p_value(pa$p)
  )
}

tn_tier <- eligible |>
  dplyr::filter(tn) |>
  dplyr::count(tier, legal) |>
  tidyr::pivot_wider(names_from = legal, values_from = n, values_fill = 0, names_prefix = "arm") |>
  dplyr::mutate(tier = factor(tier, levels = c("Department", "Head of Department", "Sub Office"))) |>
  dplyr::arrange(tier)

tn_drawn <- rti |>
  dplyr::filter(tn) |>
  dplyr::group_by(tier) |>
  dplyr::summarise(share = 100 * mean(legal), .groups = "drop")

tier_rows <- tn_tier |>
  dplyr::left_join(tn_drawn, by = "tier") |>
  purrr::pmap_chr(\(tier, arm0, arm1, share) {
    format_table_row(
      as.character(tier), format_count(arm0 + arm1), format_count(arm0), format_count(arm1), "",
      format_estimate(100 * arm1 / (arm0 + arm1)), format_estimate(share), ""
    )
  })

body <- c(
  format_table_panel("Panel A. All drawn applications", 8),
  purrr::map_chr(state_order, \(s) balance_row(dplyr::filter(rti, state == s), state_labels[[s]])),
  "\\midrule",
  format_table_panel("Panel B. Tamil Nadu past day 30, by tier", 8),
  format_table_row("", "N", "Plain", "Legal", "", "Legal (\\%)", "Drawn (\\%)", ""),
  tier_rows
)

header <- paste(
  "& & \\multicolumn{3}{c}{Filed (\\%)} & \\multicolumn{3}{c}{Past day 30 (\\%)} \\\\",
  "\\cmidrule(lr){3-5}\\cmidrule(lr){6-8}",
  format_table_row("State", "N", "Plain", "Legal", "$p$", "Plain", "Legal", "$p$")
)

save_table(
  "tab_balance",
  "Does the letter predict who is filed and who has reached day 30?",
  sprintf(
    paste0(
      "Past day 30: filed by %s. Panel A: $p$-values on the letter in a linear ",
      "probability model with randomization-block fixed effects and robust SEs. ",
      "Panel B: counts, with the legal share among them and among all drawn in ",
      "that tier. All 7 department-tier filings past day 30 got the legal letter."
    ),
    format(as_of - 30, "%d %B")
  ),
  "lrrrrrrr", header, body
)

# Figure: cumulative filings ----
cum_filings <- filed |>
  dplyr::filter(!is.na(filing_date)) |>
  dplyr::count(state_name, filing_date) |>
  dplyr::group_by(state_name) |>
  dplyr::arrange(filing_date) |>
  dplyr::mutate(cum = cumsum(n)) |>
  dplyr::ungroup()

fig_filings <- ggplot2::ggplot(cum_filings, ggplot2::aes(filing_date, cum,
  color = state_name,
  linetype = state_name
)) +
  ggplot2::geom_vline(xintercept = as_of - 30, color = ink_2, linewidth = 0.3, linetype = "dotted") +
  ggplot2::annotate("text",
    x = as_of - 31, y = 500, label = "Filed before this line:\npast day 30", hjust = 1, vjust = 1,
    size = 2.9, color = ink_2, family = "sans", lineheight = 0.95
  ) +
  ggplot2::geom_step(linewidth = 0.8) +
  ggplot2::scale_color_manual(values = state_colors) +
  ggplot2::scale_linetype_manual(values = state_lines) +
  ggplot2::scale_x_date(date_breaks = "2 weeks", date_labels = "%d %b") +
  ggplot2::labs(x = "Filing date", y = "Applications filed (cumulative)") +
  theme_rti()
save_figure(fig_filings, "fig_filings", height = 3.2)

save_figure_note(
  "fig_filings",
  "Cumulative filings by state",
  sprintf(paste0(
    "One line per state; %s applications have a filing date, from the portal ",
    "acknowledgment where one exists, otherwise the RA sheet. Applications ",
    "filed before the dotted line have passed the 30-day limit in s.7(1)."
  ), format_count(nrow(dplyr::filter(filed, !is.na(filing_date)))))
)
