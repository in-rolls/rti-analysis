# R project conventions

This repository follows the research-compendium layout used by `finite-sample/know_hidden` and the [tidyverse style guide](https://style.tidyverse.org/). It remains in the `in-rolls` organization.

- Use R for input preparation, analysis, figures, and numerical manuscript values. Make coordinates R and LaTeX commands.
- Put shared functions in `R/`, ordered analysis stages in `scripts/`, editable LaTeX in `ms/`, and generated exhibits in `tabs/` and `figs/`.
- Use descriptive `snake_case` names. Functions and executable scripts start with verbs. Keep source identifiers and external data values unchanged.
- Use native `|>` pipes and explicit `package::function()` calls. Install dependencies through `make restore`; analysis scripts never install packages.
- Run each analysis stage in its own environment. Shared settings live in `scripts/00_config.R`; stages receive the application samples prepared by `scripts/99_run_all.R`.
- Run `make format` before `make check`. Lint enforces snake_case identifiers and a 120-character line limit, matching the reference project's width.

`data/derived/` contains both status records rebuilt from the private originals and the application-level analysis file. `data/hand/` preserves reviewed coding inputs. Private parsing intermediates stay in ignored `data/private/`; downloaded, checksum-pinned source files stay in ignored `data/upstream/`.

`docs/relocations.csv` records earlier paths, their replacement locations, and the SHA-256 hashes of the earlier files at commit `a7879da31c77f217cfc089318e4bc4520c0ec621`.
