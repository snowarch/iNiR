---
description: Governance and release follow-through checklist for public-contract, contributor-process, or release-prep changes.
---

# Governance & Release Check

Use this workflow when a task changes governance, contributor workflow, public contracts, or release metadata.

1. Classify the task:
   - governance-only
   - contributor/public docs
   - public runtime contract
   - release-prep

2. Read the governing sources:
   - root `AGENTS.md`
   - scoped `AGENTS.md` if the touched area has one
   - relevant `.windsurf/rules/*.md`
   - contributor docs affected by the change

3. Identify collateral surfaces before editing:
   - config/schema → `Config.qml` + `defaults/config.json` + consumers/settings/migrations
   - IPC/launcher → handler + callers + `docs/IPC.md`
   - scripts/dependencies → caller + setup/updater/migrations + packaging/distribution docs
   - governance → root/scoped `AGENTS.md` + rules + workflows + external always-on memory if truly needed
   - release-prep → `VERSION` + `CHANGELOG.md` + tag + release notes

4. Edit the minimum set of files required to leave the contract consistent.

5. Re-read nearby governance surfaces and remove contradictions.

6. Validate the result:
   - runtime changes → restart + logs + feature path
   - docs/governance changes → re-read changed files and grep for stale names/commands/tooling
   - release-prep → confirm `VERSION`, `CHANGELOG.md`, tag name, and release notes all match

7. Finish only when the operational contract is coherent across:
   - code
   - docs
   - governance
   - release metadata
