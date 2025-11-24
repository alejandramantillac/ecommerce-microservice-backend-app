# Request for Change (RFC) Template

> Duplicate this file per change and store it under `docs/change-management/rfcs/<change-id>.md` or link it to your ticketing tool. All sections are mandatory unless marked optional.

## 1. Metadata
- **Change ID:** `RFC-YYYY-XX`
- **Title:** `<Short descriptive title>`
- **Requester / Owner:** `<Name, team>`
- **Stakeholders:** `<Product, QA, SRE, etc.>`
- **Target Environment(s):** `<dev | staging | prod>`
- **Planned Window:** `<date + time window>`
- **Risk Level:** `Low / Medium / High`

## 2. Description
Describe the change in plain language. What is being deployed? Include links to design documents, tickets, and related features.

## 3. Justification
Why is this change needed? Business value, bug fix, compliance, etc.

## 4. Impact Analysis
- Affected services / components.
- Dependencies (databases, third-party APIs, infrastructure).
- User impact (downtime, degraded experience).
- Monitoring / alerting updates required?

## 5. Implementation Plan
1. Step-by-step deployment actions (CLI commands, Jenkins job, Terraform apply, etc.).
2. Preconditions / feature flags.
3. Validation tests (unit, integration, manual checks).

## 6. Rollback Plan
- Reference the relevant section in [`docs/operations/rollback-playbooks.md`](../operations/rollback-playbooks.md).
- Commands to execute (tested in staging).
- Expected RTO / RPO for this change.
- Data considerations (backups, migrations).

## 7. Communication Plan
- Slack channels / mailing lists to notify.
- Stakeholder contacts for go/no-go.
- Incident bridge details if required.

## 8. Approval
| Role | Name | Date | Decision / Notes |
|------|------|------|------------------|
| Requester |  |  |  |
| SRE Reviewer |  |  |  |
| Release Manager |  |  |  |
| CAB (if required) |  |  |  |

## 9. Execution Log (to be completed during/after change)
- Actual start / end times.
- Jenkins build / deployment links.
- Validation results.
- Issues encountered and remediation.
- Rollback executed? (Y/N; include duration if yes.)

## 10. Post-Implementation Review
- Outcome summary (Success / Rolled Back / Deferred).
- Follow-up tasks / bugs created.
- Lessons learned.

