root <- normalizePath(file.path("..", ".."))

suppressPackageStartupMessages({
  library(dplyr)
  library(fixest)
  library(lubridate)
  library(purrr)
  library(stringr)
  library(survival)
})
setFixest_notes(FALSE)

source(file.path(root, "code", "00_config.R"))
source(file.path(root, "code", "00_utils.R"))

read_analysis <- function() readRDS(file.path(root, "data", "cleaned", "analysis.rds"))
