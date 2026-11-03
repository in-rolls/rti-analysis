root <- normalizePath(file.path("..", ".."))
source(file.path(root, "scripts", "00_config.R"))
read_analysis <- function() readRDS(file.path(root, "data", "derived", "analysis.rds"))
