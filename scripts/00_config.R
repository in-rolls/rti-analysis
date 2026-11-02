raw_freeze <- "raw_snapshots/2026-10-29"
as_of <- as.Date("2026-10-29")
horizons <- c(7, 14, 21, 30, 35, 45)
seed <- 20261030
ri_draws <- 2000

## Table and figure notes over this many characters stop the run
note_limit <- 440

state_order <- c("TN", "TG", "KA", "DL", "MH")
state_labels <- c(
  TN = "Tamil Nadu", TG = "Telangana", KA = "Karnataka", DL = "Delhi", MH = "Maharashtra"
)

other_function <- "Finance, industry and other"
outcome_levels <- c(
  "Full information", "Partial information", "Fee demanded", "Denied",
  "Returned", "Transferred", "Reply, not yet coded", "No response"
)

options(scipen = 999)
fixest::setFixest_notes(FALSE)

paths <- list(tables = here::here("tabs"), figures = here::here("figs"))
for (path in paths) dir.create(path, recursive = TRUE, showWarnings = FALSE)

samples <- list(
  "Tamil Nadu" = \(applications) dplyr::filter(applications, state == "TN"),
  "Other states" = \(applications) dplyr::filter(applications, state != "TN"),
  "Excl. Telangana" = \(applications) dplyr::filter(applications, !state %in% c("TN", "TG"))
)

for (module in c("coding", "analysis", "sources", "paper", "raw")) {
  source(here::here("R", paste0(module, ".R")))
}
