---
trigger: model_decision
description: Pull when changing governance, contributor workflow, public contracts, versioning, changelog, PR discipline, tags, or release expectations.
---

# iNiR Governance, Release & Public-Contract Discipline

Use this rule when the task changes how contributors or agents are expected to work, or when it changes a public/project contract that must stay synchronized across code, docs, and release metadata.

## 1) First classify the change

Before editing, decide which class of change you are making:

- **Governance-only**
  - `AGENTS.md`
  - scoped `AGENTS.md`
  - `.windsurf/rules/`
  - `.windsurf/workflows/`
  - local agent memories

- **Contributor/public docs**
  - `docs/`
  - `agents/docs/`
  - README / install / IPC / packages / limitations

- **Public runtime contract**
  - IPC targets/functions
  - launcher commands
  - config keys
  - migration behavior
  - distributed dependency expectations

- **Release-prep**
  - `VERSION`
  - `CHANGELOG.md`
  - tags
  - release notes / release PR

Do not treat these as interchangeable. A feature patch is not automatically a release-prep patch.

## 2) Source-of-truth rules

- **Real code + runtime behavior** beats remembered docs.
- **Root AGENTS** defines the global contract.
- **Scoped AGENTS** refine local behavior.
- **Rules** hold deep topical guidance.
- **Workflows** hold repeatable procedures.
- **Contributor docs** explain the repo to humans; they should not redefine code reality.

## 3) Collateral update matrix

### Config/public option change

Update together:

- `modules/common/Config.qml`
- `defaults/config.json`
- consumer(s)
- settings UI when applicable
- migration(s) when existing users need compatibility
- contributor docs / changelog if the change is externally meaningful

### IPC / launcher / callable contract change

Update together:

- handler implementation
- callers / keybinds / scripts
- `docs/IPC.md`
- rule/workflow docs if agent behavior depends on it
- changelog / release notes when user-visible

### Script / setup / dependency change

Update together:

- script
- caller
- setup / installer / updater / migrations if relevant
- packaging docs (`docs/PACKAGES.md`, distribution docs) if dependency surface changed

### Governance change

Update together:

- root/scoped `AGENTS.md`
- `.windsurf/rules/`
- `.windsurf/workflows/`
- local always-on memory only if the behavior truly must apply outside the repo

Do not bury a repo-specific rule in a global external memory if it belongs in repo governance.

## 4) Git, commits and PR discipline

### Commits

Preferred format:

`type(scope): summary`

Examples:

- `feat(overview): add keyboard action mode`
- `fix(config): persist new backdrop defaults`
- `docs(governance): rewrite release workflow`

### PR expectations

A good PR should make the following explicit:

- problem/context
- authoritative layer chosen
- main changes
- collateral surfaces updated
- migration/compatibility impact
- validation performed

If the change is release-relevant, the PR should say so explicitly.

## 5) Versioning, changelog, tags, releases

### Version source

- Current project version lives in `VERSION`
- Changelog lives in `CHANGELOG.md`
- Tag format is `vX.Y.Z`

### SemVer

- **MAJOR** → breaking compatibility / removed public behavior / incompatible config or workflow shift
- **MINOR** → new user-facing features / new public IPC / new public config surface
- **PATCH** → fixes, polish, docs, release prep, compatibility follow-through

### Critical rule

Do **not** bump `VERSION`, create a tag, or speak as if a release exists unless the task is explicitly doing release preparation.

### Release-prep sync group

Release prep is incomplete unless these stay synchronized:

- `VERSION`
- `CHANGELOG.md`
- tag `vX.Y.Z`
- release notes / release PR summary

## 6) CHANGELOG discipline

- `CHANGELOG.md` follows **Keep a Changelog**
- It is a release surface, not a noisy mirror of every commit
- User-visible changes, public IPC/config changes, and compatibility/migration changes must be representable there

If the repo is not currently in release-prep, at minimum ensure the PR/summary makes future changelog entry straightforward.

## 7) Governance quality bar

A governance change is incomplete if it:

- duplicates a rule that already has a canonical home
- changes wording without changing the actual operational contract
- leaves contradictory instructions in another governance surface
- references stale tool names, stale commands, or stale product naming
- explains process without making it actionable

## 8) Definition of done for governance/release work

The task is not done until you have:

- read the files you changed
- checked adjacent governance surfaces for contradictions
- updated collateral docs/rules/workflows as needed
- validated naming/tooling/command consistency
- verified whether version/changelog/tag/release surfaces should or should not move
