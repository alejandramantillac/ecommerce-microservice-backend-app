# Change Calendar

> Update this calendar as soon as an RFC is approved and again after execution. Use one row per change window. Store historical data for audit purposes.

| Date & Time (UTC) | Change ID / RFC | Description | Owner / Backup | Environment | Status | Rollback Verified | Links |
|-------------------|-----------------|-------------|----------------|-------------|--------|-------------------|-------|
| 2025-11-24 15:00-16:00 | RFC-2025-11 | Deploy `user-service` hotfix for pricing bug | A. Mantilla / J. Doe | staging | **Planned** | Yes (staging) | Jenkins stage #112 |
| 2025-11-25 18:00-19:00 | RFC-2025-12 | Production rollout `v0.7.0` (checkout revamp) | Release Mgr / SRE on-call | prod | **Approved** | Yes (auto rollback) | RFC doc, release #0.7.0 |
| … | … | … | … | … | … | … | … |

### Status Legend
- **Planned** – approved but not started.
- **In Progress** – change window open, deployment running.
- **Completed** – deployed successfully (no rollback).
- **Rolled Back** – automated or manual rollback executed (document details in RFC).
- **Blocked** – postponed due to external dependency.

### Instructions
1. Reference the RFC ID and hyperlink to the file/ticket.
2. Use local timezone columns if needed, but keep UTC for single source of truth.
3. Record actual start/end times once the window closes.
4. Attach Jenkins build links, monitoring dashboards, and any PIR documents.
5. Keep a minimum rolling window of two weeks visible so stakeholders can plan around blackout periods.

