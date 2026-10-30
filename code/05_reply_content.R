# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: 05_reply_content.R
### What the coded replies contain, and office phone calls among RA2 and RA4 filings.
# ----
if (!exists("rti")) source(here::here("code", "02_load_packages_and_data.R"))

# Table: content of coded replies ----
replies <- rti |> filter(coded == 1L)
n_tn <- sum(replies$tn)
n_other <- sum(!replies$tn)
n_all <- nrow(replies)

count_row <- function(label, cond) {
  a <- sum(cond & replies$tn)
  b <- sum(cond & !replies$tn)
  tab_row(
    paste0("\\quad ", label), f0(a), f0(b), f0(a + b),
    f0(as.integer(round(100 * (a + b) / n_all)))
  )
}

value_rows <- function(var, map) {
  imap_chr(map, \(lab, val) count_row(lab, replies[[var]] == val))
}

clause <- replies$clause_cited
fees <- replies |> filter(!is.na(fee_inr))

body <- c(
  tab_panel("Disposition", 5),
  value_rows("disposition", c(
    full = "Full information", partial = "Partial information", fee_pending = "Fee asked first",
    denied = "Denied or deflected", returned = "Returned", transferred = "Transferred"
  )),
  tab_panel("Data supplied", 5),
  value_rows("granularity", c(
    format_a = "Application-level register", format_b = "Monthly or category counts",
    format_c = "Period totals", narrative_only = "Prose only", none = "None"
  )),
  tab_panel("Section 25 annual return", 5),
  value_rows("q3_sec25", c(
    supplied = "Supplied", not_held = "Not held", offered_on_payment = "Offered on payment",
    refused_separate_application = "Told to apply separately",
    referred_to_website = "Referred to website", not_addressed = "Not addressed"
  )),
  tab_panel("How it arrived", 5),
  value_rows("medium", c(post = "Post", portal = "Portal", email = "Email")),
  tab_panel("Provisions cited", 5),
  count_row("Exemption, s.8", str_detect(clause, "^8")),
  count_row("Sections 2(f) or 7(9)", str_detect(clause, "2\\(f\\)|7\\(9\\)")),
  count_row("Transfer, s.6(3)", clause == "6(3)"),
  count_row("None", clause == "none")
)

save_table(
  "tab_content",
  "What the coded replies contain",
  sprintf(
    paste0(
      "All %d coded replies, whenever they came. Double-coded blind, with ",
      "disagreements adjudicated. Fees were quoted in %d replies (median Rs %s, maximum Rs ",
      "%s)."
    ),
    n_all, nrow(fees), f0(as.integer(round(median(fees$fee_inr)))),
    f0(as.integer(round(max(fees$fee_inr))))
  ),
  "lrrrr",
  tab_row(
    "", sprintf("Tamil Nadu (%d)", n_tn), sprintf("Others (%d)", n_other),
    sprintf("All (%d)", n_all), "All (\\%)"
  ),
  body
)

# Table: phone calls, RA2 and RA4 filings only ----
## The denominator is RA2 and RA4 filings, because RA1 and RA3 could not receive calls.
phone_base <- filed |> filter(phone_filer == 1L)
stopifnot(nrow(phone_base) == 501)

call_row <- function(d, label) {
  p0 <- d |> filter(legal == 0)
  p1 <- d |> filter(legal == 1)
  tab_row(
    label, f0(nrow(d)), f0(sum(d$phone_call)), f1(100 * mean(d$phone_call)),
    paste0(sum(p0$phone_call), " / ", nrow(p0)), paste0(sum(p1$phone_call), " / ", nrow(p1))
  )
}

type_row <- function(label, val) {
  tab_row(
    paste0("\\quad ", label), "", f0(sum(phone_base$call_type == val, na.rm = TRUE)), "",
    "", ""
  )
}

body <- c(
  tab_panel("Panel A. By state", 6),
  map_chr(STATE_ORDER, \(s) call_row(filter(phone_base, state == s), STATE_LABELS[[s]])),
  "\\midrule",
  call_row(phone_base, "All"),
  tab_panel("Panel B. Why the office called", 6),
  type_row("Clarify what is sought", "clarify"),
  type_row("Ask why the filer applied", "why_filed"),
  type_row("Give an answer by phone", "answer_by_phone"),
  type_row("Confirm a reply arrived", "confirm_receipt")
)

header <- paste(
  "& & & & \\multicolumn{2}{c}{Calls / filings} \\\\",
  "\\cmidrule(lr){5-6}",
  tab_row("State", "Filings", "Calls", "Per 100 filings", "Plain", "Legal")
)

save_table(
  "tab_calls",
  "Office phone calls to the filer, RA2 and RA4 filings only",
  sprintf(paste0(
    "Only RA2 and RA4 could receive calls, so other filings are excluded and ",
    "calls never enter response rates. Taken from RA notes up to %s, so ",
    "possibly undercounted. The Act requires no reason from the applicant ",
    "(s.6(2))."
  ), format(AS_OF, "%d %B")),
  "lrrrrr", header, body
)
