source("R/privacy.R")
findings <- find_privacy_issues()
if (length(findings) > 0) {
  stop("Privacy check failed:\n", paste(findings, collapse = "\n"))
}
message("Privacy check passed.")
