project_file <- function(...) file.path(root, ...)
applications <- read_analysis()

testthat::test_that("every exhibit has a note within the length limit", {
  exhibits <- c(
    list.files(project_file("tabs"), "^tab_.*\\.tex$", full.names = TRUE),
    list.files(project_file("figs"), "\\.tex$", full.names = TRUE)
  )
  for (f in exhibits) {
    note <- grep("\\\\textit\\{Notes:\\}", readLines(f), value = TRUE)
    testthat::expect_length(note, 1L)
    testthat::expect_lte(nchar(sub(".*\\\\textit\\{Notes:\\} ", "", note)), note_limit)
  }
})

testthat::test_that("every figure was written", {
  figures <- sub("\\.tex$", ".pdf", list.files(project_file("figs"), "\\.tex$", full.names = TRUE))
  testthat::expect_length(figures, 6L)
  testthat::expect_true(all(file.exists(figures)))
})

testthat::test_that("headline counts agree with the analysis file", {
  headline <- read.csv(project_file("tabs", "headline_numbers.csv"))
  e <- applications[applications$past30 == 1, ]
  testthat::expect_equal(headline$n[headline$sample == "ALL"], nrow(e))
  testthat::expect_equal(headline$any_30[headline$sample == "ALL"], sum(e$any_30 == 100))
  testthat::expect_equal(headline$reply_30[headline$sample == "ALL"], sum(e$reply_30 == 100))
  testthat::expect_equal(headline$info_30[headline$sample == "ALL"], sum(e$info_30 == 100))
  testthat::expect_equal(sum(headline$n[headline$sample != "ALL"]), nrow(e))
})

testthat::test_that("the main estimate reproduces by hand within Tamil Nadu strata", {
  main <- read.csv(project_file("tabs", "main_effects.csv"))
  tn <- applications[applications$past30 == 1 & applications$state == "TN", ]
  tn <- tn[ave(tn$legal, tn$block, FUN = length) > 1, ]
  by_hand <- lm(any_30 ~ legal + factor(block), data = tn)
  testthat::expect_equal(
    main$b[main$sample == "Tamil Nadu"], unname(coef(by_hand)["legal"]),
    tolerance = 1e-8
  )
  testthat::expect_equal(main$n[main$sample == "Tamil Nadu"], nrow(tn))
})

testthat::test_that("paper macros reproduce computed counts and response rates", {
  macros <- readLines(project_file("tabs", "macros.tex"))
  rates <- read.csv(project_file("tabs", "response_by_state.csv"))
  expected <- sprintf("\\newcommand{\\rtinfiled}{%s}", format_count(sum(applications$filed)))
  testthat::expect_true(expected %in% macros)
  expected <- sprintf(
    "\\newcommand{\\rtiinfoextg}{%.1f}",
    rates$info[rates$sample == "All excl. Telangana"]
  )
  testthat::expect_true(expected %in% macros)
  testthat::expect_false(any(grepl("@@", macros, fixed = TRUE)))
})

testthat::test_that("macro names are valid and collisions stop generation", {
  path <- tempfile(fileext = ".tex")
  on.exit(unlink(path))
  write_macros(c(n_past30 = "455", as_of = "29 October 2026"), path)
  testthat::expect_equal(readLines(path), c(
    "\\newcommand{\\rtinpastthirty}{455}",
    "\\newcommand{\\rtiasof}{29 October 2026}"
  ))
  testthat::expect_error(write_macros(c(a_b = "1", ab = "2"), path))
})
