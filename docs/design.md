# Design and definitions

The audit files one standard RTI request online with each sampled office, asking for its own register of RTI applications over twelve months. Each letter is plain or legal-salience; the legal letter adds the s.7(1) deadline and the s.20 penalties. The full design is in `main.tex` in the Overleaf project.

## Who counts as past day 30

An application is past day 30 if it was filed at least 30 days before the data date. Section 7(1) gives 30 days from receipt, and online filing makes receipt the filing date.

The exceptions are not modeled: 35 days through an Assistant PIO (s.5(2)), a fresh clock at the new office after a s.6(3) transfer, time waiting on a fee excluded (s.7(3)), and 40 days with third-party input (s.11). Days 35 and 45 are reported as sensitivity, partly because a postal reply carries the letter's date but may still be in transit.

## Outcomes

| Outcome | Definition |
| --- | --- |
| Any response | Earliest of a portal notice (disposed, returned, rejected), office email, s.6(3) transfer, fee demand, a coded reply document, or a response date on the RA sheet. One portal reply seen only in an RA note (MH-002) is added by hand |
| Reply | The same, excluding transfers. A document coded as a transfer is not a reply |
| Information supplied | A reply coded full or partial. A lower bound, because some disposed notices have no document downloaded yet |
| Phone call | Reported separately and never counted as a response. Only RA2 and RA4 could receive calls |

Silent applications are right-censored at the data date in the Kaplan-Meier curves.

An application counts as **filed** if the RA sheet holds a real registration number or the portal sent an acknowledgment. A note typed into the number cell does not count.

## Coding the replies

Two coders read each reply independently, and the second could not see the first codes. Where they disagreed, an adjudicator who could not tell them apart settled the field from the documents, under the rules below. A last audit re-read every reply coded full or as supplying the Section 25 return, because codes both coders agreed on had not been checked against those rules. It changed 3 replies, including TN-027, whose letter says a report is enclosed when the file holds none. Codes describe what is in the file, not what a letter claims. TN-492 arrived too late for the first pass, so it has only the second coder and the adjudicator. Agreement is measured on the 104 files coded twice, which include TN-469, later found to be no reply.

| Disposition | Rule |
| --- | --- |
| Full | Register information supplied (Format A, B or C), and the Section 25 return supplied or stated not held |
| Partial | Some requested information actually supplied, but not all of the above |
| Fee asked first | Nothing supplied yet, and the register information is offered on payment |
| Denied | Nothing supplied, and the register information is refused or deflected. This includes "not maintained in that form", inspection-only offers, and fees that buy only the Section 25 return |
| Returned | Bounced back with nothing, and no refusal reasoning beyond asking to clarify or refile |
| Transferred | Handed to another office under s.6(3) with no data supplied |

"Full" is stricter than in the first pass, which is the main reason full replies fell from 27 to 15. Whether to require the Section 25 return is a judgment call. "Information supplied" (full or partial) does not depend on it, and it is what the coders agree on most (92%). The reply date is the date on the earliest letter sent to the applicant. A letter with no legible date keeps its arrival date.

## Randomization and fixed effects

Randomization differs in Tamil Nadu, so Tamil Nadu and the other states are always estimated separately.

| Sample | Sampling | Letter randomized within | Block fixed effect |
| --- | --- | --- | --- |
| Tamil Nadu | Department × tier quotas | Department × tier stratum | Department × tier |
| Telangana, Karnataka | Proportional to department group, with a cap | The whole batch | State × batch |
| Delhi, Maharashtra | Proportional to department group, with a cap | State within batch | State × batch |

The Telangana and Karnataka sampler docstrings say treatment is balanced within strata, but the code shuffles over the batch, and the tests confirm balance only at that level. Department group is a sampling stratum in these states. Adding it as a fixed effect leaves few applications with both letters in a group, and the note reports how few.

Standard errors are robust. Each office appears once in the sample, so this is the same as clustering by office, as `main.tex` specifies.

## Things that shape the comparisons

- **Filing order is not random.** Tamil Nadu's applications past day 30 are RA1 and RA2's first batch, from 11 of 40 departments, and all 7 department-tier filings among them got the legal letter. Raw comparisons by letter are confounded with tier, which the block fixed effects remove.
- **Filers are bundled.** RA2 and RA4 are one person, and RA1 and RA3 another. Phone reachability cannot be separated from the filer's name and postal address.
- **Telangana is a lower bound.** Its portal sends filing acknowledgments only, and the RA sheets record no status checks.
- **Reply coding was done by Claude:** the first pass, the second coding and the adjudication, each in a separate context. It has not yet been checked by a person.
- **Maharashtra's letter is shorter**, because its portal caps requests at 150 words. The robustness table excludes it.

## Departures from the design document

This is a first cut and does not follow `main.tex` throughout.

- Kaplan-Meier curves follow `main.tex`, but its 90- and 180-day horizons have not been reached, so curves are censored at the data date.
- The Cox model and the randomization-inference p-values are our additions. `main.tex` specifies linear probability models for the arms.
- Frame weights are applied only to Tamil Nadu by tier. League tables, the commission-report comparison and appeals are not in this cut.
- Results by letter are an interim, unregistered look while filing continues.
