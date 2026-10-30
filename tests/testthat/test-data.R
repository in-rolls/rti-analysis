d <- read_analysis()

testthat::test_that("the snapshot matches its recorded checksums", {
  dir <- file.path(root, "data", "raw", SNAPSHOT)
  manifest <- read.csv(file.path(dir, "MANIFEST.csv"))
  testthat::expect_equal(unname(tools::md5sum(file.path(dir, manifest$file))), manifest$md5)
})

testthat::test_that("sample accounting holds by state", {
  testthat::expect_equal(nrow(d), 1665L)
  testthat::expect_false(any(duplicated(d$app_id)))
  testthat::expect_equal(sum(d$filed), 1000L)
  testthat::expect_equal(sum(!is.na(d$filing_date)), 999L)
  testthat::expect_equal(sum(d$past30), 455L)
  past30 <- table(d$state[d$past30 == 1])
  testthat::expect_equal(
    as.integer(past30[c("TN", "TG", "KA", "DL", "MH")]), c(140L, 187L, 78L, 22L, 28L)
  )
})

testthat::test_that("past day 30 means exactly 30 or more days of exposure", {
  testthat::expect_true(all(d$exposure[d$past30 == 1] >= 30))
  testthat::expect_true(all(is.na(d$exposure[d$past30 == 0]) | d$exposure[d$past30 == 0] < 30))
  testthat::expect_true(all(is.na(d$any_30[d$past30 == 0])))
  testthat::expect_false(any(is.na(d$any_30[d$past30 == 1])))
})

testthat::test_that("outcomes are nested and dated in order", {
  testthat::expect_true(all(is.na(d$days_any) | d$days_any >= 0))
  testthat::expect_true(all(is.na(d$date_any) | d$date_any <= AS_OF))
  testthat::expect_true(all(d$filed[!is.na(d$date_any)] == 1L))
  e <- d[d$past30 == 1, ]
  testthat::expect_true(all(e$reply_30 <= e$any_30))
  testthat::expect_true(all(e$info_30 <= e$reply_30))
})

testthat::test_that("arms follow the design: 30% legal within each randomization block", {
  tn <- d[d$state == "TN", ]
  testthat::expect_equal(sum(tn$legal), 300L)
  by_stratum <- tapply(tn$legal, tn$block, function(x) abs(sum(x) - 0.3 * length(x)))
  testthat::expect_true(all(by_stratum <= 1))
  other <- d[d$state != "TN", ]
  by_block <- tapply(other$legal, other$block, function(x) abs(sum(x) - 0.3 * length(x)))
  testthat::expect_true(all(by_block <= 1))
  testthat::expect_equal(sort(unique(other$block[other$state == "DL"])), c(
    "DL dm2026q3_01", "DL dm2026q3_02"
  ))
})

testthat::test_that("phone calls appear only where they could be received", {
  calls <- d[d$phone_call == 1L, ]
  testthat::expect_equal(nrow(calls), 9L)
  testthat::expect_true(all(calls$assigned_ra %in% c("RA2", "RA4")))
  testthat::expect_true(all(calls$filed == 1L))
  testthat::expect_false("TN-719" %in% calls$app_id)
})

testthat::test_that("hand corrections are applied", {
  testthat::expect_true(is.na(d$disposition[d$app_id == "TG-150"]))
  testthat::expect_equal(d$disposition[d$app_id == "TG-162"], "full")
  testthat::expect_equal(d$date_notice[d$app_id == "MH-002"], as.Date("2026-09-29"))
  testthat::expect_true(is.na(d$filing_date[d$app_id == "TN-592"]))
  testthat::expect_equal(d$treatment[d$app_id == "TN-027"], "plain")
})
