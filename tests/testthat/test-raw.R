source(file.path(root, "R", "raw.R"))

msg <- function(from, subject = "", body = "", ...) {
  list(
    from = from, subject = subject, body_text = body, body_html_text = "", labels = list(),
    attachments = list(), ...
  )
}

testthat::test_that("registration numbers are found, normalised and deduplicated", {
  testthat::expect_equal(extract_registration_numbers("no /R/ here"), character())
  testthat::expect_equal(extract_registration_numbers("ABCDE/R/2026/60011"), "ABCDE/R/2026/60011")
  ## Portal text glues the next label onto the number
  testthat::expect_equal(extract_registration_numbers("ABCDE/R/2026/60011Name: x"), "ABCDE/R/2026/60011")
  testthat::expect_equal(extract_registration_numbers("ABCDE / R / 2026 / 60011"), "ABCDE/R/2026/60011")
  testthat::expect_equal(
    extract_registration_numbers("ABCDE/R/2026/60011 and ABCDE/R/2026/60011 then WXYZ/A/2026/1234"),
    c("ABCDE/R/2026/60011", "WXYZ/A/2026/1234")
  )
})

testthat::test_that("office codes with an ampersand are read, as typed or as HTML", {
  testthat::expect_equal(extract_registration_numbers("DD&DC/R/2026/60004"), "DD&DC/R/2026/60004")
  testthat::expect_equal(extract_registration_numbers("HG&amp;CD/R/2026/60056"), "HG&CD/R/2026/60056")
  testthat::expect_equal(normalize_registration("DD&DC/R/2026/60004"), "DD&DC/R/2026/60004")
})

testthat::test_that("sheet values are normalised, and notes are not registration numbers", {
  testthat::expect_equal(normalize_registration(" abcde/r/2026/60011&#9;"), "ABCDE/R/2026/60011")
  testthat::expect_equal(normalize_registration(""), "")
  testthat::expect_true(is_real_reg("ABCDE/R/2026/60011"))
  testthat::expect_false(is_real_reg("department not found"))
  testthat::expect_false(is_real_reg(NA))
  ## A note holding a date is still a note
  testthat::expect_false(is_real_reg("Received letter on 2026-09-08 regarding RTI"))
  testthat::expect_true(is_real_reg("TGRTI/APP/SC./20/09/26/DI/34428"))
})

testthat::test_that("portal templates are classified, and templates decide the event", {
  tn <- "rtisupport@tn.gov.in"
  ka <- "rtionline-kar@nic.in"
  ack <- classify_email(msg(
    tn, "RTI request filed successfully",
    "ABCDE/R/2026/60011 Date of Filing : 01/09/2026"
  ))
  testthat::expect_equal(ack$kind, "filing_ack")
  testthat::expect_equal(ack$state, "TN")
  testthat::expect_equal(ack$fields$reg_no, "ABCDE/R/2026/60011")
  testthat::expect_equal(ack$fields$filing_date, "01/09/2026")

  moved <- classify_email(msg(
    tn, "RTI request transferred",
    "ABCDE/R/2026/60011 transferred to office vide new registration WXYZ/R/2026/70022"
  ))
  testthat::expect_equal(moved$kind, "transferred")
  testthat::expect_equal(moved$fields$reg_no, "ABCDE/R/2026/60011")
  testthat::expect_equal(unlist(moved$fields$new_reg_nos), "WXYZ/R/2026/70022")

  testthat::expect_equal(classify_email(msg(
    ka, "request disposed of",
    "ABCDE/R/2026/60011"
  ))$kind, "disposed")
  testthat::expect_equal(classify_email(msg(ka, "request returned back", "x"))$kind, "returned")
  testthat::expect_equal(classify_email(msg(ka, "request rejected", "x"))$kind, "rejected")
  testthat::expect_equal(classify_email(msg(ka, "Your OTP for login", "1234"))$kind, "otp")

  fee <- classify_email(msg(ka, "additional fee due", "pay Rs. 1,250 for ABCDE/R/2026/60011"))
  testthat::expect_equal(fee$kind, "fee_demand")
  testthat::expect_equal(fee$fields$amount_inr, "1250")
})

testthat::test_that("the Telangana acknowledgement counts as filing proof with no number", {
  tg <- classify_email(msg(
    "tsrtinoreply@gmail.com", "RTI application submission",
    "Dear Applicant,\nYour Registration Number is: $regno"
  ))
  testthat::expect_equal(tg$kind, "filing_ack_tg")
  testthat::expect_equal(tg$fields$reg_no, "")
})

