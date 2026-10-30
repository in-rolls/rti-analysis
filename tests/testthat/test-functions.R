testthat::test_that("Wilson intervals match prop.test without continuity correction", {
  for (case in list(c(5, 10), c(1, 187), c(40, 78), c(0, 22))) {
    expected <- 100 * prop.test(case[1], case[2], correct = FALSE)$conf.int
    ci <- wilson(case[1], case[2], z = qnorm(0.975))
    testthat::expect_equal(c(ci$lo, ci$hi), as.numeric(expected), tolerance = 1e-6)
  }
})

testthat::test_that("Cohen's kappa matches values worked by hand", {
  testthat::expect_equal(cohen_kappa(c("a", "b"), c("a", "b")), 1)
  ## Agreement on 3 of 4, chance agreement of 0.5
  testthat::expect_equal(cohen_kappa(c("a", "a", "b", "b"), c("a", "b", "b", "b")), 0.5)
})

testthat::test_that("number formatting handles negatives, negative zero and missing values", {
  testthat::expect_equal(f1(-0.04), "0.0")
  testthat::expect_equal(f1(-1.23), "$-$1.2")
  testthat::expect_equal(f1(NA_real_), "")
  testthat::expect_equal(f0(1665L), "1,665")
  testthat::expect_equal(f_p(0.0001), "$<$0.001")
  testthat::expect_equal(f_p(0.5), "0.500")
  testthat::expect_equal(f_se(3.86), "(3.9)")
})

testthat::test_that("function coding avoids the false matches found by hand", {
  expected <- c(
    "SOCIAL WELFARE AND WOMEN EMPOWERMENT DEPARTMENT" = "Welfare, labour and food",
    "YOUTH EMPOWERMENT AND SPORTS" = "Finance, industry and other",
    "DISTRICT TREASURY" = "Finance, industry and other",
    "Treasury Office, Karimnagar" = "Finance, industry and other",
    "TGTRANSCO" = "Infrastructure and utilities",
    "MANDAL PRAJA PARISHAD DOULTHABAD" = "Local government and housing",
    "INDUSTRIAL SAFETY AND HEALTH" = "Welfare, labour and food",
    "SCHOOL EDUCATION DEPARTMENT" = "Education",
    "COMMISSIONER OF POLICE" = "Police, justice and excise",
    "TAHSILDAR OFFICE" = "Revenue, land and registration"
  )
  testthat::expect_equal(code_function(names(expected)), unname(expected))
})

toy <- data.frame(
  y = c(100, 100, 0, 0, 100, 100, 0, 0),
  legal = c(1L, 1L, 0L, 0L, 1L, 1L, 0L, 0L),
  block = rep(c("a", "b"), each = 4),
  dept_group = rep(c("a", "b"), each = 4)
)

testthat::test_that("fit_lpm matches lm with block dummies and drops singleton blocks", {
  set.seed(1)
  d <- data.frame(block = rep(letters[1:6], each = 8), legal = rep(c(0L, 1L), 24))
  d$y <- 100 * rbinom(nrow(d), 1, 0.2 + 0.1 * d$legal)
  by_hand <- lm(y ~ legal + factor(block), data = d)
  r <- fit_lpm(d, "y", "block")
  testthat::expect_equal(r$b, unname(coef(by_hand)["legal"]), tolerance = 1e-8)
  testthat::expect_equal(r$n, nrow(d))
  testthat::expect_equal(r$mde, 2.8 * r$se)
  testthat::expect_equal(r$plain_mean, mean(d$y[d$legal == 0]))

  with_singleton <- rbind(d, data.frame(block = "z", legal = 1L, y = 100))
  testthat::expect_equal(fit_lpm(with_singleton, "y", "block")$n, nrow(d))
})

testthat::test_that("randomization inference matches the exact answer on a toy design", {
  ## Two blocks of four with two treated: of 36 assignments, 2 give an absolute effect of 100
  set.seed(1)
  testthat::expect_equal(ri_pvalue(toy, "y", draws = 5000), 2 / 36, tolerance = 0.25)
  set.seed(1)
  testthat::expect_equal(ri_pvalue_fe(toy, "y", draws = 5000), 2 / 36, tolerance = 0.25)
})

testthat::test_that("randomization inference gives p of one when the effect is exactly zero", {
  flat <- toy
  flat$y <- c(100, 0, 100, 0, 100, 0, 100, 0)
  set.seed(1)
  testthat::expect_equal(ri_pvalue(flat, "y", draws = 200), 1)
})

testthat::test_that("Kaplan-Meier curves match simple shares without censoring", {
  d <- data.frame(km_time = 1:20, km_event = 1L, arm = "only")
  curve <- km_curve(d, "arm")
  testthat::expect_equal(curve$cum[curve$day == 5], 25)
  testthat::expect_true(all(curve$at_risk >= 10 | curve$day == 0))
})

testthat::test_that("Kaplan-Meier treats silent applications as censored, not as no response", {
  d <- data.frame(km_time = c(1, 2, rep(40, 18)), km_event = c(1L, 1L, rep(0L, 18)), arm = "only")
  curve <- km_curve(d, "arm")
  testthat::expect_equal(curve$cum[curve$day == 30], 10)
})
