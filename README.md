# Measuring the Right to Know

An audit of online Right to Information requests in five Indian states.

Priyadarshi Amar and Gaurav Sood

[Read the paper](ms/main.pdf) · [Read the tables and figures](ms/exhibits.pdf) · [Design and definitions](docs/design.md) · [Data and provenance](docs/data.md)

This is the analysis and paper repository. [in-rolls/rti](https://github.com/in-rolls/rti) owns the office frames, sampling, issued assignments, instruments, and fieldwork viewer. The two projects exchange versioned files with checksums; neither imports the other's R code.

## TL;DR

**Does RTI work for a citizen who files online?** Not reliably, so far. As of 29 October 2026, 996 of 1,665 drawn applications are filed and 455 have passed the 30-day limit in s.7(1). Outside Telangana, 28.7% of those got any response in time and 14.2% got information.

| State | Past day 30 | Any response (%) | Reply (%) | Information supplied (%) |
| --- | ---: | ---: | ---: | ---: |
| Tamil Nadu | 140 | 12.9 | 12.1 | 5.0 |
| Tamil Nadu, adjusted for office level |  | 7.0 | 6.9 | 2.1 |
| Telangana | 187 | 1.1 | 1.1 | 1.1 |
| Karnataka | 78 | 52.6 | 51.3 | 28.2 |
| Delhi | 22 | 22.7 | 18.2 | 13.6 |
| Maharashtra | 28 | 46.4 | 35.7 | 21.4 |
| All states | 455 | 17.4 | 16.0 | 8.8 |
| All excl. Telangana | 268 | 28.7 | 26.5 | 14.2 |

Any response is any office action, including a transfer or fee demand. Reply excludes transfers. Information supplied is a reply coded full or partial, a lower bound while some replies have not been downloaded.

- **Response varies widely by state**, from 12.9% in Tamil Nadu (7.0% after weighting the results to match the proportions of headquarters and subordinate offices on the portal; this does not account for which departments were filed first) to 52.6% in Karnataka. States differ in portals and in the kinds of offices sampled, so these gaps are not causal.
- **Telangana's 1.1% is a lower bound.** Its portal sends no status emails and no status checks are recorded, so it cannot yet be read as silence.
- **Few replies answer everything.** Of 104 coded replies, 54 supply some information and 15 answer both the register request and the Section 25 return. Two coders agree on whether information was supplied in 92% of replies, but only 74% on the full disposition.
- **The legal letter shows no detectable effect yet.** The effect on any response by day 30 is 1.1 points (SE 5.8) in Tamil Nadu and 3.6 (SE 3.9) in other states, or 10.9 (SE 9.3) in Karnataka, Delhi and Maharashtra. The smallest effects we could detect are about 16.2, 10.9 and 26.1 points, so a null says little yet. One specification with department-group fixed effects shows a large effect, but it rests on 41 applications and is not significant at 5% under randomization inference; see the main table. This is an interim, unregistered look while filing continues.

## Reproduce

Use R 4.6.0, GNU Make, and a TeX installation with XeLaTeX and `latexmk`. R packages are pinned in `renv.lock`.

**From the derived data in this repository:**

```sh
make restore
make check
```

`make check` reruns the analysis, builds the paper and exhibit appendix, regenerates this README, lints the code, runs the tests and runs the privacy check.

`make ci-docker` runs the same checks in the standard `rocker/verse:4.6.0` image. It requires a running Docker daemon and network access for dependency restoration.

The analysis and input preparation use R throughout. There is no Python dependency. Naming, layout, and formatting conventions are documented in [docs/naming.md](docs/naming.md).

**From the original inputs:** the originals hold personal data, so they stay in the shared Drive folder rather than in git. You also need `poppler` and `tesseract`.

The recovered private archive is incomplete: 131 pinned receipt or response-document paths have not been located. The public derived-data workflow above is reproducible. A complete rebuild from originals requires the remaining documents; `make verify-raw` must pass before running it. Email parsing, frozen-sheet ingestion, and event matching have separately reproduced their saved outputs. See the [audit record](docs/paper_audit.md).

```sh
export RTI_RAW="/path/to/shared/drive/rti"
make verify-raw
make rebuild
make check
```

`make verify-raw` checks every original against `data/raw_manifest.csv`. `make rebuild` then parses the emails and RA sheets, matches messages to applications, and builds status. Unchanged code and originals should reproduce the saved data and result tables. Compiled PDFs may differ in timestamps and other binary metadata.

## Repository

| Path | Contents |
| --- | --- |
| `data/upstream.csv` | Frames and issued assignments pinned to a commit in `in-rolls/rti`; downloaded on first run |
| `data/raw_manifest.csv` | Size and checksum of each of the original files kept in Drive |
| `data/hand/` | Everything made by judgment: reply coding, second coding, adjudication, hand corrections, phone calls |
| `data/derived/` | Status records, analysis data, and coding crosswalks generated by R |
| `R/` | Shared functions for parsing, coding, estimation, tables, and figures |
| `scripts/` | Ordered analysis stages and commands for rebuilding the private inputs |
| `tabs/`, `figs/` | Generated tables, numerical macros, and figures |
| `ms/` | Editable manuscript, bibliography, and compiled PDFs |
| `docs/` | Design, definitions, provenance, and what is still missing |
| `tests/` | Parsers, sample accounting, estimators, outputs and privacy |
| `hooks/` | Pre-push guard; install with `make hooks` |

The README is generated from `docs/README.md.in`. Edit the template, not this file.

## Reading the code

Start with `scripts/99_run_all.R`: it prepares the application data, then runs the numbered analysis stages in order. `scripts/00_config.R` defines the data date, samples, and simulation settings. Stage scripts assemble results; shared calculations belong in `R/analysis.R`, outcome and department coding in `R/coding.R`, input verification in `R/sources.R`, and exhibit formatting in `R/paper.R`.

`scripts/rebuild_raw.R` is a separate entry point for private-source reconstruction. Its parsing and matching helpers live in `R/raw.R`. That reconstruction remains here until the complete originals can be verified; the fieldwork intake database does not replace the frozen study record. Changes to an estimator or coding rule should update its shared function and behavioral tests, rather than repeat the calculation in another table or in manuscript prose.

## Paper development

Edit `ms/main.tex`. `make paper` runs the analysis and builds `ms/main.pdf` and `ms/exhibits.pdf`; `make manuscript` rebuilds the PDFs from existing exhibits. R writes numerical values to `tabs/macros.tex`, which the manuscript reads directly. See [the audit and design reconciliation](docs/paper_audit.md) for interpretation limits and unresolved evidence gaps.