testthat::test_that("office mail is a reply only if it concerns an RTI or has an attachment", {
  office <- "pio.office@example.org"
  testthat::expect_equal(
    classify_email(msg(office, "Your RTI application", "see below"))$kind,
    "pio_email"
  )
  testthat::expect_equal(classify_email(msg(office, "Newsletter", "hello"))$kind, "other")
  with_file <- msg(office, "Letter", "see attached")
  with_file$attachments <- list(list(saved_as = "a.pdf"))
  testthat::expect_equal(classify_email(with_file)$kind, "pio_email")
  fee <- classify_email(msg(office, "RTI reply", "kindly remit the photocopy charges"))
  testthat::expect_true(fee$fields$mentions_fee)
  gov <- classify_email(msg("pio@dept.gov.in", "RTI reply", "information attached"))
  testthat::expect_equal(gov$kind, "pio_email")
})

testthat::test_that("system mail and our own sent mail are never replies", {
  testthat::expect_equal(classify_email(msg(
    "no-reply@accounts.google.com", "Security alert",
    "x"
  ))$kind, "system")
  sent <- msg("someone@example.org", "RTI", "ABCDE/R/2026/60011")
  sent$labels <- list("SENT")
  testthat::expect_equal(classify_email(sent)$kind, "sent_by_us")
})

testthat::test_that("the state-language RTI phrases match", {
  testthat::expect_true(stringr::str_detect("தகவல் அறியும் உரிமை", rti_words_re))
  testthat::expect_true(stringr::str_detect("ಮಾಹಿತಿ ಹಕ್ಕು", rti_words_re))
  testthat::expect_true(stringr::str_detect("सूचना का अधिकार", rti_words_re))
})

testthat::test_that("sheet dates parse in every format the RAs use", {
  testthat::expect_equal(parse_sheet_date("2026-09-26")$day, as.Date("2026-09-26"))
  testthat::expect_equal(parse_sheet_date("28-08-2026")$day, as.Date("2026-08-28"))
  testthat::expect_equal(parse_sheet_date("28/08/2026")$day, as.Date("2026-08-28"))
  testthat::expect_true(is.na(parse_sheet_date("31-02-2026")$day))
  testthat::expect_true(is.na(parse_sheet_date("not a date")$day))
  at <- parse_sheet_date("04-09-2026 20:27:58")$at
  testthat::expect_equal(
    format(at, "%Y-%m-%d %H:%M:%S", tz = "Asia/Kolkata"),
    "2026-09-04 20:27:58"
  )
})

testthat::test_that("PIO addresses typed with stray spaces are repaired", {
  testthat::expect_equal(fix_email("x @ gmail.com"), "x@gmail.com")
  testthat::expect_equal(fix_email("x@.domain.net"), "x@domain.net")
  testthat::expect_equal(fix_email("none given"), "")
})

testthat::test_that("office-and-date matching needs office words plus a date, and a clear winner", {
  info <- list(
    "TN-001" = list(office = "Fisheries Inspector Thanjavur", dates = "2026-09-01"),
    "TN-002" = list(office = "Sericulture Inspector Erode", dates = "2026-09-02")
  )
  testthat::expect_equal(
    match_office_and_date("Fisheries Inspector Thanjavur dated 01.09.2026", info),
    "TN-001"
  )
  testthat::expect_equal(
    match_office_and_date("Fisheries Inspector Thanjavur dated 15.09.2026", info),
    "TN-001"
  )
  testthat::expect_equal(match_office_and_date("Something else entirely 01.09.2026", info), "")
  restricted <- match_office_and_date("Fisheries Inspector 01.09.2026", info, restrict = "TN-002")
  testthat::expect_equal(restricted, "")
})

testthat::test_that("a pinned file is checked against its checksum", {
  dir <- tempfile("pin")
  dir.create(dir)
  pin <- list(
    repo = "owner/repo", ref = "abc123", path = "data/frame.csv",
    md5 = "not-the-checksum"
  )
  cached <- file.path(dir, "abc123_frame.csv")
  writeLines("a,b", cached)
  testthat::expect_error(fetch_pinned(pin, dir), "does not match")
  pin$md5 <- unname(tools::md5sum(cached))
  testthat::expect_equal(fetch_pinned(pin, dir), cached)
})
