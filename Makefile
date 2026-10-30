.PHONY: restore analysis format lint test privacy hooks check clean

restore:
	Rscript --vanilla -e 'if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", repos = "https://cloud.r-project.org"); renv::load(project = getwd()); renv::restore(prompt = FALSE)'

analysis:
	Rscript code/00_master.R

format:
	Rscript -e 'for (p in c("code", "tests")) styler::style_dir(p)'

lint:
	Rscript -e 'l <- unlist(lapply(c("code", "tests"), lintr::lint_dir), recursive = FALSE); print(l); quit(status = as.integer(length(l) > 0))'

test: analysis
	Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE)'

privacy:
	Rscript --vanilla code/check_privacy.R

hooks:
	@cp hooks/pre-push .git/hooks/pre-push
	@chmod +x .git/hooks/pre-push
	@echo "pre-push hook installed: pushes are blocked if personal data is tracked"

check: analysis lint test privacy

clean:
	rm -f output/*.aux output/*.log output/*.out Rplots.pdf data/cleaned/analysis.rds
