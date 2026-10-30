# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 07b_data_checks.R
### What the original inputs cover, how the rebuild compares with the trackers and the first
### cut, and
### how well two coders agree on the replies.
# ----
if (!exists("rti")) source(here::here("code", "02_load_packages_and_data.R"))

# Table: what the originals hold ----
audit_row <- function(d, label) {
  filed_apps <- d |> filter(filed == 1L)
  has_notice <- !is.na(filed_apps$disposed_on) | !is.na(filed_apps$returned_on) |
    !is.na(filed_apps$rejected_on)
  tab_row(
    label, f0(nrow(d)), f0(nrow(filed_apps)),
    f0(sum(!is.na(filed_apps$ack_date))),
    f0(sum(filed_apps$n_receipts > 0)),
    f0(sum(filed_apps$n_reply_pdfs > 0)),
    f0(sum(has_notice & filed_apps$n_reply_pdfs == 0))
  )
}

save_table(
  "tab_audit",
  "What the original inputs cover",
  paste0(
    "Filed: a real registration number on the RA sheet or a portal ",
    "acknowledgment. Notice, no PDF: ",
    "the portal says disposed, returned or rejected, but the reply has not ",
    "been downloaded. No status ",
    "notices reached the inboxes from Telangana, Delhi or Maharashtra, so ",
    "replies left only on those ",
    "portals are not observed."
  ),
  "lrrrrrr",
  tab_row("State", "Drawn", "Filed", "Portal ack.", "Receipt", "Reply PDF", "Notice, no PDF"),
  c(
    map_chr(STATE_ORDER, \(s) audit_row(filter(rti, state == s), STATE_LABELS[[s]])),
    "\\midrule",
    audit_row(rti, "All")
  )
)

# Table: rebuilt from the originals against the email tracker ----
agreement <- read_csv(here("data", "derived", "tracker_agreement.csv"), show_col_types = FALSE)
field_labels <- c(
  filed = "Filed", filing_date = "Filing date", ack_date = "Acknowledgment date",
  transferred_on = "Transfer date", fee_demanded_on = "Fee demand date",
  disposed_on = "Disposed date", returned_on = "Returned date", rejected_on = "Rejected date",
  email_response_on = "Office email date", first_response = "First response date"
)

save_table(
  "tab_validation",
  "Rebuilt from the original inputs, against the email tracker",
  paste0(
    "Applications drawn, field by field. The 4 filed differences are ",
    "number cells saying no number ",
    "was issued, and the filing-date differences are all on unfiled applications. The rest are ",
    "notices dated the data date, and messages matched by hand after reading them."
  ),
  "lrr",
  tab_row("Field", "Agree", "Differ"),
  map_chr(seq_len(nrow(agreement)), \(i) {
    tab_row(field_labels[[agreement$field[i]]], f0(agreement$agree[i]), f0(agreement$differ[i]))
  })
)

# Table: what moved from the first cut ----
first_cut <- read_csv(here("data", "validation", "first_cut_rates.csv"), show_col_types = FALSE)
now <- read_csv(file.path(PATHS$tables, "response_by_state.csv"), show_col_types = FALSE)
moved <- first_cut |> inner_join(now, by = "sample", suffix = c("_old", "_new"))

save_table(
  "tab_changes",
  "Response within 30 days: first cut against the rebuild (\\%)",
  paste0(
    "First cut: tracker outputs and first-pass reply coding. Rebuild: ",
    "original inputs and adjudicated ",
    "coding. Any response moves only through corrected reply dates; ",
    "information supplied also moves ",
    "through adjudicated dispositions."
  ),
  "lrrrrrr",
  paste(
    "& \\multicolumn{2}{c}{Any response} & \\multicolumn{2}{c}{Reply}",
    "& \\multicolumn{2}{c}{Information supplied} \\\\",
    "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}\\cmidrule(lr){6-7}",
    tab_row("State", "First cut", "Rebuild", "First cut", "Rebuild", "First cut", "Rebuild")
  ),
  map_chr(seq_len(nrow(moved)), \(i) {
    tab_row(
      moved$sample[i], f1(moved$any_old[i]), f1(moved$any_new[i]), f1(moved$reply_old[i]),
      f1(moved$reply_new[i]), f1(moved$info_old[i]), f1(moved$info_new[i])
    )
  })
)

# Table: two coders ----
first_pass <- read_csv(here("data", "hand", "responses_coded.csv"),
  col_types = cols(.default = "c"), show_col_types = FALSE, na = ""
)
second <- read_csv(here("data", "hand", "second_coding.csv"),
  col_types = cols(.default = "c"), show_col_types = FALSE, na = ""
)
adjudicated <- read_csv(here("data", "hand", "coding_adjudicated.csv"),
  col_types = cols(.default = "c"), show_col_types = FALSE, na = ""
)
pairs <- first_pass |> inner_join(second, by = "app_id", suffix = c("_a", "_b"))
informed <- c("full", "partial")

agreement_row <- function(label, a, b) {
  a <- coalesce(as.character(a), "")
  b <- coalesce(as.character(b), "")
  tab_row(label, f0(length(a)), f1(100 * mean(a == b)), sprintf("%.2f", cohen_kappa(a, b)))
}

final_disposition <- first_pass |>
  select(app_id, disposition) |>
  bind_rows(second |> filter(!app_id %in% first_pass$app_id) |> select(app_id, disposition))
for (i in which(adjudicated$field == "disposition")) {
  final_disposition$disposition[final_disposition$app_id == adjudicated$app_id[i]] <-
    adjudicated$value[i]
}
not_replies <- read_csv(here("data", "hand", "manual_corrections.csv"),
  col_types = cols(.default = "c"), show_col_types = FALSE
) |>
  filter(action == "not_a_reply") |>
  pull(app_id)
final_disposition <- final_disposition |> filter(!app_id %in% not_replies)

disposition_labels <- c(
  full = "Full information", partial = "Partial information", fee_pending = "Fee asked first",
  denied = "Denied or deflected", returned = "Returned", transferred = "Transferred"
)

save_table(
  "tab_coding",
  "Reply coding: agreement between two independent coders",
  paste0(
    "Panel A: the second coder could not see the first codes. Panel B: disagreements went to an ",
    "adjudicator who could not tell the coders apart. Full now requires ",
    "the Section 25 return to be ",
    "answered as well, which is stricter than the first pass. Reply coding ",
    "cannot be rerun, only audited."
  ),
  "lrrr",
  tab_row("", "N", "Agree (\\%)", "Kappa"),
  c(
    tab_panel("Panel A. Agreement", 4),
    agreement_row(
      "Information supplied, yes or no", pairs$disposition_a %in% informed,
      pairs$disposition_b %in% informed
    ),
    agreement_row("Disposition", pairs$disposition_a, pairs$disposition_b),
    agreement_row("Data format", pairs$granularity_a, pairs$granularity_b),
    agreement_row("Section 25 return", pairs$q3_sec25_a, pairs$q3_sec25_b),
    agreement_row("Reply date", pairs$response_date_a, pairs$response_date_b),
    "\\midrule",
    tab_row("", "", "First pass", "Adjudicated"),
    tab_panel("Panel B. Disposition counts", 4),
    imap_chr(disposition_labels, \(label, code) {
      tab_row(
        label, "", f0(sum(first_pass$disposition == code)),
        f0(sum(final_disposition$disposition == code))
      )
    })
  )
)
