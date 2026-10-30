# Data and provenance

## The chain

```
raw emails, attachments ─┐
RA sheets (frozen)       ├─ code/raw_*.R ──> data/derived/ ─┐
overrides, hand fixes    │                                  │
assignment lists ────────┘                                  ├─ code/0*.R ──> tables, figures
                                                            │
reply PDFs ── read by two coders and an adjudicator ──> data/hand/ ─┘
```

Everything reruns from the originals except the reply coding, which is judgment. It can be audited against the PDFs or coded again, but not recomputed.

## Originals

The originals carry filer names and addresses, phone numbers, inbox addresses, one-time passwords and payment references, and one reply is larger than GitHub's file limit. They stay in the shared Drive folder `rti/`. `data/raw_manifest.csv` pins each file by checksum, with its path hashed because paths can hold inbox and filer names, so anyone can confirm they have what this analysis used.

| Input | Where in `rti/` | Files | Used for |
| --- | --- | ---: | --- |
| Raw emails from the 3 filing inboxes | `email_tracker/raw/` | 252 batches, 2,030 unique messages | Acknowledgments, notices, transfers, fees, office replies |
| Email attachments | `email_tracker/attachments/` | 55 PDFs | Registration numbers quoted in replies |
| RA filing sheets as of the data date | `raw_snapshots/2026-10-29/ra_sheets/` | 18 tabs | Registration numbers, filing dates, RA notes |
| Tab rules, overrides, matching stop words | `raw_snapshots/2026-10-29/` | 3 | Which tabs count; earlier manual matches |
| Reply PDFs | `rti responses/` | 151 | Reply coding |
| Filing receipts | `Filed_RTI/` | 994 | Filing audit |
| Tamil Nadu frame | `tn_universe.csv` | 1 | Frame sizes and tier weights |

Only the RA sheets and overrides get overwritten, so only they are copied to the dated folder. The live RA sheets are Google Sheets; these copies are their hourly CSV mirror on the data date. Emails, attachments, PDFs and receipts only get added to, so the manifest pins them where they are. Messages dated after the data date are ignored.

The assignment lists in `data/raw/assignments/` come from Drive (Tamil Nadu) and the public state repos.

## Made by hand

| File | What it is |
| --- | --- |
| `data/hand/responses_coded.csv` | First-pass reply coding, unchanged, with notes |
| `data/hand/second_coding.csv` | Blind second coding of every reply |
| `data/hand/coding_adjudicated.csv` | Each settled disagreement, with its basis |
| `data/hand/match_fixes.csv` | Messages matched by reading them during the audit |
| `data/hand/manual_corrections.csv` | Corrections and flags, each with its source |
| `data/hand/phone_calls.csv` | Office calls from RA notes |
| `raw_snapshots/2026-10-29/overrides.csv` (Drive) | 25 earlier manual matches; its notes hold contact details, so it stays out of git |

## Cross-checks

`code/raw_05_compare_tracker.R` compares the rebuild with the email tracker's output as of the data date, application by application. The rebuild is a separate R implementation, so a difference means one of them is wrong. It shares the tracker's matching rules, so agreement alone does not prove those rules right, and the rules were audited separately below.

Ten of 1,665 applications differ, all explained in `tests/testthat/test-data.R`:

| Applications | Why |
| --- | --- |
| KA-150, TN-509, TN-513, TN-592 | The number cell says no number was issued or the attempt failed. The tracker counted any text as filed, which is why it reported 1,000 |
| TN-289, TN-900 | Dates held for attempts that were never filed |
| KA-154, TN-492 | Notices that arrived on the data date after the tracker ran at 08:10 UTC |
| KA-047, MH-053 | Unmatched office mail, read and matched by hand. Both replies were already counted |

## Audit of the matching

- **Unmatched mail after the fixes:** 120 Telangana acknowledgments, which carry no number and can only be matched by a filing time the RA did not always record; 2 acknowledgments that are repeat filings (KA-167, TN-971); and 1 junk email.
- **Low-confidence matches:** 5, made on office words and a date. All 5 have a reply PDF, and the offices in the replies were compared with the assigned offices. Results without these matches are in the robustness table.
- **Filing dates:** the portal's date where an acknowledgment exists (696), otherwise the RA sheet (300). Where both exist, 564 of 574 agree within a day. The exceptions are 8 Maharashtra filings at 6 days, where payment followed later, KA-025 at 3 days, and TN-308 at 40 days, a typing error.
- **Repeat filings with one office:** KA-025, KA-062, KA-152, KA-167, TN-971.
- **Missing inbox:** 161 Tamil Nadu filings have no acknowledgment, yet they receive portal notices at about the same rate as those that do (6 of 161, 18 of 367). There is no sign of a fourth inbox, though this does not rule one out.

## What is still missing

- **Telangana outcomes.** Its portal sends no status emails, and no status checks are recorded. Replies left only on the portal are not observed.
- **Delhi and Maharashtra portal replies.** No status notices reach the inboxes, so only replies that offices email, or that RAs download, are seen.
- **Replies not downloaded.** See "Notice, no PDF" in the note. The portal says these were answered, but no document is on file.
- **Postal replies.** They appear only once an RA uploads them, and arrival is not logged.
- **Spam from before the collector.** The collector started on 27 September, and Gmail deletes spam after 30 days, so spam from before 28 August would be gone. Filing started on 26 August, so the exposure is small.
- **Documents that need a look:** TN-276 claims a hardcopy was posted, but none is on file. KA-033 has no cover letter tying it to the application. KA-137's register seems to be missing rows 1 to 6. MH-022 has no letter, so its date is its arrival on the portal. The dates for DL-009 and KA-020 come from the email, since their letters are undated.

## Privacy

Registration numbers, PIO contacts, filer names and addresses stay out of git. Parsed emails and sheets go to `data/private/`, which is gitignored. `code/check_privacy.R` fails if git would publish an email, a phone number, a registration number or a filled personal column. It also checks any terms in a local, gitignored `.private_terms` file, so filer names can be checked without being published. It runs in `make check`, in CI and, after `make hooks`, before every push.

This repository is private because filing continues and it holds interim results by letter. Office names appear because they are public.

## A new data date

1. Copy the RA sheets for that date; `code/raw_00_freeze.R` then writes the dated Drive folder and the assignment lists. Set `RTI_SHEETS_COPY` if the copy is not in the default place. It refuses to overwrite a freeze.
2. Update `RAW_FREEZE` and `AS_OF` in `code/00_config.R`, then run `code/raw_00b_manifest.R` to pin the originals.
3. `make rebuild`, code any new replies by hand, then revisit the counts checked in `01_data_cleaning.R` and `tests/`.
