# RTI repository consolidation

Recommendation: keep two active repositories, organized by access and responsibility. Use public `in-rolls/rti` for fieldwork and versioned, de-identified data releases; keep private `in-rolls/rti-analysis` for analysis and the manuscript. Consolidate the state repositories into `rti`, including the Delhi–Maharashtra dependency discovered during this review. Maintain the resulting pipelines in R.

Implementation is underway on `in-rolls/rti` branch `consolidate/r-fieldwork`. The analysis fork was renamed to `in-rolls/rti-paper` on November 2, 2026. Priyadarshi plans to transfer the original to `in-rolls/rti-analysis`, after which our paper branch should be proposed there through a PR. The fork remains in `in-rolls`; GitHub's transfer rules may require resolving that fork-network conflict before the transfer. No repositories have been archived or deleted, and visibility is unchanged.

## What the repositories contain

Reviewed on November 2, 2026. Remote branches and visibility were checked through GitHub; code and committed data were inspected locally.

| Repository | Observed role | Distinct material to preserve | Recommended destination |
| --- | --- | --- | --- |
| `in-rolls/rti` | Public Python fieldwork package, Tamil Nadu crawler, original study design, letters, intake, validation, SQLite views, and batch viewer | Tamil Nadu's hierarchical office identities and department-by-level sampling; 1,000-application frozen batch; original design and older instruments | Canonical fieldwork repository, converted to R |
| `in-rolls/rti-telangana` | Public state extension; three Python scripts and a static dashboard | 117 raw portal pages; 3,401-office frame; 250- and 125-application batches; supplementary-batch design note | State parser and batch configurations in `rti` |
| `in-rolls/rti-karnataka` | Public state extension; two Python scripts and a static dashboard | Raw portal roster; 1,800-office frame; 180-application batch; Karnataka-specific department extraction | State parser and batch configuration in `rti` |
| `in-rolls/rti-analysis` | Private R analysis and paper | Frozen status and coding data, outcome construction, estimators, exhibits, manuscript, and audit records | Retain as the private research compendium |

There is also a fifth dependency: `priyadarshiamar/rti-delhi-maharashtra`. The analysis pins its frame and both assignment batches. Those supply 44 Delhi and 66 Maharashtra applications. Consolidating only the four local repositories would leave this dependency outside the organization and outside the shared fieldwork pipeline.

The reviewed revisions are `e795a6d` on `rti`'s current remote `main`, `5a6ccf3` for Telangana, `50d0b2f` for Karnataka, and `1f427bf` for the analysis branch. The Delhi–Maharashtra snapshot is `8e86e24`. The local `rti` checkout remains on `restructure-pipeline` at `a2815a4`; its source code matches current `main`, whose intervening changes concern CI and dependency locking. Start migration from current `main`, preserving the local checkout and its untracked work.

## What is duplicated, and what is genuinely different

The Telangana and Karnataka scripts share the same capped allocation, sample selection, treatment shuffle, RA balancing, CSV writers, and metadata structure. Their department-name parsers differ, as do their frame parsers and batch constants. They do not need separate repositories or independent sampler implementations.

Both state repositories carry `config/batch.yaml`, but their sampling scripts use hardcoded constants instead of reading it. That creates two representations of the design. The consolidated pipeline should read a single batch configuration and validate it against the frozen metadata.

Dashboard data are also duplicated. All eight Karnataka files under `docs/data/` match files in `out/` byte-for-byte. Eight of thirteen Telangana dashboard files are exact copies; the remaining assignment and worklist files combine the two batches. The state sampler commands do not regenerate that combined dashboard. A single site build should derive its worklists and views from the canonical assignment records.

State-specific designs must remain distinct. Tamil Nadu assigns treatment within department-by-office-level blocks. Telangana and Karnataka select offices by department group but shuffle treatment over the sampled batch. Despite comments describing within-stratum treatment assignment, that is what their code actually does. The existing analysis already distinguishes these randomization schemes. A shared implementation must represent both explicitly.

The original `rti` application/event schema is useful, but its committed tables are not the current five-state tracking record. They contain 135 applications and three events, versus 1,665 drawn applications in the analysis. The analysis instead reconstructs status from frozen RA sheets, email records, documents, and reviewed corrections. Import and reconcile those sources before making the consolidated event tables authoritative; do not replace current evidence with the old tables merely because their schema is cleaner.

The combined frame in `rti` is also older than the state-specific frames. It has 3,325 Telangana and 1,699 Karnataka rows, whereas the frames used for these batches contain 3,401 and 1,800. Preserve each batch's exact frame version, rather than redirecting old assignments to the latest combined frame.

## Why two repositories

The current access boundary is real: fieldwork repositories are public, while `rti-analysis` is private. Two repositories preserve that boundary while eliminating state-by-state maintenance. They also let the fieldwork pipeline release a stable dataset that the paper can pin and reproduce independently of ongoing collection.

One repository becomes reasonable if the manuscript and analytical material are cleared for public release, or if the entire project is deliberately made private and public worklists are published separately. Neither access decision follows automatically from a code cleanup. Four or five active repositories are unnecessary; a second repository is justified by the current access requirements.

Private emails, original documents, filer details, and evidence links remain outside Git. Public code can process private inputs locally and publish only the explicitly selected, de-identified outputs.

## Target structure and responsibilities

`rti` should use the same R conventions as the analysis repository:

```text
R/                         frame parsers, sampling, letters, intake, validation
scripts/                   commands that call the shared functions
config/states/             portal and parsing settings
config/batches/            one immutable configuration per drawn batch
design/                    original study plan and dated amendments
letters/                   versioned instruments
data/                      raw/reference snapshots and generated data
site/                      one dashboard template
tests/testthat/            parsers, allocation, identity, intake, privacy
```

