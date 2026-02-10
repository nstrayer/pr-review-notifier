# Migration Plan Review

Reviewed file: `MIGRATION_PLAN.md`  
Scope assumption: fresh app install (no in-place user data migration required)

## Summary

The migration plan is directionally solid and technically feasible. The main gaps are around persistence completeness and operational details (polling behavior, parity details), not core architecture.

## Findings

### 1) Medium: Persistence scope is incomplete for current behavior parity

Phase 2 calls out PR cache + dismissed IDs, but current behavior also depends on additional persisted keys:
- `notifiedPRs` (duplicate notification suppression)
- `lastQueryTime`
- `lastCheckHadErrors`
- `lastCheckErrors` (tray/menu error state details)
- `settingsPrompted` (first-run setup prompting behavior)

The migration table includes most but not all; `settingsPrompted` is currently missing.

References:
- `MIGRATION_PLAN.md:82`
- `MIGRATION_PLAN.md:195`
- `src/main/main.ts:575`
- `src/main/main.ts:598`
- `src/utils/github.ts:391`

Recommendation:
- Add an explicit per-key persistence matrix: keep/reset/recompute with rationale.

### 2) Medium: Polling implementation detail is underspecified and may regress behavior

The plan offers `Timer.publish` or async task-loop polling. Current implementation avoids overlap by scheduling the next check only after the current check completes. A naive timer can trigger overlapping API calls and noisy notifications.

References:
- `MIGRATION_PLAN.md:50`
- `MIGRATION_PLAN.md:97`
- `src/main/main.ts:520`

Recommendation:
- Require single-flight polling (one check at a time), cancellation on interval changes, and a defined retry/backoff strategy.

### 3) Low: IPC channel count is inconsistent in the plan

The summary states 10 IPC channels, but the listed table contains more channels than that.

References:
- `MIGRATION_PLAN.md:11`
- `MIGRATION_PLAN.md:177`

Recommendation:
- Correct the count to match the documented list so parity tracking is unambiguous.

### 4) Low: “Existing Swift project in App/” note is currently inaccurate for this repo

The plan mentions an `App/` directory that does not currently exist.

Reference:
- `MIGRATION_PLAN.md:159`

Recommendation:
- Replace with a neutral preflight step (“check for existing native project artifacts before scaffolding”).

## Notes on Fresh Install Scope

Because this migration targets fresh installs, a one-time user-data migration from Electron store is not required and is not a blocking issue.

## Verdict

Pass with revisions.  
Address the medium findings before implementation begins to reduce parity and reliability risk.
