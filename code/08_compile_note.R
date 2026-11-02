# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 08_compile_note.R
### Assembles and compiles output/first_cut_note.pdf, records package versions, copies outputs
### (never data) to the Overleaf project when that folder exists.
# ----
if (!exists("rti")) source(here::here("code", "02_load_packages_and_data.R"))

# Exhibit order ----
exhibits <- c(
  "tables/tab_sample", "figures/fig_filings",
  "tables/tab_response_state", "figures/fig_outcomes", "figures/fig_km_state",
  "tables/tab_speed", "tables/tab_response_letter", "figures/fig_km_letter",
  "tables/tab_cuts", "figures/fig_function", "tables/tab_filer",
  "tables/tab_content", "tables/tab_calls", "tables/tab_balance",
  "tables/tab_main", "tables/tab_robust", "figures/fig_horizon", "tables/tab_correlates",
  "tables/tab_audit", "tables/tab_coding"
)

doc <- c(
  "\\documentclass[11pt]{article}",
  "\\usepackage[margin=1in]{geometry}",
  "\\usepackage{mathptmx}",
  "\\usepackage[T1]{fontenc}",
  "\\usepackage{booktabs,threeparttable,graphicx,placeins}",
  "\\usepackage[font=normalsize,labelfont=bf,skip=6pt]{caption}",
  "\\setlength{\\parindent}{0pt}",
  "\\setlength{\\textfloatsep}{14pt plus 2pt minus 2pt}",
  "\\setlength{\\floatsep}{16pt plus 2pt minus 2pt}",
  "\\renewcommand{\\topfraction}{0.95}",
  "\\renewcommand{\\bottomfraction}{0.9}",
  "\\renewcommand{\\textfraction}{0.05}",
  "\\renewcommand{\\floatpagefraction}{0.8}",
  "\\title{Does RTI work? First-cut tables and figures}",
  "\\author{Amar and Sood}",
  sprintf("\\date{Data as of %s}", format(AS_OF, "%d %B %Y")),
  "\\pdftrailerid{}",
  "\\begin{document}",
  "\\maketitle",
  sprintf("\\input{%s}\n\\FloatBarrier", exhibits),
  "\\end{document}"
)

writeLines(doc, here("output", "first_cut_note.tex"))

# Compile twice ----
## Fixed dates, so that recompiling the same inputs gives the same PDF
Sys.setenv(SOURCE_DATE_EPOCH = as.numeric(as.POSIXct(AS_OF, tz = "UTC")), FORCE_SOURCE_DATE = "1")
old_wd <- setwd(here("output"))
for (i in 1:2) {
  status <- system2("pdflatex", c(
    "-interaction=nonstopmode", "-halt-on-error",
    "first_cut_note.tex"
  ),
  stdout = FALSE, stderr = FALSE
  )
  if (status != 0) {
    setwd(old_wd)
    stop("pdflatex failed; see output/first_cut_note.log")
  }
}
unlink(c("first_cut_note.aux", "first_cut_note.out", "first_cut_note.log"))
setwd(old_wd)

# README ----
## Generated from docs/README.md.in, so the numbers it quotes cannot go stale.
by_state <- read_csv(file.path(PATHS$tables, "response_by_state.csv"), show_col_types = FALSE)
effects <- read_csv(file.path(PATHS$tables, "main_effects.csv"), show_col_types = FALSE)

rate <- \(sample, y = "any") sprintf("%.1f", by_state[[y]][by_state$sample == sample])
effect <- \(sample, y) sprintf("%.1f", effects[[y]][effects$sample == sample])

display_order <- c(
  "Tamil Nadu", "Tamil Nadu, tier-standardized", "Telangana", "Karnataka", "Delhi",
  "Maharashtra", "All states", "All excl. Telangana"
)
results_table <- c(
  "| State | Past day 30 | Any response (%) | Reply (%) | Information supplied (%) |",
  "| --- | ---: | ---: | ---: | ---: |",
  map_chr(display_order, \(s) {
    n <- by_state$n[by_state$sample == s]
    sprintf(
      "| %s | %s | %s | %s | %s |", s, ifelse(is.na(n), "", f0(n)), rate(s), rate(s, "reply"),
      rate(s, "info")
    )
  })
)