Within data directories, state and batch identify records or partitions. They do not require their own codebases. Keep separate source snapshots where the underlying portals differ. Generate site output from the same assignments used by the analysis, with state and batch filters.

Move reusable source-document parsing and event matching into the fieldwork pipeline after comparison with the frozen analysis inputs. Keep analysis-specific outcome construction, models, coding assessments, figures, tables, and manuscript values in `rti-analysis`. The interface between repositories is a versioned data release with schema, checksums, source revisions, and stable application IDs—not shared runtime code or Git submodules.

The original `rti/ms/ms.tex` is a study design, not a competing version of the results paper. Preserve its original revision and move its maintained role to `design/`. Keep the results manuscript in `rti-analysis/ms/main.tex`.

## Python disposition

There is no identified requirement for Python in future frame preparation, sampling, letter rendering, intake, or analysis. Convert those maintained functions to R and use the existing renv, testthat, lintr, and Make workflow.

Historical replay is the exception. The filed batches were generated with Python's `random.Random`, `sample`, and `shuffle`. Replacing those calls with R functions and the same integer seed does not establish identical assignments: generator initialization and sampling algorithms are part of reproducibility. R explicitly documents its own Mersenne-Twister initialization, and Python's reproducibility guarantees distinguish the generator from other random algorithms. See the [R RNG documentation](https://stat.ethz.ch/R-manual/R-devel/library/base/html/Random.html) and [Python reproducibility notes](https://docs.python.org/3/library/random.html#notes-on-reproducibility).

Preserve original code, environments, frames, metadata, and assignments in tagged history or archival releases. The active R pipeline should read and verify those frozen assignment files. Use the new R sampler only for new batches, recording the R version, RNG settings, seed, configuration, and frame checksum. Do not build a custom Python-compatibility random generator in R just to eliminate historical Python from the archive.

HTML/CSS and minimal browser JavaScript remain presentation assets for the dashboard; they do not become a second data-processing pipeline.

## Migration sequence and completion criteria

1. **Freeze the existing evidence.** Record source commits, hashes, batch metadata, assignments, instruments, and the original study plan. Inventory untracked material separately. The local `rti` checkout includes an untracked prototype directory, a manuscript file, and a roughly 1.9 GB ZIP; preserve them pending review and do not include them in a broad Git add.
2. **Import state assets into `rti`.** Include Delhi–Maharashtra. Keep original attribution and a manifest from source repository/commit/path/hash to destination. Preserve frozen files byte-for-byte. An archival release preserves the old code; the maintained tree gets shared modules, not nested copies of whole repositories.
3. **Implement the R fieldwork pipeline.** Share allocation, validation, letter rendering, and worklist generation. Keep portal parsing and randomization designs explicit. Port the existing behavioral tests, including repeated intake, identifier stability, failed-filing denominators, privacy, and preservation of reviewed corrections. Verify frame reconstruction against the archived frames.
4. **Reconcile records and publish a data release.** Match all 1,665 assignments exactly, including treatment, RA, batch, and office. Preserve unresolved matches and missing evidence as such. Reproduce the current status data and analysis results before changing any substantive coding rule. The release replaces the paper's four-repository download manifest with one pinned source.
5. **Replace the dashboard and retire redundant forks.** Build one state-filterable viewer from canonical data; compare every worklist and instrument. The active Telangana and Karnataka dashboards are currently on Priyadarshi's upstream Pages sites, not on the `in-rolls` forks. Coordinate those links before retirement. Archive the redundant organization forks with a pointer to `in-rolls/rti`; preserve upstream histories and do not delete repositories as part of migration.

The migration is complete when old assignments and instruments retain their hashes, no issued IDs or treatment assignments change, every state has validated frame parsing, the current paper results reproduce, all R checks pass, the public export excludes private fields, and existing dashboard users have a working replacement. At that point there should be two active pipelines and no maintained state-specific Python scripts.

## Checks performed for this review

- Rebuilt Telangana's frame and both assignment batches in an isolated copy using the original scripts. The frame and both assignment CSVs are byte-identical to the committed versions.
- Rebuilt Karnataka's frame and assignment batch in an isolated copy. Both CSVs are byte-identical to the committed versions.
- Ran the original `rti` test suite successfully with available pytest/PyYAML dependencies, including its privacy-guard subprocess. Black, isort, and flake8 passed on the inspected source and tests. This was a code verification run, not a restoration of its locked deployment environment.
- Confirmed that the two state repositories have no tracked test suite, workflow, or dependency lockfile. Their current organization forks match their upstream main revisions.
- Checked the analysis dependency manifest, application counts, repository visibility, branch revisions, and Pages configuration. No live portal crawl or private-originals audit was performed.
- Rebuilt the manuscript after correcting appendix counters. Tables and references now use A1, A2, and A3; main-text tables remain 1–3. The appendix page was rendered and visually inspected. LaTeX reports no unresolved references or overfull boxes; lint and privacy checks pass.

## Implementation update

Fieldwork consolidation is available in [in-rolls/rti PR #3](https://github.com/in-rolls/rti/pull/3). It includes the shared R implementation, frozen sources and instruments, one viewer, and 80 passing regression assertions. The paper's upstream manifest now pins the consolidated source commit without changing any input checksum or analytical result. The renamed development fork is `in-rolls/rti-paper`; the original repository's transfer and the subsequent upstream paper PR remain separate steps.

Email parsing, frozen sheet ingestion, and event matching have been rebuilt against recovered private originals and reproduce their prior derived CSVs exactly. Full receipt/response-document verification is still incomplete, as documented in `docs/paper_audit.md`. The fieldwork PR remains a draft; the replacement viewer has not been deployed, and no state forks have been archived.
