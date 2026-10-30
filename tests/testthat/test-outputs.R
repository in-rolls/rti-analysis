out <- function(...) file.path(root, "output", ...)
d <- read_analysis()

testthat::test_that("the note holds only exhibits, with no prose", {
  lines <- readLines(out("first_cut_note.tex"))
  body <- lines[(which(lines == "\\maketitle") + 1):(which(lines == "\\end{document}") - 1)]
  testthat::expect_true(all(grepl("^\\\\(input\\{|FloatBarrier)", body)))
  inputs <- sub("^\\\\input\\{(.*)\\}$", "\\1", body[grepl("^\\\\input", body)])
  testthat::expect_length(inputs, 22L)
  testthat::expect_true(all(file.exists(out(paste0(inputs, ".tex")))))
  testthat::expect_true(file.exists(out("first_cut_note.pdf")))
})

testthat::test_that("every exhibit has a note within the length limit", {
  exhibits <- c(
    list.files(out("tables"), "\\.tex$", full.names = TRUE),
    list.files(out("figures"), "\\.tex$", full.names = TRUE)
  )
  for (f in exhibits) {
    note <- grep("\\\\textit\\{Notes:\\}", readLines(f), value = TRUE)
    testthat::expect_length(note, 1L)
    testthat::expect_lte(nchar(sub(".*\\\\textit\\{Notes:\\} ", "", note)), NOTE_LIMIT)
  }
})

testthat::test_that("every figure was written", {
  figures <- sub("\\.tex$", ".pdf", list.files(out("figures"), "\\.tex$", full.names = TRUE))
  testthat::expect_length(figures, 6L)
  testthat::expect_true(all(file.exists(figures)))
})

testthat::test_that("headline counts agree with the analysis file", {
  headline <- read.csv(out("tables", "headline_numbers.csv"))
  e <- d[d$past30 == 1, ]
  testthat::expect_equal(headline$n[headline$sample == "ALL"], nrow(e))
  testthat::expect_equal(headline$any_30[headline$sample == "ALL"], sum(e$any_30 == 100))
  testthat::expect_equal(headline$reply_30[headline$sample == "ALL"], sum(e$reply_30 == 100))
  testthat::expect_equal(headline$info_30[headline$sample == "ALL"], sum(e$info_30 == 100))
  testthat::expect_equal(sum(headline$n[headline$sample != "ALL"]), nrow(e))
})

testthat::test_that("the main estimate reproduces by hand within Tamil Nadu strata", {
  main <- read.csv(out("tables", "main_effects.csv"))
  tn <- d[d$past30 == 1 & d$state == "TN", ]
  tn <- tn[ave(tn$legal, tn$block, FUN = length) > 1, ]
  by_hand <- lm(any_30 ~ legal + factor(block), data = tn)
  testthat::expect_equal(
    main$b[main$sample == "Tamil Nadu"], unname(coef(by_hand)["legal"]),
    tolerance = 1e-8
  )
  testthat::expect_equal(main$n[main$sample == "Tamil Nadu"], nrow(tn))
})

testthat::test_that("the README was generated and its numbers match the tables", {
  readme <- readLines(file.path(root, "README.md"))
  testthat::expect_false(any(grepl("@@", readme, fixed = TRUE)))
  by_state <- read.csv(out("tables", "response_by_state.csv"))
  tn <- by_state[by_state$sample == "Tamil Nadu", ]
  row <- grep("^\\| Tamil Nadu \\|", readme, value = TRUE)
  testthat::expect_length(row, 1L)
  testthat::expect_true(grepl(sprintf("| %.1f |", tn$any), row, fixed = TRUE))
})