coding_agreement <- read_csv(file.path(PATHS$tables, "coding_agreement.csv"),
  show_col_types = FALSE
)
agree_rate <- \(m) sprintf("%.0f", coding_agreement$agree[coding_agreement$measure == m])
n_coded <- sum(rti$coded)
n_full <- sum(rti$disposition == "full", na.rm = TRUE)
n_informed <- sum(rti$disposition %in% c("full", "partial"))

fill <- c(
  N_CODED = f0(n_coded), N_FULL = f0(n_full), N_INFORMED = f0(n_informed),
  AGREE_INFO = agree_rate("information"), AGREE_DISP = agree_rate("disposition"),
  AS_OF = format(AS_OF, "%d %B %Y"), N_DRAWN = f0(nrow(rti)), N_FILED = f0(sum(rti$filed)),
  N_PAST30 = f0(sum(rti$past30)), RESULTS_TABLE = paste(results_table, collapse = "\n"),
  ANY_EXTG = rate("All excl. Telangana"), INFO_EXTG = rate("All excl. Telangana", "info"),
  ANY_TN = rate("Tamil Nadu"), ANY_TN_W = rate("Tamil Nadu, tier-standardized"),
  ANY_KA = rate("Karnataka"), ANY_TG = rate("Telangana"),
  B_TN = effect("Tamil Nadu", "b"), SE_TN = effect("Tamil Nadu", "se"),
  MDE_TN = effect("Tamil Nadu", "mde"),
  B_OTHER = effect("Other states", "b"), SE_OTHER = effect("Other states", "se"),
  MDE_OTHER = effect("Other states", "mde"),
  B_EXTG = effect("Excl. Telangana", "b"), SE_EXTG = effect("Excl. Telangana", "se"),
  MDE_EXTG = effect("Excl. Telangana", "mde")
)

readme <- readLines(here("docs", "README.md.in"))
for (key in names(fill)) readme <- gsub(paste0("@@", key, "@@"), fill[[key]], readme, fixed = TRUE)
writeLines(readme, here("README.md"))

# Manuscript uses the same computed values as the README.
paper <- readLines(here("ms", "paper.tex.in"))
for (key in names(fill)) paper <- gsub(paste0("@@", key, "@@"), fill[[key]], paper, fixed = TRUE)
if (any(grepl("@@", paper, fixed = TRUE))) stop("Unresolved manuscript value")
writeLines(paper, here("output", "paper.tex"))
old_wd <- setwd(here("output"))
for (i in 1:2) {
  status <- system2("pdflatex", c(
    "-interaction=nonstopmode", "-halt-on-error", "paper.tex"
  ), stdout = FALSE, stderr = FALSE)
  if (status != 0) {
    setwd(old_wd)
    stop("pdflatex failed; see output/paper.log")
  }
}
setwd(old_wd)

# Record package versions ----
pkgs <- sessionInfo()
pkg_info <- bind_rows(
  tibble(package = "R", version = paste(R.version$major, R.version$minor, sep = ".")),
  map_dfr(names(pkgs$otherPkgs), \(p) {
    tibble(package = p, version = as.character(packageVersion(p)))
  })
)
dir.create(here("other"), showWarnings = FALSE)
write_csv(pkg_info, here("other", "R_packages_info.csv"))

# Copy outputs to Overleaf ----
overleaf <- file.path(path.expand("~"), "Dropbox/Apps/Overleaf/rti/first_cut")
if (dir.exists(dirname(overleaf))) {
  dir.create(file.path(overleaf, "tables"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(overleaf, "figures"), recursive = TRUE, showWarnings = FALSE)
  file.copy(here("output", c("first_cut_note.tex", "first_cut_note.pdf")), overleaf,
    overwrite = TRUE
  )
  file.copy(list.files(PATHS$tables, pattern = "\\.tex$", full.names = TRUE), file.path(
    overleaf,
    "tables"
  ), overwrite = TRUE)
  file.copy(list.files(PATHS$figures, pattern = "\\.(tex|pdf)$", full.names = TRUE),
    file.path(overleaf, "figures"),
    overwrite = TRUE
  )
}

cat("Note compiled: output/first_cut_note.pdf\n")
