source("scripts/00_config.R")
set.seed(seed)

source("scripts/01_prepare_data.R", local = new.env(parent = globalenv()))
rti <- readr::read_rds(here::here("data", "derived", "analysis.rds"))
filed <- dplyr::filter(rti, filed == 1L)
eligible <- dplyr::filter(rti, past30 == 1L)

stages <- c(
  "02_summarize_filings.R",
  "03_summarize_responses.R",
  "04_summarize_content.R",
  "05_estimate_effects.R",
  "06_estimate_correlates.R",
  "07_audit_data.R",
  "08_write_paper_values.R"
)
for (stage in stages) {
  message("Running ", stage)
  sys.source(file.path("scripts", stage), envir = new.env(parent = globalenv()))
}
