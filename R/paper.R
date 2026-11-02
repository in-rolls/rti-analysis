format_count <- function(x) ifelse(is.na(x), "", formatC(x, format = "d", big.mark = ","))
format_estimate <- function(x) {
  x <- round(x, 1)
  x[!is.na(x) & x == 0] <- 0
  ifelse(is.na(x), "", sub("^-", "$-$", sprintf("%.1f", x)))
}
format_decimal <- function(x) ifelse(is.na(x), "", sprintf("%.2f", x))
format_p_value <- function(p) ifelse(is.na(p), "", ifelse(p < 0.001, "$<$0.001", sprintf("%.3f", p)))
format_standard_error <- function(x) ifelse(is.na(x), "", sprintf("(%.1f)", x))
format_interval <- function(lo, hi) sprintf("[%.1f, %.1f]", lo, hi)

format_table_row <- function(...) paste0(paste(c(...), collapse = " & "), " \\\\")
format_table_panel <- function(text, ncol) {
  sprintf(paste0(
    "\\addlinespace\\multicolumn{%d}{l}{\\textit{%s}} \\\\"
  ), ncol, text)
}

state_colors <- c(
  "Tamil Nadu" = "#2a78d6", "Telangana" = "#eb6834", "Karnataka" = "#1baf7a",
  "Delhi" = "#eda100", "Maharashtra" = "#e87ba4"
)
state_lines <- c(
  "Tamil Nadu" = "solid", "Telangana" = "dashed", "Karnataka" = "solid",
  "Delhi" = "dotdash", "Maharashtra" = "longdash"
)
arm_colors <- c("Plain" = "#52514e", "Legal salience" = "#2a78d6")
arm_lines <- c("Plain" = "dashed", "Legal salience" = "solid")
ink <- "#0b0b0b"
ink_2 <- "#52514e"
grid <- "#e8e7e3"

theme_rti <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size, base_family = "sans") +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(color = grid, linewidth = 0.3),
      axis.line.x = ggplot2::element_line(color = ink_2, linewidth = 0.3),
      axis.ticks.x = ggplot2::element_line(color = ink_2, linewidth = 0.3),
      axis.text = ggplot2::element_text(color = ink_2),
      axis.title = ggplot2::element_text(color = ink),
      strip.text = ggplot2::element_text(color = ink, face = "plain", hjust = 0),
      legend.position = "bottom",
      legend.title = ggplot2::element_blank(),
      legend.text = ggplot2::element_text(color = ink),
      legend.key.width = ggplot2::unit(1.6, "lines"),
      legend.margin = ggplot2::margin(0, 0, 0, 0),
      plot.margin = ggplot2::margin(4, 8, 2, 2)
    )
}

save_figure <- function(plot, name, width = 6.3, height = 3.5) {
  ggplot2::ggsave(file.path(paths$figures, paste0(name, ".pdf")), plot,
    width = width, height = height,
    device = pdf, useDingbats = FALSE, timestamp = FALSE
  )
}

# Table helpers ----
## One self-contained .tex per table: caption on top, a short note underneath.
save_table <- function(name, caption, notes, colspec, header, body, size = "\\small") {
  if (nchar(notes) > note_limit) {
    stop(
      "Table note too long: ", name, " (", nchar(notes),
      " characters)"
    )
  }
  lines <- c(
    "\\begin{table}[!htbp]", "\\centering",
    sprintf("\\caption{%s}", caption), sprintf("\\label{tab:%s}", name), size,
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", sprintf("\\begin{tabular}{%s}", colspec), "\\toprule",
    header, "\\midrule", body, "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}[flushleft]\\footnotesize",
    sprintf("\\item \\textit{Notes:} %s", notes),
    "\\end{tablenotes}", "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
  )
  writeLines(lines, file.path(paths$tables, paste0(name, ".tex")))
}

## Same discipline for figure notes; the note is read back when the document is assembled
save_figure_note <- function(name, caption, notes) {
  if (nchar(notes) > note_limit) {
    stop(
      "Figure note too long: ", name, " (", nchar(notes),
      " characters)"
    )
  }
  lines <- c(
    "\\begin{figure}[!htbp]", "\\centering",
    sprintf("\\caption{%s}", caption), sprintf("\\label{fig:%s}", name),
    sprintf("\\includegraphics[width=\\textwidth]{%s.pdf}", name),
    "\\begin{minipage}{\\textwidth}\\footnotesize",
    sprintf("\\textit{Notes:} %s", notes), "\\end{minipage}", "\\end{figure}"
  )
  writeLines(lines, file.path(paths$figures, paste0(name, ".tex")))
}

write_macros <- function(values, path) {
  names <- paste0("rti", gsub("_", "", tolower(names(values)), fixed = TRUE))
  names <- gsub("30", "thirty", names, fixed = TRUE)
  stopifnot(!anyDuplicated(names), all(grepl("^[A-Za-z]+$", names)))
  writeLines(sprintf("\\newcommand{\\%s}{%s}", names, values), path)
}
