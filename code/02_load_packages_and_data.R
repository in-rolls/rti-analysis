# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 02_load_packages_and_data.R
### Loads packages and the cleaned analysis file, and sets the theme and table helpers.
# ----
# Load required packages ----
pacman::p_load(
  dplyr, tidyr, purrr, readr, stringr, forcats, ggplot2, lubridate, fixest, survival,
  scales, here
)

source(here("code", "00_config.R"))
source(here("code", "00_utils.R"))

options(scipen = 999)
setFixest_notes(FALSE)

# Set seed for reproducibility ----
set.seed(SEED)

# Paths ----
PATHS <- list(tables = here("output", "tables"), figures = here("output", "figures"))
walk(PATHS, dir.create, recursive = TRUE, showWarnings = FALSE)

# Load data ----
rti <- read_rds(here("data", "cleaned", "analysis.rds"))
filed <- rti |> filter(filed == 1L)
eligible <- rti |> filter(past30 == 1L)

## Samples for the arm comparisons. Never one pooled design: randomization differs in Tamil Nadu.
SAMPLES <- list(
  "Tamil Nadu" = \(d) filter(d, state == "TN"),
  "Other states" = \(d) filter(d, state != "TN"),
  "Excl. Telangana" = \(d) filter(d, !state %in% c("TN", "TG"))
)

# Figure theme ----
## Palette checked with the dataviz validator: slots pass CVD separation. Three fall below 3:1
## contrast on white, so every state and arm also has its own linetype and a legend.
STATE_COLORS <- c(
  "Tamil Nadu" = "#2a78d6", "Telangana" = "#eb6834", "Karnataka" = "#1baf7a",
  "Delhi" = "#eda100", "Maharashtra" = "#e87ba4"
)
STATE_LINES <- c(
  "Tamil Nadu" = "solid", "Telangana" = "dashed", "Karnataka" = "solid",
  "Delhi" = "dotdash", "Maharashtra" = "longdash"
)
ARM_COLORS <- c("Plain" = "#52514e", "Legal salience" = "#2a78d6")
ARM_LINES <- c("Plain" = "dashed", "Legal salience" = "solid")
INK <- "#0b0b0b"
INK_2 <- "#52514e"
GRID <- "#e8e7e3"

theme_rti <- function(base_size = 9.5) {
  theme_minimal(base_size = base_size, base_family = "serif") +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(color = GRID, linewidth = 0.3),
      axis.line.x = element_line(color = INK_2, linewidth = 0.3),
      axis.ticks.x = element_line(color = INK_2, linewidth = 0.3),
      axis.text = element_text(color = INK_2),
      axis.title = element_text(color = INK),
      strip.text = element_text(color = INK, face = "plain", hjust = 0),
      legend.position = "bottom",
      legend.title = element_blank(),
      legend.text = element_text(color = INK),
      legend.key.width = unit(1.6, "lines"),
      legend.margin = margin(0, 0, 0, 0),
      plot.margin = margin(4, 8, 2, 2)
    )
}

save_fig <- function(plot, name, width = 6.3, height = 3.5) {
  ggsave(file.path(PATHS$figures, paste0(name, ".pdf")), plot,
    width = width, height = height,
    device = pdf, useDingbats = FALSE, timestamp = FALSE
  )
}

# Table helpers ----
## One self-contained .tex per table: caption on top, a short note underneath.
save_table <- function(name, caption, notes, colspec, header, body, size = "\\small") {
  if (nchar(notes) > NOTE_LIMIT) {
    stop(
      "Table note too long: ", name, " (", nchar(notes),
      " characters)"
    )
  }
  lines <- c(
    "\\begin{table}[!htbp]", "\\centering",
    sprintf("\\caption{%s}", caption), sprintf("\\label{tab:%s}", name), size,
    "\\begin{threeparttable}", sprintf("\\begin{tabular}{%s}", colspec), "\\toprule",
    header, "\\midrule", body, "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}[flushleft]\\footnotesize",
    sprintf("\\item \\textit{Notes:} %s", notes),
    "\\end{tablenotes}", "\\end{threeparttable}", "\\end{table}"
  )
  writeLines(lines, file.path(PATHS$tables, paste0(name, ".tex")))
}

## Same discipline for figure notes; the note is read back when the document is assembled
save_fig_note <- function(name, caption, notes) {
  if (nchar(notes) > NOTE_LIMIT) {
    stop(
      "Figure note too long: ", name, " (", nchar(notes),
      " characters)"
    )
  }
  lines <- c(
    "\\begin{figure}[!htbp]", "\\centering",
    sprintf("\\caption{%s}", caption), sprintf("\\label{fig:%s}", name),
    sprintf("\\includegraphics[width=\\textwidth]{figures/%s.pdf}", name),
    "\\begin{minipage}{\\textwidth}\\footnotesize",
    sprintf("\\textit{Notes:} %s", notes), "\\end{minipage}", "\\end{figure}"
  )
  writeLines(lines, file.path(PATHS$figures, paste0(name, ".tex")))
}
