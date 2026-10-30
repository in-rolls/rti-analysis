# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 00_config.R
### Settings shared by the pipeline and the tests. A new data date starts here.
# ----
## Originals are frozen in the shared Drive folder
RAW_FREEZE <- "raw_snapshots/2026-10-29"
AS_OF <- as.Date("2026-10-29")
HORIZONS <- c(7, 14, 21, 30, 35, 45)
SEED <- 20261030
RI_DRAWS <- 2000

## Data this project uses but does not own: pinned to a commit and checked by checksum
TN_FRAME_PIN <- list(
  repo = "in-rolls/rti",
  ref = "955861bbeeb886d4e9792db41ad667ce2d3e2bad",
  path = "data/frame.csv",
  md5 = "8f4493dacd8a298a737f3a2f0fb5f348"
)

## Table and figure notes over this many characters stop the run
NOTE_LIMIT <- 440

STATE_ORDER <- c("TN", "TG", "KA", "DL", "MH")
STATE_LABELS <- c(
  TN = "Tamil Nadu", TG = "Telangana", KA = "Karnataka", DL = "Delhi", MH = "Maharashtra"
)

OTHER_FUNCTION <- "Finance, industry and other"
OUTCOME_LEVELS <- c(
  "Full information", "Partial information", "Fee demanded", "Denied",
  "Returned", "Transferred", "Reply, not yet coded", "No response"
)
