# Paper audit and design reconciliation

The frozen October 29, 2026 derived data reproduce the headline response counts and main treatment coefficients. This audit does not validate raw extraction or reply coding against the private source documents.

## Claim ledger

| Claim | Universe and denominator | Producer | Interpretation |
| --- | --- | --- | --- |
| Recorded response within 30 days | Filed applications at least 30 days old, by state | `04_response_descriptives.R`, `response_by_state.csv` | Realized sample, mixed arms; missing portal events can appear as zero |
| Information within 30 days | Same mature sample; full or partial coded reply by horizon | Same | Documented information, not complete ascertainment |
| Tamil Nadu standardization | Mature sample's tier rates, weighted by frame tier shares | Same | Adjusts tier composition only, not department selection or filing |
| Legal-salience contrast | Mature observations retained by block-FE model | `06_regressions_legal_salience.R`, `main_effects.csv` | Interim within-block contrast, conditional on eligibility and ascertainment assumptions |
| Coding agreement | Replies coded twice, not the mature filing sample | `07b_data_checks.R`, `coding_agreement.csv` | Agreement between model coding passes, not human validation |

All numerical manuscript values use the existing computed README substitution map in `08_compile_note.R`; tables are generated inputs. Literal numbers in the manuscript are outcome horizons, statutory section identifiers, citation metadata, or the design commit identifier.

## Verified calculations

An independent count from the committed analysis CSV gave any-response/information counts: Tamil Nadu 18/7 of 140; Telangana 2/2 of 187; Karnataka 41/22 of 78; Delhi 5/3 of 22; Maharashtra 13/6 of 28. Excluding Telangana gives 77/268 (28.7%) recorded responses and 38/268 (14.2%) information provision.

Independent within-block demeaning reproduced 1.09504 percentage points for Tamil Nadu, 3.58585 for other states, and 10.88462 excluding Telangana from other states. No change to these estimates was warranted. Tamil Nadu drops 12 singleton observations, retaining 128; all seven eligible department-HQ applications received treatment and identify no HQ contrast.

## Corrections

- The main regression caption said replies excluded transfers and fees. Construction and the outcome definition exclude transfers only. Seven mature fee-pending applications count as replies. Corrected the caption without changing outcomes.
- The state table called every confidence interval Wilson. The tier-standardized Tamil Nadu interval uses a normal approximation: 6.97594%, interval [2.56785%, 11.38403%]. Corrected its note.
- Renamed the Tamil Nadu row to tier-standardized. Its early sample spans 11 of 40 departments; weighting by tier alone does not make it representative of the full frame.

## Design reconciliation

The author-specified reference is `in-rolls/rti/ms/ms.tex` at commit `a2815a4e54279b07b0715b4811dca5d9bc7cb323`. The upstream analysis refers to an Overleaf `main.tex`, unavailable here; equivalence is not assumed. A versioned design is not evidence of prospective registration.

| Reference design | Existing snapshot | Paper treatment |
| --- | --- | --- |
| Plain-arm descriptive backbone | State summaries pool both arms | Explicit realized treatment-mixture estimand; plain means in regression table |
| Frame-weighted descriptive target | Tier standardization only for Tamil Nadu | No statewide or national representative claim |
| 90-/180-day horizons and appeals | Interim short follow-up | No claims about eventual receipt or appeals |
| Linear probability treatment models | LPM plus Cox and permutation additions | Additions marked exploratory |
| Register demand, commission comparisons, peer information, reservation arm | Not established by this analysis | Future work, not results |

## Inference and measurement checks

Eligibility conditions on successful filing and follow-up after assignment. Block controls do not remove within-block selection. Balance nonsignificance does not prove exchangeability. Randomization inference conditions on eligible block arm totals; department-FE variants condition further on block-by-department totals. That finer conditioning is not inherently incorrect, but it differs from unconditional assignment and requires the same selection assumptions.

Telangana's unobserved outcomes are not confirmed silence. Delhi and Maharashtra also lack portal notices; missing downloads and postal replies affect substantive classification. Excluding Telangana does not solve all missingness. Kaplan–Meier handles administrative censoring under its assumptions, not unrecorded events. Letter dates and arrival dates are mixed, so curves are not a uniform measure of applicant receipt time.

Raw matching, repeat-filing histories, adjudications, and claims about absent documents cannot be independently verified without the private archive. Model agreement is not accuracy. Do not describe the common 30-day threshold as a case-specific legal compliance determination. Filer identity and phone reachability are bundled and do not identify distinct causal effects.

## Sources checked for the manuscript

- Peisakhin and Pinto (2010): paper at https://accountabilityindia.in/sites/default/files/document-library/regulationandgovernance_peisakhin.pdf; DOI 10.1111/j.1748-5991.2010.01081.x.
- Worthy, John, and Vannoni (2017): authors' institutional record at https://kclpure.kcl.ac.uk/portal/en/publications/transparency-at-the-parish-pump-a-field-experiment-to-measure-the/; DOI 10.1093/jopart/muw063.
- Berliner, Bagozzi, and Palmer-Rubin (2018): author manuscript at https://eprints.lse.ac.uk/100496/1/berlinerbagozzipalmerrubin_worlddevelopment_whatinformationdocitizenswant.pdf; DOI 10.1016/j.worlddev.2018.04.016.

The paper does not import unverified novelty claims, current legal claims, registration claims, or ethics approval claims from the prospective design.

## Local validation (November 1, 2026)

- All ten pinned upstream files were recovered from their Git histories and matched the manifest MD5 checksums. Derived-to-analysis rebuilding left `analysis.csv` unchanged.
- `make check` completed: 216 assertions passed, zero failures or test warnings, one skipped raw-originals test; lint and privacy checks passed. Both PDFs compiled. The paper has ten pages, all visually inspected; the final LaTeX log has no undefined references or overfull boxes.
- Local R is 4.6.0. Exact `renv` restoration was attempted but encountered a missing compiler header, then network restrictions. The successful run used installed system packages with the project pacman installation. `other/R_packages_info.csv` records those actual versions. The pinned R 4.5.2 environment remains to be verified in CI; no lockfile was changed. Fixest emitted a package-build-version advisory (built under 4.6.1).
- The locally rebuilt coefficient CSV differs from upstream only at floating-point precision (roughly 1e-14); displayed estimates and standard errors are unchanged.
- To repeat the local fallback, set `RENV_CONFIG_AUTOLOADER_ENABLED=false`, `R_USER_CONFIG_DIR=/private/tmp/rti-r-config`, and `R_LIBS_USER` to this checkout's `renv/library/macos/R-4.6/aarch64-apple-darwin23`, then run `make check`. These are environment workarounds, not replacements for the pinned replication environment.
- Private source documents, human coding validation, registration and ethics records remain outstanding. The draft is suitable for author review, not a claim that those tasks have been completed.
