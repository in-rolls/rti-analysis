# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 03_filing_and_balance.R
### Sample and filing progress, whether the letter predicts being filed or reaching day 30, Figure 1.
# ----
if (!exists("rti")) source(here::here("code", "02_load_packages_and_data.R"))

frame_sizes <- read_csv(here("data", "raw", "snapshot_2026-10-29", "frame_sizes.csv"), show_col_types = FALSE)

# Table: sample and filing by state ----
sample_row <- function(d, label, frame = NA) {
  fd <- d %>% filter(filed == 1L, !is.na(filing_date))
  e <- d %>% filter(past30 == 1L)
  tab_row(label, f0(frame), f0(nrow(d)), paste0(f0(sum(d$legal == 0)), " / ", f0(sum(d$legal == 1))),
          f0(sum(d$filed)), f1(100 * mean(d$filed)), f0(nrow(e)),
          sprintf("%s to %s", format(min(fd$filing_date), "%d %b"), format(max(fd$filing_date), "%d %b")))
}

body <- c(map_chr(STATE_ORDER, \(s) sample_row(filter(rti, state == s), STATE_LABELS[[s]],
                                               frame_sizes$frame_n[frame_sizes$state == s])),
          "\\midrule", sample_row(rti, "All", sum(frame_sizes$frame_n)))

save_table("tab_sample",
  "Sample and filing by state",
  sprintf("Data as of %s. Past day 30: filed by %s, so the 30-day limit in s.7(1) has passed. Tamil Nadu is drawn by department $\\times$ tier quotas, other states proportionally to department group with a cap.",
          format(AS_OF, "%d %B %Y"), format(AS_OF - 30, "%d %B")),
  "lrrrrrrl",
  paste0(tab_row("State", "Frame", "Drawn", "Plain / legal", "Filed", "Filed (\\%)", "Past day 30", "Filing window")),
  body)

# Table: does the letter predict filing or reaching day 30? ----
## Within randomization blocks. Singletons drop out with the block fixed effect.
balance_row <- function(d, label) {
  est <- function(y) {
    ## Delhi is fully filed in both arms, so there is nothing to test there
    if (n_distinct(d[[y]]) == 1) return(list(b = NA_real_, p = NA_real_))
    m <- feols(as.formula(paste0(y, " ~ legal | block")), data = mutate(d, filed = 100 * filed, past30 = 100 * past30),
               vcov = "hetero", fixef.rm = "singleton")
    list(b = coef(m)[["legal"]], p = fixest::pvalue(m)[["legal"]])
  }
  fl <- est("filed"); pa <- est("past30")
  tab_row(label, f0(nrow(d)),
          f1(100 * mean(d$filed[d$legal == 0])), f1(100 * mean(d$filed[d$legal == 1])), f_p(fl$p),
          f1(100 * mean(d$past30[d$legal == 0])), f1(100 * mean(d$past30[d$legal == 1])), f_p(pa$p))
}

tn_tier <- eligible %>%
  filter(tn) %>%
  count(tier, legal) %>%
  pivot_wider(names_from = legal, values_from = n, values_fill = 0, names_prefix = "arm") %>%
  mutate(tier = factor(tier, levels = c("Department", "Head of Department", "Sub Office"))) %>%
  arrange(tier)

tn_drawn <- rti %>%
  filter(tn) %>%
  group_by(tier) %>%
  summarise(share = 100 * mean(legal), .groups = "drop")

tier_rows <- tn_tier %>%
  left_join(tn_drawn, by = "tier") %>%
  pmap_chr(\(tier, arm0, arm1, share) {
    tab_row(as.character(tier), f0(arm0 + arm1), f0(arm0), f0(arm1), "",
            f1(100 * arm1 / (arm0 + arm1)), f1(share), "")
  })

body <- c(tab_panel("Panel A. All drawn applications", 8),
          map_chr(STATE_ORDER, \(s) balance_row(filter(rti, state == s), STATE_LABELS[[s]])),
          "\\midrule",
          tab_panel("Panel B. Tamil Nadu past day 30, by tier", 8),
          tab_row("", "N", "Plain", "Legal", "", "Legal (\\%)", "Drawn (\\%)", ""),
          tier_rows)

header <- paste(
  "& & \\multicolumn{3}{c}{Filed (\\%)} & \\multicolumn{3}{c}{Past day 30 (\\%)} \\\\",
  "\\cmidrule(lr){3-5}\\cmidrule(lr){6-8}",
  tab_row("State", "N", "Plain", "Legal", "$p$", "Plain", "Legal", "$p$"))

save_table("tab_balance",
  "Does the letter predict who is filed and who has reached day 30?",
  sprintf("Past day 30: filed by %s. Panel A: $p$-values on the letter in a linear probability model with randomization-block fixed effects and robust SEs. Panel B: counts, with the legal share among them and among all drawn in that tier. All 7 department-tier filings past day 30 got the legal letter.",
          format(AS_OF - 30, "%d %B")),
  "lrrrrrrr", header, body)

# Figure: cumulative filings ----
cum_filings <- filed %>%
  filter(!is.na(filing_date)) %>%
  count(state_name, filing_date) %>%
  group_by(state_name) %>%
  arrange(filing_date) %>%
  mutate(cum = cumsum(n)) %>%
  ungroup()

fig_filings <- ggplot(cum_filings, aes(filing_date, cum, color = state_name, linetype = state_name)) +
  geom_vline(xintercept = AS_OF - 30, color = INK_2, linewidth = 0.3, linetype = "dotted") +
  annotate("text", x = AS_OF - 31, y = 500, label = "Filed before this line:\npast day 30", hjust = 1, vjust = 1,
           size = 2.9, color = INK_2, family = "serif", lineheight = 0.95) +
  geom_step(linewidth = 0.8) +
  scale_color_manual(values = STATE_COLORS) +
  scale_linetype_manual(values = STATE_LINES) +
  scale_x_date(date_breaks = "2 weeks", date_labels = "%d %b") +
  labs(x = "Filing date", y = "Applications filed (cumulative)") +
  theme_rti()
save_fig(fig_filings, "fig_filings", height = 3.2)

save_fig_note("fig_filings",
  "Cumulative filings by state",
  sprintf("One line per state; %s applications have a filing date, from the portal acknowledgment where one exists, otherwise the RA sheet. Applications filed before the dotted line have passed the 30-day limit in s.7(1).", f0(nrow(filter(filed, !is.na(filing_date))))))
