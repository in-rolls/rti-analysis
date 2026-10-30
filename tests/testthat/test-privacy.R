source(file.path(root, "code", "check_privacy.R"))

testthat::test_that("the scan catches each kind of personal data", {
  testthat::expect_equal(scan_text("write to someone@example.com"), "email")
  testthat::expect_equal(scan_text("call 9876543210 today"), "phone")
  testthat::expect_equal(scan_text("ABCDE/R/2026/60011"), "registration")
  testthat::expect_equal(scan_text("TGRTI/APP/MAN/04/09/26/DI/33521"), "registration")
})

testthat::test_that("the scan leaves ordinary project text alone", {
  ok <- c(
    "TG-150,tg2026q3_02,plain,RA1", "Commissioner of Police, Navi Mumbai", "SEED <- 20261030",
    "1665,1000,455", "2026-10-29", "1a05fc9876543210,2026-09-02", "ca1c11bff11b8dea8854ed9876543210"
  )
  testthat::expect_length(scan_text(ok), 0L)
})

testthat::test_that("forbidden columns are caught in a header", {
  testthat::expect_equal(forbidden_in_header("app_id,reg_no,filed"), "reg_no")
  testthat::expect_length(forbidden_in_header("app_id,state,treatment"), 0L)
})

testthat::test_that("git is not tracking anything personal", {
  testthat::expect_identical(privacy_findings(root), character())
})
