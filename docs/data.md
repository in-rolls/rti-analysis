# Data and provenance

Everything reruns from what is in this repository. `data/raw/snapshot_2026-10-29/` freezes the tracker outputs as of the data date, so results do not move when the trackers update, and `01_data_cleaning.R` stops if a file differs from `MANIFEST.csv`.

| File | Source | Records | Removed at snapshot |
| --- | --- | ---: | --- |
| `status_panel.csv` | Email tracker, one row per drawn application | 1,665 | Registration numbers, filer names |
| `events.csv` | Email tracker, one row per matched message | 831 | Everything except date, kind, application, match method and confidence |
| `responses_coded.csv` | `rti-responses`, first-pass coding of replies | 104 | Free-text coder notes |
| `assignments_tn.csv` | Tamil Nadu draw | 1,000 | Tracking columns |
| `assignments_other.csv` | State repos, two batches where they exist | 665 | Tracking columns |
| `tn_frame_tiers.csv`, `frame_sizes.csv` | Portal frames | 3, 5 | Everything except counts |

`SOURCES.csv` records where each file came from and when it was last modified.

## Hand-coded files

- `data/raw/manual_corrections.csv` lists every correction and flag with its source. Two change the analysis: the reply filed under TG-150 belongs to TG-162 (it came from TG-162's office), and MH-002's portal reply appears only in an RA note. TN-592 has no filing date, so it has no exposure. TN-027 got the wrong letter and stays in its assigned arm.
- `data/raw/phone_calls.csv` lists office calls, hand-checked from RA notes and typed. Calls are self-reported, so they may be undercounted.

## Where the originals live

| What | Where |
| --- | --- |
| Reply PDFs, filing receipts, RA sheet mirrors, emails | Shared Drive folder `rti/` |
| Reply coding with notes, earlier reports, commission data | `priyadarshiamar/rti-responses` (private) |
| How emails are matched to applications | `priyadarshiamar/rti-email-tracker` (private) |
| Sampling, assignments and letters | `in-rolls/rti` (Tamil Nadu), `priyadarshiamar/rti-telangana`, `rti-karnataka`, `rti-delhi-maharashtra` (public) |

## Privacy

Registration numbers, PIO contacts, filer names and postal addresses stay out of this repository. `code/check_privacy.R` fails if git would publish an email, a phone number, a registration number or a dropped column. It also checks any terms listed in a local, gitignored `.private_terms` file, so filer names can be checked without being published. It runs in `make check`, in CI and, after `make hooks`, before every push. Office names appear because they are public.

This repository is private because filing continues and it holds interim results by letter.

## A new data date

Set `RTI_DRIVE` to your path to the shared Drive `rti/` folder, clone the state repos and `rti-responses` into your home folder, set a new `snapshot_date` in `code/00a_refresh_raw_snapshot.R` and run it. It refuses to overwrite an existing snapshot. Then update `SNAPSHOT` and `AS_OF` in `code/00_config.R`, and revisit the counts checked in `01_data_cleaning.R` and `tests/`.
