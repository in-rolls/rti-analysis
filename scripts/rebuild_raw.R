stages <- c("parse_emails", "read_sheets", "match_events", "build_status")
for (stage in stages) {
  message("Running ", stage)
  sys.source(file.path("scripts", paste0(stage, ".R")), envir = new.env(parent = globalenv()))
}
