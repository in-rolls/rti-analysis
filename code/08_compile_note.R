# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 08_compile_note.R
### Assembles and compiles output/first_cut_note.pdf, records package versions, copies outputs
### (never data) to the Overleaf project when that folder exists.
# ----
if (!exists("rti")) source(here::here("code", "02_load_packages_and_data.R"))

# Exhibit order ----
exhibits <- c("tables/tab_sample", "figures/fig_filings",
              "tables/tab_response_state", "figures/fig_outcomes", "figures/fig_km_state",
              "tables/tab_speed", "tables/tab_response_letter", "figures/fig_km_letter",
              "tables/tab_cuts", "figures/fig_function", "tables/tab_filer",
              "tables/tab_content", "tables/tab_calls", "tables/tab_balance",
              "tables/tab_main", "tables/tab_robust", "figures/fig_horizon", "tables/tab_correlates")

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
  "\\begin{document}",
  "\\maketitle",
  sprintf("\\input{%s}\n\\FloatBarrier", exhibits),
  "\\end{document}")

writeLines(doc, here("output", "first_cut_note.tex"))

# Compile twice ----
old_wd <- setwd(here("output"))
for (i in 1:2) {
  status <- system2("pdflatex", c("-interaction=nonstopmode", "-halt-on-error", "first_cut_note.tex"),
                    stdout = FALSE, stderr = FALSE)
  if (status != 0) {
    setwd(old_wd)
    stop("pdflatex failed; see output/first_cut_note.log")
  }
}
unlink(c("first_cut_note.aux", "first_cut_note.out", "first_cut_note.log"))
setwd(old_wd)

# Record package versions ----
pkgs <- sessionInfo()
pkg_info <- bind_rows(
  tibble(package = "R", version = paste(R.version$major, R.version$minor, sep = ".")),
  map_dfr(names(pkgs$otherPkgs), \(p) tibble(package = p, version = as.character(packageVersion(p)))))
dir.create(here("other"), showWarnings = FALSE)
write_csv(pkg_info, here("other", "R_packages_info.csv"))

# Copy outputs to Overleaf ----
overleaf <- file.path(path.expand("~"), "Dropbox/Apps/Overleaf/rti/first_cut")
if (dir.exists(dirname(overleaf))) {
  dir.create(file.path(overleaf, "tables"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(overleaf, "figures"), recursive = TRUE, showWarnings = FALSE)
  file.copy(here("output", c("first_cut_note.tex", "first_cut_note.pdf")), overleaf, overwrite = TRUE)
  file.copy(list.files(PATHS$tables, pattern = "\\.tex$", full.names = TRUE), file.path(overleaf, "tables"), overwrite = TRUE)
  file.copy(list.files(PATHS$figures, pattern = "\\.(tex|pdf)$", full.names = TRUE), file.path(overleaf, "figures"), overwrite = TRUE)
}

cat("Note compiled: output/first_cut_note.pdf\n")
