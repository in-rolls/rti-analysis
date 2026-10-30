# Does RTI Work?

**First-cut tables and figures from an audit of India's Right to Information Act**

Priyadarshi Amar and Gaurav Sood

[Read the tables and figures](output/first_cut_note.pdf) · [Design and definitions](docs/design.md) · [Data and provenance](docs/data.md)

## TL;DR

**Does RTI work for a citizen who files online?** Not reliably, so far. As of 29 October 2026, 996 of 1,665 drawn applications are filed and 455 have passed the 30-day limit in s.7(1). Outside Telangana, 28.7% of those got any response in time and 14.2% got information.

| State | Past day 30 | Any response (%) | Reply (%) | Information supplied (%) |
| --- | ---: | ---: | ---: | ---: |
| Tamil Nadu | 140 | 12.9 | 12.1 | 5.0 |
| Tamil Nadu, weighted to frame |  | 7.0 | 6.9 | 2.1 |
| Telangana | 187 | 1.1 | 1.1 | 1.1 |
| Karnataka | 78 | 52.6 | 51.3 | 28.2 |
| Delhi | 22 | 22.7 | 18.2 | 13.6 |
| Maharashtra | 28 | 46.4 | 35.7 | 21.4 |
| All states | 455 | 17.4 | 16.0 | 8.8 |
| All excl. Telangana | 268 | 28.7 | 26.5 | 14.2 |

Any response is any office action, including a transfer or fee demand. Reply excludes transfers. Information supplied is a reply coded full or partial, a lower bound while some replies have not been downloaded.

- **Response varies widely by state**, from 12.9% in Tamil Nadu (7.0% weighted to its frame, since nearly all its offices are sub-offices) to 52.6% in Karnataka. States differ in portals and in the kinds of offices sampled, so these gaps are not causal.
- **Telangana's 1.1% is a lower bound.** Its portal sends no status emails and no status checks are recorded, so it cannot yet be read as silence.
- **Few replies answer everything.** Of 104 coded replies, 54 supply some information and 15 answer both the register request and the Section 25 return. Two coders agree on whether information was supplied in 92% of replies, but only 74% on the full disposition.
- **The legal letter shows no detectable effect yet.** The effect on any response by day 30 is 1.1 points (SE 5.8) in Tamil Nadu and 3.6 (SE 3.9) in other states, or 10.9 (SE 9.3) in Karnataka, Delhi and Maharashtra. The smallest effects we could detect are about 16.2, 10.9 and 26.1 points, so a null says little yet. One specification with department-group fixed effects shows a large effect, but it rests on 41 applications and is not significant at 5% under randomization inference; see the main table. This is an interim, unregistered look while filing continues.

## Reproduce

Use R 4.5.2, GNU Make and a TeX installation with `pdflatex`. R packages are pinned in `renv.lock`.

**From the derived data in this repository:**

```sh
make restore
make check
```

`make check` reruns the analysis, compiles the note, regenerates this README, lints the code, runs the tests and runs the privacy check.

**From the original inputs:** the originals hold personal data, so they stay in the shared Drive folder rather than in git. You also need `poppler` and `tesseract`.

```sh
export RTI_RAW="/path/to/shared/drive/rti"
make verify-raw
make rebuild
make check
```

`make verify-raw` checks every original against `data/raw_manifest.csv`. `make rebuild` then parses the emails and RA sheets, matches messages to applications, and builds status. If the code and originals are unchanged, `git status` stays clean afterwards.

## Repository

| Path | Contents |
| --- | --- |
| `data/upstream.csv` | The frames and drawn assignment lists, pinned to commits in the public repositories; downloaded on first run |
| `data/raw_manifest.csv` | Size and checksum of each of the original files kept in Drive |
| `data/hand/` | Everything made by judgment: reply coding, second coding, adjudication, hand corrections, phone calls |
| `data/derived/` | Built from the originals by `code/raw_*.R`, with no personal data |
| `data/cleaned/` | One row per drawn application, and the function-coding crosswalk |
| `code/raw_*.R` | Originals to derived data |
| `code/00_*.R` to `code/08_*.R` | Derived data to tables and figures |
| `output/` | The note, tables and figures |
| `docs/` | Design, definitions, provenance, and what is still missing |
| `tests/` | Parsers, sample accounting, estimators, outputs and privacy |
| `hooks/` | Pre-push guard; install with `make hooks` |

The README is generated from `docs/README.md.in`. Edit the template, not this file.
