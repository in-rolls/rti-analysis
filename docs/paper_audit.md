# Paper audit and design reconciliation

The frozen October 29, 2026 derived data reproduce the headline response counts and main treatment coefficients. This audit does not validate raw extraction or reply coding against the private source documents.

## Claim ledger

| Claim | Universe and denominator | Producer | Interpretation |
| --- | --- | --- | --- |
| Recorded response within 30 days | Filed applications at least 30 days old, by state | `scripts/03_summarize_responses.R`, `response_by_state.csv` | Realized sample, mixed arms; missing portal events can appear as zero |
| Information within 30 days | Same mature sample; full or partial coded reply by horizon | Same | Documented information, not complete ascertainment |
| Tamil Nadu standardization | Mature sample's tier rates, weighted by frame tier shares | Same | Adjusts tier composition only, not department selection or filing |
| Legal-salience contrast | Mature observations retained by block-FE model | `scripts/05_estimate_effects.R`, `main_effects.csv` | Interim within-block contrast, conditional on eligibility and ascertainment assumptions |
| Coding agreement | Replies coded twice, not the mature filing sample | `scripts/07_audit_data.R`, `coding_agreement.csv` | Agreement between model coding passes, not human validation |

R writes computed manuscript values to `tabs/macros.tex` in `scripts/08_write_paper_values.R`. The editable manuscript reads those macros and the generated tables directly.

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

## Prose and literature revision

The paper now explains weighting as adjusting the mix of department headquarters, head-of-department offices, and subordinate offices to match their shares on the portal. The table uses an explained `Adjusted` row. This is the same calculation previously labeled tier-standardized; no weights or outcomes changed. Repository paths, build instructions, and author-facing verification notes have been removed from the article and retained here.

The expanded review uses 17 references in `ms/references.bib`, organized around Indian assessments, implementation and enforcement, request wording, requester identity, administrative burden, and measurement of successful access. BibTeX generates the bibliography and all entries are cited. In addition to the sources above, the following primary records were checked:

| Reference | Primary record | Use in paper |
| --- | --- | --- |
| RaaG and NCPRI (2009) | https://www.snsindia.org/wp-content/uploads/2018/10/RAAG-study-executive-summary.pdf | Mixed-method assessment including researcher-filed applications |
| RaaG and CES (2014) | https://www.snsindia.org/wp-content/uploads/2024/01/Report-RaaG-2014.pdf | Applicant accounts, reported performance, and research-team requests; request and sample comparability |
| Peisakhin (2012) | https://www.journals.uchicago.edu/doi/abs/10.1086/663727 | Experimental evidence on service access in India |
| Relly et al. (2020) | https://experts.arizona.edu/en/publications/more-than-a-decade-in-the-making-a-study-of-the-implementation-of/ | Implementation, civic engagement, bureaucratic and political factors |
| SNS (2025) | https://www.snsindia.org/wp-content/uploads/2025/10/Report-Card-Key-findings-2025.pdf | Vacancies, backlogs, and penalties in its reporting period |
| Grimmelikhuijsen et al. (2019) | https://journal-bpa.org/index.php/jbpa/article/view/34 | Dutch replication of formal versus informal requests |
| Spac et al. (2018) | https://www.muni.cz/en/research/publications/1417556 | Legal reference versus moral appeal in Slovakia |
| Cuillier (2010) | https://experts.arizona.edu/en/publications/honey-v-vinegar-testing-compliance-gaining-theories-in-the-contex/ | Different effects of threatening and friendly wording |
| ben-Aaron et al. (2017) | https://www.microsoft.com/en-us/research/publication/transparency-by-conformity-a-field-experiment-evaluating-openness-in-local-governments/ | Peer compliance information, response speed and completeness |
| Michener et al. (2020) | https://onlinelibrary.wiley.com/doi/abs/10.1111/gove.12416 | Institutional versus noninstitutional requesters in Brazil |
| Pineiro Rodriguez and Rossel (2018) | https://investigadores.ucu.edu.uy/en/publications/a-field-experiment-on-bureaucratic-discretionary-bias-under-foi-l/ | Gender differences in the benefit of invoking the law in Uruguay |
| Lagunes and Pocasangre (2019) | https://cgeg.sipa.columbia.edu/news/dynamic-transparency-audit-mexicos-freedom-information-act | Changes in response frequency, speed, and quality in Mexico |
| Cicatiello et al. (2024) | https://www.sciencedirect.com/science/article/pii/S0167268124000489 | Regional variation in treatment of prominent requesters in Italy |
| Spac et al. (2025) | https://www.muni.cz/en/research/publications/2491597 | Interaction between information burden and legal references |

