# Migration Plan Review

Reviewed file: `MIGRATION_PLAN.md`  
Scope assumption: fresh app install (no in-place user data migration required)

## Summary

The migration plan is directionally solid and technically feasible. All previously identified gaps around persistence completeness, polling behavior, IPC channel counts, and directory references have been resolved in the current version of the plan. A rate limiting strategy has been added to Phase 3.

## Findings

### 1) ~~Medium~~ Resolved: Persistence scope is complete

Phase 2 (line 82) explicitly covers PR cache, dismissed IDs, notified PR IDs, last query time, and error state. The Store Schema table (lines 196-214) lists all persisted keys including `settingsPrompted` (line 214), `notifiedPRs`, `lastQueryTime`, `lastCheckHadErrors`, and `lastCheckErrors`.

This finding was based on an earlier draft and has been fully addressed in the current plan.

Recommendation (optional):
- Consider adding a per-key persistence matrix (keep/reset/recompute) for additional implementation clarity, but this is not a gap.

### 2) ~~Medium~~ Resolved: Polling implementation is specified

Phase 4 (lines 97-101) already specifies:
- Single-flight polling via an async `Task` loop that awaits each check before sleeping
- Cancel and restart the polling task when the check interval changes
- Manual "Check Now" skips if a check is already in flight

This matches the current Electron behavior and addresses the concern about overlapping API calls.

Note: A retry/backoff strategy for rate-limited or failed requests is not yet specified -- see the rate limiting note added to Phase 3 of the plan.

### 3) ~~Low~~ Resolved: IPC channel count is consistent

The summary (line 11) states "13 IPC channels" and the table (lines 180-194) lists exactly 13 channels. These are consistent.

This finding was based on an earlier draft where the count may have been different.

### 4) ~~Low~~ Resolved: Preflight step uses neutral phrasing

The plan (line 160) already uses the recommended neutral phrasing: "Check for any existing Swift project artifacts in the repo before scaffolding to avoid conflicts or duplication." There is no reference to an `App/` directory.

This finding was based on an earlier draft and has been addressed.

## Notes on Fresh Install Scope

Because this migration targets fresh installs, a one-time user-data migration from Electron store is not required and is not a blocking issue.

## Verdict

Pass.
All previously identified findings have been addressed in the current plan. The plan is ready for implementation.
