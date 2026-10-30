# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: raw_02_read_ra_sheets.R
### Reads the RA filing sheets frozen for the data date into one register row per application.
### The full register stays in data/private/; only non-personal fields reach data/derived/.
# ----
pacman::p_load(dplyr, purrr, readr, stringr, here)

source(here("code", "00_config.R"))
source(here("code", "00_utils.R"))
source(here("code", "raw_utils.R"))

raw_root <- path.expand(Sys.getenv("RTI_RAW"))
if (!nzchar(raw_root) || !dir.exists(raw_root)) stop("Set RTI_RAW to the shared Drive rti/ folder.")

freeze_dir <- file.path(raw_root, RAW_FREEZE)
rules <- read_csv(file.path(freeze_dir, "ra_sheet_rules.csv"), show_col_types = FALSE)
assignments <- read_assignments()

group_ras <- list(RA1_RA3 = c("RA1", "RA3"), RA2_RA4 = c("RA2", "RA4"))

## A filed row whose id cell was overwritten with a note: its office name still identifies it
recover_id <- function(office, group) {
  hit <- assignments |>
    filter(
      str_to_lower(str_trim(office_name)) == str_to_lower(str_trim(office)),
      assigned_ra %in% group_ras[[group]]
    )
  if (nrow(hit) == 1) hit$app_id else ""
}

read_tab <- function(rule) {
  path <- file.path(freeze_dir, "ra_sheets", rule$file)
  grid <- read.csv(path,
    header = FALSE, colClasses = "character", check.names = FALSE,
    encoding = "UTF-8", fileEncoding = "UTF-8-BOM", na.strings = character()
  )
  if (nrow(grid) < 2) {
    return(NULL)
  }
  header <- str_to_lower(str_trim(unlist(grid[1, ])))
  ## A header can repeat across a tab: take the first non-blank value, as the tracker does
  pick <- function(row, ...) {
    for (key in c(...)) {
      values <- str_trim(row[header == key])
      values <- values[nzchar(values)]
      if (length(values) > 0) {
        return(values[1])
      }
    }
    ""
  }
  map_dfr(seq(2, nrow(grid)), function(i) {
    row <- unlist(grid[i, ])
    id_cell <- str_to_upper(pick(row, "application_id"))
    reg_raw <- pick(row, "registration_number")
    recovered <- FALSE
    if (!str_detect(id_cell, APP_RE)) {
      if (!nzchar(id_cell) || !is_real_reg(reg_raw)) {
        return(NULL)
      }
      id_cell <- recover_id(pick(row, "office_name"), rule$group)
      recovered <- TRUE
      if (!nzchar(id_cell)) {
        return(NULL)
      }
    }
    filing <- parse_sheet_date(pick(row, "filing_date"))
    contact <- paste(
      pick(row, "pio_name"), pick(row, "contact details of nodal officer"),
      pick(row, "email-id"), pick(row, "notes")
    )
    emails <- unique(vapply(str_extract_all(contact, EMAIL_RE)[[1]], fix_email, ""))
    tibble(
      app_id = id_cell, group = rule$group, person = rule$person, tab = rule$tab,
      reg_raw = reg_raw, reg_no = norm_reg(reg_raw),
      sheet_filing_date = filing$day, sheet_filing_at = filing$at,
      sheet_response_date = parse_sheet_date(pick(row, "response_date"))$day,
      outcome = pick(row, "filing_outcome"), not_filed_reason = pick(row, "not_filed_reason"),
      notes = pick(row, "notes"), pio_emails = list(unname(emails[nzchar(emails)])),
      id_recovered = recovered
    )
  })
}

counted <- rules |> filter(use == "count")
if (any(rules$use == "unrecognised")) {
  print(filter(rules, use == "unrecognised") |> select(group, tab))
  stop("RA sheet tabs not covered by the rules")
}

rows <- map_dfr(seq_len(nrow(counted)), \(i) read_tab(counted[i, ]))

# One row per application ----
## The first row carrying a registration number wins; the rest are flagged
register <- rows |>
  mutate(has_reg = nzchar(reg_no), real_reg = is_real_reg(reg_no)) |>
  arrange(app_id, desc(has_reg)) |>
  group_by(app_id) |>
  mutate(
    n_tabs = n(),
    conflicting_regs = n_distinct(reg_no[has_reg]) > 1
  ) |>
  slice(1) |>
  ungroup()

write_rds(register, here("data", "private", "ra_register.rds"))

ra_filings <- register |>
  transmute(app_id, group,
    reg_cell = case_when(real_reg ~ "number", has_reg ~ "text", TRUE ~ "empty"),
    sheet_filing_date, sheet_response_date, n_tabs, conflicting_regs, id_recovered
  )
write_csv(ra_filings, here("data", "derived", "ra_filings.csv"), na = "")

print(count(ra_filings, str_sub(app_id, 1, 2), reg_cell))
cat(
  "Recovered ids:", sum(ra_filings$id_recovered), "; conflicting numbers:",
  sum(ra_filings$conflicting_regs), "\n"
)
