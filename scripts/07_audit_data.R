# Table: what the originals hold ----
audit_row <- function(applications, label) {
  filed_apps <- applications |> dplyr::filter(filed == 1L)
  has_notice <- !is.na(filed_apps$disposed_on) | !is.na(filed_apps$returned_on) |
    !is.na(filed_apps$rejected_on)
  format_table_row(
    label, format_count(nrow(applications)), format_count(nrow(filed_apps)),
    format_count(sum(!is.na(filed_apps$ack_date))),
    format_count(sum(filed_apps$n_receipts > 0)),
    format_count(sum(filed_apps$n_reply_pdfs > 0)),
    format_count(sum(has_notice & filed_apps$n_reply_pdfs == 0))
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
  format_table_row("State", "Drawn", "Filed", "Portal ack.", "Receipt", "Reply PDF", "Notice, no PDF"),
  c(
    purrr::map_chr(state_order, \(s) audit_row(dplyr::filter(rti, state == s), state_labels[[s]])),
    "\\midrule",
    audit_row(rti, "All")
  )
)

# Table: two coders ----
first_pass <- readr::read_csv(here::here("data", "hand", "responses_coded.csv"),
  col_types = readr::cols(.default = "c"), show_col_types = FALSE, na = ""
)
second <- readr::read_csv(here::here("data", "hand", "second_coding.csv"),
  col_types = readr::cols(.default = "c"), show_col_types = FALSE, na = ""
)
adjudicated <- readr::read_csv(here::here("data", "hand", "coding_adjudicated.csv"),
  col_types = readr::cols(.default = "c"), show_col_types = FALSE, na = ""
)
pairs <- first_pass |> dplyr::inner_join(second, by = "app_id", suffix = c("_a", "_b"))
informed <- c("full", "partial")

agreement_row <- function(label, a, b) {
  a <- dplyr::coalesce(as.character(a), "")
  b <- dplyr::coalesce(as.character(b), "")
  format_table_row(
    label, format_count(length(a)), format_estimate(100 * mean(a == b)),
    sprintf("%.2f", compute_cohen_kappa(a, b))
  )
}

final_disposition <- first_pass |>
  dplyr::select(app_id, disposition) |>
  dplyr::bind_rows(second |> dplyr::filter(!app_id %in% first_pass$app_id) |> dplyr::select(app_id, disposition))
for (i in which(adjudicated$field == "disposition")) {
  final_disposition$disposition[final_disposition$app_id == adjudicated$app_id[i]] <-
    adjudicated$value[i]
}
not_replies <- readr::read_csv(here::here("data", "hand", "manual_corrections.csv"),
  col_types = readr::cols(.default = "c"), show_col_types = FALSE
) |>
  dplyr::filter(action == "not_a_reply") |>
  dplyr::pull(app_id)
final_disposition <- final_disposition |> dplyr::filter(!app_id %in% not_replies)

readr::write_csv(
  dplyr::tibble(
    measure = c("information", "disposition"),
    agree = c(
      100 * mean((pairs$disposition_a %in% informed) == (pairs$disposition_b %in% informed)),
      100 * mean(pairs$disposition_a == pairs$disposition_b)
    )
  ),
  file.path(paths$tables, "coding_agreement.csv")
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
  format_table_row("", "N", "Agree (\\%)", "Kappa"),
  c(
    format_table_panel("Panel A. Agreement", 4),
    agreement_row(
      "Information supplied, yes or no", pairs$disposition_a %in% informed,
      pairs$disposition_b %in% informed
    ),
    agreement_row("Disposition", pairs$disposition_a, pairs$disposition_b),
    agreement_row("Data format", pairs$granularity_a, pairs$granularity_b),
    agreement_row("Section 25 return", pairs$q3_sec25_a, pairs$q3_sec25_b),
    agreement_row("Reply date", pairs$response_date_a, pairs$response_date_b),
    "\\midrule",
    format_table_row("", "", "First pass", "Adjudicated"),
    format_table_panel("Panel B. Disposition counts", 4),
    purrr::imap_chr(disposition_labels, \(label, code) {
      format_table_row(
        label, "", format_count(sum(first_pass$disposition == code)),
        format_count(sum(final_disposition$disposition == code))
      )
    })
  )
)
