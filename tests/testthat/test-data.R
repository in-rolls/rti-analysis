d <- read_analysis()

testthat::test_that("the tracker cross-check files match their recorded checksums", {
  dir <- file.path(root, "data", "validation", TRACKER_CHECK)
  manifest <- read.csv(file.path(dir, "MANIFEST.csv"))
  testthat::expect_equal(unname(tools::md5sum(file.path(dir, manifest$file))), manifest$md5)
})

testthat::test_that("the manifest pins every original, and matches them when they are available", {
  manifest <- read.csv(file.path(root, "data", "raw_manifest.csv"), colClasses = "character")
  testthat::expect_false(anyNA(manifest$md5))
  testthat::expect_false(any(duplicated(manifest$path_md5)))
  folders <- c("email_tracker/raw", "email_tracker/attachments", "rti responses", "Filed_RTI")
  testthat::expect_true(all(folders %in% manifest$folder))
  raw_root <- path.expand(Sys.getenv("RTI_RAW"))
  testthat::skip_if(!nzchar(raw_root) || !dir.exists(raw_root), "originals are not on this machine")
  source(file.path(root, "code", "raw_utils.R"), local = TRUE)
  batches <- pinned_originals(raw_root, "email_tracker/raw", manifest)
  testthat::expect_equal(unname(tools::md5sum(file.path(raw_root, batches$path))), batches$md5)
})

testthat::test_that("sample accounting holds by state", {
  testthat::expect_equal(nrow(d), 1665L)
  testthat::expect_false(any(duplicated(d$app_id)))
  testthat::expect_equal(sum(d$filed), 996L)
  testthat::expect_equal(sum(!is.na(d$filing_date)), 996L)
  testthat::expect_equal(sum(d$past30), 455L)
  past30 <- table(d$state[d$past30 == 1])
  testthat::expect_equal(
    as.integer(past30[c("TN", "TG", "KA", "DL", "MH")]), c(140L, 187L, 78L, 22L, 28L)
  )
})

testthat::test_that("a note in the number cell does not make an application filed", {
  failed <- c("KA-150", "TN-509", "TN-513", "TN-592")
  testthat::expect_true(all(d$filed[d$app_id %in% failed] == 0L))
  testthat::expect_true(all(is.na(d$filing_date[d$app_id %in% failed])))
  ## A note in the cell plus a portal acknowledgment is still a filing
  testthat::expect_equal(d$filed[d$app_id == "TN-223"], 1L)
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
  testthat::expect_true(all(e$any_strict_30 <= e$any_30))
  ## The bound has to be able to bite: some first responses rest on a low-confidence match
  testthat::expect_lt(sum(e$any_strict_30), sum(e$any_30))
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

testthat::test_that("hand corrections and adjudicated coding are applied", {
  testthat::expect_true(is.na(d$disposition[d$app_id == "TG-150"]))
  testthat::expect_equal(d$disposition[d$app_id == "TG-162"], "full")
  testthat::expect_equal(d$date_notice[d$app_id == "MH-002"], as.Date("2026-09-29"))
  testthat::expect_equal(d$treatment[d$app_id == "TN-027"], "plain")
  ## A portal status page is not a reply
  testthat::expect_true(is.na(d$disposition[d$app_id == "TN-469"]))
  ## Coded only in the second round
  testthat::expect_equal(d$disposition[d$app_id == "TN-492"], "partial")
  ## Letter dated 13 October, not the portal's 22 October
  testthat::expect_equal(d$coded_response_date[d$app_id == "KA-137"], as.Date("2026-10-13"))
  ## No dated letter, but still a reply with a date
  testthat::expect_equal(d$coded_response_date[d$app_id == "MH-022"], as.Date("2026-10-23"))
  testthat::expect_equal(sum(d$coded), 104L)
  ## Full requires the Section 25 return to be answered as well
  testthat::expect_equal(sum(d$disposition == "full", na.rm = TRUE), 15L)
})

testthat::test_that("every coded reply obeys the written coding rules", {
  coded <- d[d$coded == 1L, ]
  has_data <- coded$granularity %in% c("format_a", "format_b", "format_c")
  supplied <- coded$q3_sec25 == "supplied"
  full <- coded$disposition == "full"
  testthat::expect_true(all(has_data[full] & coded$q3_sec25[full] %in% c("supplied", "not_held")))
  partial <- coded$disposition == "partial"
  testthat::expect_true(all((has_data | supplied | coded$granularity == "narrative_only")[partial]))
  none <- coded$disposition %in% c("fee_pending", "denied", "returned", "transferred")
  testthat::expect_false(any((has_data | supplied)[none]))
})

testthat::test_that("every coded reply has its document in the archive", {
  ## Except the reply filed under the wrong id, which is counted under TG-150's name
  coded <- d[d$coded == 1L & d$app_id != "TG-162", ]
  testthat::expect_true(all(coded$n_reply_pdfs > 0))
})

testthat::test_that("rebuilt status agrees with the tracker except on explained applications", {
  differ <- read.csv(file.path(root, "data", "derived", "tracker_differences.csv"))
  explained <- c(
    "KA-150", "TN-509", "TN-513", "TN-592", ## number cells saying no number was issued
    "TN-289", "TN-900", ## dates held for attempts that were never filed
    "KA-154", "TN-492", ## notices dated the data date, after the tracker ran
    "KA-047", "MH-053" ## unmatched mail read and matched by hand
  )
  testthat::expect_setequal(unique(differ$app_id), explained)
})

testthat::test_that("derived data carries no personal columns", {
  files <- list.files(file.path(root, "data", "derived"), "\\.csv$", full.names = TRUE)
  personal <- c(
    "reg_no", "reg_raw", "sender", "sender_name", "subject", "notes", "person",
    "account"
  )
  for (f in files) {
    testthat::expect_length(intersect(names(read.csv(f, nrows = 1)), personal), 0L)
  }
})
