# Two RTI repositories

The project has two maintained deliverables:

| Repository | Responsibility | Starting point |
| --- | --- | --- |
| [in-rolls/rti](https://github.com/in-rolls/rti) | Office frames, sampling, issued assignments, instruments, intake, public worklists | `make check`; `scripts/01_build_release.R` |
| [in-rolls/rti-analysis](https://github.com/in-rolls/rti-analysis) | Study records, outcome coding, analysis, tables, figures, results paper | `make check`; `scripts/99_run_all.R` |

Both use R, renv, testthat, lintr, and Make. Shared functions live in `R/`; scripts assemble workflows. States are data and configuration within the fieldwork repository. They do not have separate samplers or dashboards. The analysis reads checksummed files from a fixed fieldwork revision, rather than importing fieldwork code or tracking a moving branch.

Both repositories are intended to be public. Private emails, original documents, filer details, evidence links, and intake state remain outside Git. The separation reflects two responsibilities and release schedules, not a requirement for a private paper repository.

## What is preserved

The fieldwork repository's `docs/source_manifest.csv` records the original repository, commit, path, destination, and SHA-256 for imported evidence. It covers public portal snapshots, the frames used for sampling, six issued batches, original worklists and instruments, and design documents. All 1,665 issued assignments retain their original IDs, treatment, assistant allocation, and source columns.

The original study plan is `rti/design/study_plan.tex`; the results manuscript is `rti-analysis/ms/main.tex`. State amendments remain with the fieldwork design. The original 135-row application table and three events are historical records, not replacements for the study's current status data.

Historical Python programs and environments must remain recoverable with their original Git history. R verifies the frozen draws; it does not claim that an R seed reproduces Python's sampling algorithms. New draws use the shared R sampler and record their configuration and RNG settings.

The analysis refactor's path mapping is recorded in `docs/relocations.csv`. Hand coding and corrections remain explicit inputs. Numerical manuscript values and this repository's README are generated from the analysis, avoiding independent copies of results.

## Cutover

Priyadarshi transferred the original analysis and state repositories to `in-rolls`. His address-update PRs have been merged. The development fork, `in-rolls/rti-paper`, will be removed after its paper branch is merged into the original `rti-analysis` and all unique commits are verified there.

The state repositories will cease to be maintained once their material and history are preserved and the shared viewer is deployed and checked. Retirement must account for GitHub Pages links and PR records as well as files. Deleting a repository removes its Pages address; preserving Git history alone does not preserve that service. The canonical viewer is [in-rolls.github.io/rti](https://in-rolls.github.io/rti/).

## Remaining evidence gap

Private-source parsing and event matching remain in `rti-analysis` until they can be compared against the complete originals. The recovered emails, attachments, configuration, and frozen sheets reproduce the corresponding saved CSVs. The available archive and Drive listing still lack 131 pinned receipt or response-document paths. Full document verification and a complete status rebuild therefore remain unfinished. See [the paper audit](paper_audit.md).

This gap predates repository consolidation. The checked-in derived-data analysis is reproducible, but a release must identify itself as an interim research snapshot and must not claim that all original documents have been reverified.
