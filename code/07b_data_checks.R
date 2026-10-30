# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 07b_data_checks.R
### What the original inputs cover, and how well two coders agree on the replies.
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

write_csv(
  tibble(
    measure = c("information", "disposition"),
    agree = c(
      100 * mean((pairs$disposition_a %in% informed) == (pairs$disposition_b %in% informed)),
      100 * mean(pairs$disposition_a == pairs$disposition_b)
    )
  ),
  file.path(PATHS$tables, "coding_agreement.csv")
)

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
