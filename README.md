# Does RTI Work?

**First-cut tables and figures from an audit of India's Right to Information Act**

Priyadarshi Amar and Gaurav Sood

[Read the tables and figures](output/first_cut_note.pdf) · [Design and definitions](docs/design.md) · [Data and provenance](docs/data.md)

## TL;DR

**Does RTI work for a citizen who files online?** Not reliably, so far. As of 29 October 2026, 1,000 of 1,665 drawn applications are filed and 455 have passed the 30-day limit in s.7(1). Outside Telangana, 28.4% of those got any response in time and 12.3% got information.

| State | Past day 30 | Any response (%) | Reply (%) | Information supplied (%) |
| --- | ---: | ---: | ---: | ---: |
| Tamil Nadu | 140 | 12.9 | 11.4 | 4.3 |
| Tamil Nadu, weighted to frame |  | 7.0 | 6.0 | 2.0 |
| Telangana | 187 | 1.1 | 1.1 | 1.1 |
| Karnataka | 78 | 51.3 | 50.0 | 25.6 |
| Delhi | 22 | 22.7 | 13.6 | 9.1 |
| Maharashtra | 28 | 46.4 | 32.1 | 17.9 |
| All states | 455 | 17.1 | 15.2 | 7.7 |
| All excl. Telangana | 268 | 28.4 | 25.0 | 12.3 |

Any response is any office action, including a transfer or fee demand. Reply excludes transfers. Information supplied is a reply coded full or partial, a lower bound while some replies are uncoded.

- **Response varies widely by state**, from 12.9% in Tamil Nadu (7.0% weighted to its frame, since nearly all its offices are sub-offices) to 51.3% in Karnataka. States differ in portals and in the kinds of offices sampled, so these gaps are not causal.
- **Telangana's 1.1% is a lower bound.** Its portal sends no status emails and no status checks are recorded, so it cannot yet be read as silence.
- **The legal letter shows no detectable effect yet.** The effect on any response by day 30 is 1.1 points (SE 5.8) in Tamil Nadu and 2.6 (SE 3.9) in other states, or 8.5 (SE 9.4) excluding Telangana. The smallest effects we could detect are about 16.2, 10.9 and 26.3 points, so a null says little yet. This is an interim, unregistered look while filing continues.

## Reproduce

Use R 4.5.2, GNU Make and a TeX installation with `pdflatex`. R packages are pinned in `renv.lock`.

```sh
make restore
make check
```

`make check` reruns the analysis from the frozen data snapshot, compiles the note, regenerates this README, lints the code, runs the tests and runs the privacy check. `make analysis` runs the pipeline alone. Scripts run in the order listed in `code/00_master.R`.

## Repository

| Path | Contents |
| --- | --- |
| `data/raw/` | Frozen snapshot of the trackers with checksums, hand corrections, and the phone-call list |
| `data/cleaned/` | One row per drawn application, and the function-coding crosswalk for review |
| `code/` | Numbered pipeline, with shared settings in `00_config.R` and functions in `00_utils.R` |
| `output/` | The note, tables and figures |
| `docs/` | Design, definitions, data provenance, and known limits |
| `tests/` | Sample accounting, estimators, outputs and privacy |
| `hooks/` | Pre-push guard; install with `make hooks` |

Reply PDFs, filing receipts, emails and RA sheets carry filer details and stay in the shared Drive folder. See [data and provenance](docs/data.md).

The README is generated from `docs/README.md.in`. Edit the template, not this file.
