.PHONY: restore rebuild verify-raw analysis manuscript paper format lint test privacy hooks check ci-docker clean

restore:
	Rscript --vanilla -e 'if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", repos = "https://cloud.r-project.org"); renv::load(project = getwd()); renv::restore(prompt = FALSE)'

rebuild:
	Rscript scripts/rebuild_raw.R

verify-raw:
	Rscript scripts/verify_raw.R

analysis:
	Rscript scripts/99_run_all.R

manuscript:
	cd ms && latexmk -xelatex -interaction=nonstopmode -halt-on-error main.tex exhibits.tex

paper: analysis
	$(MAKE) manuscript

format:
	Rscript -e 'for (path in c("R", "scripts", "tests")) styler::style_dir(path)'

lint:
	Rscript -e 'lints <- unlist(lapply(c("R", "scripts", "tests"), lintr::lint_dir), recursive = FALSE); print(lints); quit(status = as.integer(length(lints) > 0))'

test: analysis
	Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE)'

privacy:
	Rscript --vanilla scripts/check_privacy.R

hooks:
	cp hooks/pre-push .git/hooks/pre-push
	chmod +x .git/hooks/pre-push

check: paper lint test privacy

ci-docker:
	docker run --rm -v "$(CURDIR):/project" -w /project \
		-v r_renv_cache:/root/.cache/R/renv \
		-e RENV_CONFIG_REPOS_OVERRIDE=https://packagemanager.posit.co/cran/latest \
		rocker/verse:4.6.0 bash -c "tlmgr install latexmk fontspec booktabs threeparttable placeins caption natbib xurl setspace adjustbox && make restore check"

clean:
	cd ms && latexmk -C main.tex exhibits.tex
	rm -f Rplots.pdf data/derived/analysis.rds
