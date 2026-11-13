# Evidence-based control mapping plan

All implementations below are **planned**. This is a selected learning subset; it is not a complete compliance checklist, audit, certification or authorization package.

Source baseline checked 2026-11-13: NIST SP 800-53 Rev. 5, current catalog release 5.2.0. The current FedRAMP Full Rev5 Control Reference marks the twelve base controls below as in **Rev5 Class C**, which includes the Moderate baseline. This is separate from the 20x track. Base-control membership does not mean all required enhancements, assigned parameters or assessment objectives are covered. [NIST catalog](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final), [FedRAMP control reference](https://www.fedramp.gov/2026/reference/controls/), [designation explanation](https://www.fedramp.gov/notices/0004/)

## Twelve selected controls

Every row currently has status `planned`, responsibility `customer-operated lab portion`, and FedRAMP relationship `Rev5 Class C base control present; partial demonstration only`.

| ID and title | Proposed implementation/test | Evidence to link at release | Residual gap / assessment question |
|---|---|---|---|
| AC-2 Account Management | Inventory Azure human/service and Linux accounts; document owner/purpose and disable a disposable test guest account | Identity inventory and disable/denied-login result | Full approval, joiner/mover/leaver and recurring review process absent |
| AC-6 Least Privilege | Separate deployment/admin access from analyst access; test one allowed read and denied write under an appropriately scoped identity | Role assignments, tested identity/scope and results | No full privileged-access management or separation-of-duties program |
| AU-2 Event Logging | Define required event classes and generate each: application anomaly, guest privilege use and Azure configuration change | Source/event/retention matrix and actual records | Selection justification and ongoing review are a small lab exercise |
| AU-6 Audit Record Review, Analysis, and Reporting | Review S1/S2 and hunt results against a defined time/change window | Queries, triage note, findings and escalation summary | No continuous SOC or independent review function |
| AU-12 Audit Record Generation | Validate the emitted audit records and AMA/DCR/diagnostic pipeline | Actor/time/action/result examples, settings and source health | Coverage is limited to configured sources; no Entra sign-in/EDR guarantee |
| CM-2 Baseline Configuration | Maintain Bicep and compare intended configuration with deployed resources | Commit, what-if/configuration export and drift note | No enterprise change board or complete configuration baseline |
| CM-6 Configuration Settings | Check SSH keys/root/password settings and NSG policy against documented lab settings | Guest settings and effective-rule/flow checks | Not a complete CIS or DISA benchmark assessment |
| CM-8 System Component Inventory | Enumerate resources, guest software, agents and any optional mission tools with versions/owners | Azure and guest inventory reconciled to design | No fleet discovery or organizational asset lifecycle |
| IR-4 Incident Handling | Execute one scoped incident from triage through recovery and lessons | Case timeline, evidence manifest, containment decision, recovery test and playbook revision | No real emergency, external reporting or enterprise incident program |
| SC-7 Boundary Protection | Explicitly limit private telemetry and management paths; test allowed and prohibited traffic | Effective rules, source/destination tests, packet interpretation | Public-IP administration, incomplete egress restrictions and lack of production boundary architecture are explicit gaps |
| SI-4 System Monitoring | Correlate configured data sources, trigger controlled detections, distinguish service/sensor health | DCR/source checks, rule/query outputs and actual alert/incident | No enterprise monitoring, EDR, RF sensing or exhaustive attack coverage |
| SA-11 Developer Testing and Evaluation | PR checks validate code/IaC and reject a known unsafe configuration mutation | Failed check, fix, rerun and focused test output | Test subset does not establish complete secure development or independent assessment |

Titles and membership can be inspected by family: [AC](https://www.fedramp.gov/2026/reference/controls/access-control/), [AU](https://www.fedramp.gov/2026/reference/controls/audit-and-accountability/), [CM](https://www.fedramp.gov/2026/reference/controls/configuration-management/), [IR](https://www.fedramp.gov/2026/reference/controls/incident-response/), [SC](https://www.fedramp.gov/2026/reference/controls/system-and-communications-protection/), [SI](https://www.fedramp.gov/2026/reference/controls/system-and-information-integrity/), [SA](https://www.fedramp.gov/2026/reference/controls/system-and-services-acquisition/).

The release mapping must expand at least three rows into requirement → implementation → assessment procedure → evidence → result → gap. Suggested examples: SC-7, AU-6 and SA-11. For SC-7, explicitly relate the deny-by-default test to the selected portion of SC-7(5); for SA-11, relate a supported static-analysis check to the selected portion of SA-11(1). Label these partial enhancement demonstrations, not satisfaction of all baseline enhancements.

Verify exact assigned parameters and applicability from the dated FedRAMP guidance when completing those examples. Do not invent retention periods, review cadences or response deadlines and call them FedRAMP requirements. Record a deliberate lab value separately from any verified external value. [FedRAMP guidance](https://www.fedramp.gov/2026/reference/rev5-control-guidance/), [NIST assessment procedures](https://csrc.nist.gov/pubs/sp/800/53/a/r5/upd1/final)

## Required mapping record

Use a small machine-readable JSON file at implementation time so the README and optional explainer can reuse the same truth:

`control_id`, `title`, `framework_version`, `source_url`, `source_checked_date`, `baseline_membership`, `selected_requirement_or_enhancement`, `verified_parameter_reference`, `lab_parameter`, `implementation`, `responsibility`, `test_id`, `evidence_paths`, `observed_result`, `status`, `gap`, `next_action`.

Allowed status values: `planned`, `implemented_unvalidated`, `tested_partial`, `documented_only`, `not_applicable_with_rationale`. No default green checks, compliance percentages, or inferred completion. Missing evidence keeps the row unvalidated. Validate that linked evidence exists. Provider-inherited status is not an allowed shortcut without a specific current authorized offering and responsibility document.

## Additional frameworks without scope expansion

| Reference | Role in this project |
|---|---|
| NIST CSF 2.0 | Organize outcomes: GOVERN responsibilities/boundary, IDENTIFY inventory, PROTECT access/configuration, DETECT monitoring/analysis, RESPOND investigation/containment, RECOVER restoration. These are relationships, not automatic equivalence to controls. |
| NIST SSDF 1.1 | Relate reviewed changes, controlled tooling, code analysis and security tests to selected practices such as PO.3, PW.7 and PW.8 after reading their precise text. No SSDF compliance claim. |
| MITRE ATT&CK Enterprise | Tag behavior-specific hunt/detection hypotheses and identify telemetry gaps. It is not a regulatory framework and not every outage maps to an adversary technique. |
| Aerospace SPARTA | Required space-system threat context for the S1 replay exercise. Track exact technique/source and analogue limitations separately from NIST/FedRAMP controls; see [SPARTA mapping](sparta-mapping.md). |
| NIST IR 8401 | Ground-segment context for mission/service priorities and trust boundaries. It predates CSF 2.0; do not silently equate its subcategory numbering with CSF 2.0. |
| RMF / SP 800-37 | Explain boundary, categorization rationale, selected controls, implementation, assessment evidence and ongoing monitoring as a miniature learning cycle. No ATO claim. |
| DISA STIG, SP 800-171/CMMC | Discuss conditional DoD/customer/contract applicability. Do not add a second full checklist or claim applicability solely because the job is in national security. Synthetic public lab data is not CUI. |

[CSF 2.0](https://doi.org/10.6028/NIST.CSWP.29), [SSDF](https://csrc.nist.gov/pubs/sp/800/218/final), [IR 8401](https://doi.org/10.6028/NIST.IR.8401), [RMF](https://doi.org/10.6028/NIST.SP.800-37r2)

## Responsibility and scope

The learner owns guest configuration, application behavior, identity/access choices, network rules, log enablement, review and response. Microsoft operates underlying cloud infrastructure; exact responsibility varies by service. An ordinary Azure deployment does not establish that this application inherits a particular FedRAMP control. Region, service offering, current certification package and customer responsibility matrix must support any inheritance assertion. [Azure shared responsibility](https://learn.microsoft.com/en-us/azure/security/fundamentals/shared-responsibility)

Describe the project as **a public, synthetic Azure lab demonstrating selected control concepts with test evidence**. Keep the unknowns visible: unauthenticated simulated mission data, short retention, limited sensing, partial baseline coverage, no formal assessor, no classified accreditation, and no production mission assurance.