Relly et al.'s year was corrected to 2020 in the paper's bibliography using the authors' institutional record; the companion bibliography listed 2021. No change was made to the companion repository. Claims use the evidence inspected in abstracts, institutional records, and reports; this is not a claim to have read every article in full or conducted an exhaustive systematic review.

After the prose revision, the complete analysis, lint, privacy scan, and 216 assertions passed again (one unavailable-originals test skipped). The final paper has twelve pages, all visually inspected. All seventeen bibliography entries are cited, and LaTeX/BibTeX report no missing citations, references, overfull boxes, or bibliography warnings.

## R compendium refactor (November 2, 2026)

The repository now follows `finite-sample/know_hidden`'s organization: shared R functions, ordered scripts, generated tables and figures, and an editable LaTeX manuscript. R performs all input preparation and analysis; there is no Python dependency. Runtime package installation and automatic copying to a personal Overleaf folder were removed. The manuscript reads computed numerical macros and builds with XeLaTeX through `latexmk`.

The application CSV and all four result CSVs are byte-identical to the saved pre-refactor outputs. All fourteen table contents are unchanged; the renderer now constrains their width to the page. The input checksums and statistical specifications are unchanged. Earlier paths and their hashes are recorded in `relocations.csv`.

`renv.lock` now records the tested R 4.6.0 environment, including development tools. The project library was populated from installed packages, then `make restore check` succeeded with renv enabled: restoration reported synchronization, lint passed, 212 assertions passed, no test warnings or failures occurred, and privacy checks passed. The sole skipped test requires the unavailable private originals. The earlier README and generated-TeX text tests were replaced by checks of generated numerical macros.

The manuscript has thirteen pages and the exhibit appendix eleven. All pages were visually inspected; final LaTeX logs contain no overfull boxes, unresolved references, or warnings. `actionlint` and `git diff --check` passed. Docker is installed but no daemon is available, so the container target was not validated. A fresh network-only installation and Linux CI are distinct from the successful local restoration using installed packages.

In this sandbox, the successful command set `RENV_PATHS_CACHE=/private/tmp/rti-renv-cache`, `R_USER_CONFIG_DIR=/private/tmp/rti-r-config`, and `R_USER_CACHE_DIR=/private/tmp/rti-r-cache` to writable locations. It did not disable renv. `other/r_packages_info.csv` records the tested versions.

## Consolidated inputs and recovered originals (November 2, 2026)

The ten upstream frame and assignment inputs now point to one immutable commit in `in-rolls/rti`, introduced by fieldwork PR #3. Every input retains its prior MD5 checksum. Local `make check` passes 212 assertions, lint, and privacy checks; the analysis CSV and all four result CSVs remain byte-identical to the pre-refactor baseline. The manuscript and exhibits require no numerical changes.

The connected Drive supplied the three frozen extraction configuration files and 18 frozen RA sheet exports. Together with the local ZIP and recovered email/attachment files, 694 original files have been downloaded and checked against the manifest, with no content differences. This includes all pinned email batches, attachments, and frozen extraction settings. Re-running email parsing, sheet ingestion, and event matching reproduces their existing derived CSVs byte-for-byte.

The current Drive listing and local ZIP still lack 131 pinned receipt or response-document paths. Other receipt/response files are listed on Drive but have not all been downloaded; the full 1,473-file audit and status reconstruction remain incomplete. These limits do not change the frozen analytical results. Response extraction remains in this repository until the full cutover can be verified.

The development fork is now `in-rolls/rti-paper`. Priyadarshi plans to transfer the original repository to `in-rolls/rti-analysis`, which will become the destination for a subsequent paper PR.
