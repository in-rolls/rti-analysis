# RTI first-cut analysis

First-cut tables and figures for the RTI audit (Amar and Sood). The question: does the Right to Information Act work for a citizen who files online? Data as of 29 October 2026. This is a first cut, not a replication package, and it departs from the design document in `main.tex` where the README says so.

**Read the output:** `output/first_cut_note.pdf`.

**Reproduce it:** open `first_cut_analysis.Rproj`, or from this folder run:

```bash
Rscript code/00_master.R
```

It takes about a minute and uses only what is in this folder, except the last step, which copies outputs to Overleaf if that folder exists.

## File overview

### Data

- `data/raw/snapshot_2026-10-29/`: frozen inputs, so results do not move when the trackers update. `MANIFEST.csv` has row counts and checksums; `SOURCES.csv` has where each file came from.
  - `status_panel.csv`, `events.csv`: email tracker (registration numbers and contact details removed).
  - `responses_coded.csv`: first-pass coding of reply documents (free-text notes removed).
  - `assignments_tn.csv`, `assignments_other.csv`: the drawn samples, arms and strata.
  - `tn_frame_tiers.csv`, `frame_sizes.csv`: frame sizes.
- `data/raw/manual_corrections.csv`: every hand correction and flag, with its source.
- `data/raw/phone_calls.csv`: office phone calls, hand-checked from RA notes and typed.
- `data/cleaned/analysis.rds`, `analysis.csv`: one row per drawn application, built by `01_data_cleaning.R`.
- `data/cleaned/function_crosswalk.csv`: how offices were keyword-coded into government functions, for review.

### Code

Run in order by `code/00_master.R`:

- `00a_refresh_raw_snapshot.R`: freezes the live trackers into a new snapshot. **Not run by the master script.** Run by hand for a new data date: set `RTI_DRIVE` to your path to the shared Drive `rti/` folder, clone the repos below into your home folder, set a new `snapshot_date` (it refuses to overwrite an existing snapshot), then update `SNAPSHOT` and `AS_OF` in `01_data_cleaning.R`, the snapshot path in `03` and `04`, and the count checks.
- `01_data_cleaning.R`: builds the analysis file. Stops if the key counts change.
- `02_load_packages_and_data.R`: packages, seed, theme, table helpers. Table and figure notes over 440 characters stop the run.
- `03_filing_and_balance.R`: sample table, balance table, cumulative filings figure.
- `04_response_descriptives.R`: rates by state, letter, tier, cohort and filer group; speed; Kaplan-Meier, outcome and function figures.
- `05_reply_content.R`: what coded replies contain; phone calls.
- `06_regressions_legal_salience.R`: letter effect, robustness, effect by horizon.
- `07_correlates.R`: descriptive correlates of response.
- `08_compile_note.R`: compiles the PDF, records package versions, copies outputs (never data) to Overleaf.

### Output

- `output/first_cut_note.pdf`: all tables and figures, with no prose beyond their notes.
- `output/tables/*.tex`, `output/figures/*.pdf`, `output/figures/*.tex`: each exhibit, ready to `\input`.
- `output/tables/headline_numbers.csv`: counts used to check results independently.
- `other/R_packages_info.csv`: R and package versions.

## Where everything else lives

This repository is self-contained for the analysis: everything above reruns from the frozen snapshot. The snapshot is tracker output with registration numbers, PIO contacts, filer names and coder notes removed, not the original documents. Those stay where they are:

| What | Where |
|---|---|
| Reply PDFs, filing receipts, RA sheet mirrors, emails | Shared Drive folder `rti/` |
| Reply coding with notes, earlier reports, commission data | `priyadarshiamar/rti-responses` (private) |
| How emails are matched to applications | `priyadarshiamar/rti-email-tracker` (private) |
| Sampling, assignments and letters | `in-rolls/rti` (Tamil Nadu), `priyadarshiamar/rti-telangana`, `rti-karnataka`, `rti-delhi-maharashtra` (public) |

## Key definitions

- **Eligible:** filed at least 30 days before the data date (by 29 September). Section 7(1) gives 30 days from receipt, and online filing makes receipt the filing date. Exceptions are not modeled: 35 days through an Assistant PIO (s.5(2)), a fresh clock at the new office after a s.6(3) transfer, time waiting on a fee excluded (s.7(3)), 40 days with third-party input (s.11). Days 35 and 45 are shown as sensitivity, partly because postal replies carry the letter's date but may still be in transit.
- **Any response:** earliest of a portal notice (disposed, returned, rejected), office email, s.6(3) transfer, fee demand, or a coded reply document.
- **Reply:** the same without transfers.
- **Information supplied:** coded full or partial. A lower bound, because some disposed notices have no document downloaded yet.
- **Phone calls:** never counted in any response measure. Only RA2 and RA4 could receive calls, so they are reported only among RA2 and RA4 filings.

## Design facts the analysis depends on

- **Randomization blocks differ.** Tamil Nadu: 30% legal within each department × tier stratum. Other states: the samplers shuffle over the whole batch (state × batch), despite a docstring saying "within strata". Department group is a sampling stratum there. So Tamil Nadu and other states are always estimated separately.
- **Filers are bundled.** RA2 and RA4 are one person and RA1 and RA3 the other, so phone reachability cannot be separated from name and postal address.
- **Filing order is not random.** Tamil Nadu's 140 applications past day 30 are RA1 and RA2's first batch, from 11 of 40 departments, and all 7 department-tier filings among them got the legal letter.

## Known limits

- **Telangana is a lower bound.** Its portal sends filing acknowledgments only, with no disposed, returned or transferred emails, and the RA sheets record no status checks. The rate cannot be read as silence until the portal is checked.
- **Letter results are an interim, unregistered look** while filing continues. The September report withheld them on purpose.
- **Reply coding is a first pass** by Claude, not double-coded.
- **Frame weights** are applied only to Tamil Nadu tier. Empirical-Bayes league tables, the commission-report comparison and appeals are not in this cut.

## Departures from the design document

- Kaplan-Meier curves are from `main.tex` (line 139), but its 90- and 180-day horizons have not been reached, so curves are censored at the data date.
- The Cox model in the robustness table is our addition. `main.tex` specifies linear probability models for the arms.
- Randomization-inference $p$-values (2,000 draws within blocks) are also our addition.
