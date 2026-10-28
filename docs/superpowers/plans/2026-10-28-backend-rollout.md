# Inspector Backend Rollout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Safely deploy the October backend improvements and verify error capture plus current app/backend access.

**Architecture:** Keep Express, pg, existing SQL, existing backup APIs and Node 24. Stage a verified backend package separately and update development before production with rollback retained.

**Tech Stack:** Bash, Node.js 24, Express, PostgreSQL, Docker Compose, Flutter/Dart.

**Spec:** docs/superpowers/specs/2026-10-28-backend-rollout-design.md

## Global Constraints

- Preserve Node 24.22.1 and keep application changes limited to the already prepared backend package and necessary fixes.
- Version-2 categories and a new backup service are outside scope.
- Do not fabricate missing inspection directories or remove database records to make checks pass.
- Older backup work and ticket cleanup are outside the user's corrected scope; use the connected device for current backend checks.

## Review Focus

- Failed checkout/pull/config validation must not stop or recreate either service.
- Missing production folders must not turn ordinary inspection listing into an unassessed outage.
- Assigned inspection authorization must cover document locations actually returned at every tree level.
- Symlink/traversal and disconnected streams must remain bounded and close resources.
- Failed-request recovery and content deduplication must preserve the existing queue and skip synchronized data.

### Task 1: Harden restart failure handling

**Files:** Modify backend/restart.sh; create backend/restart.test.js.
**Interfaces:** Consumes existing git/docker-compose/sysctl/docker commands; produces a restart script that fails before service mutation when a prerequisite fails.
- [ ] Write executable tests for failed checkout, failed pull, invalid Compose config, and successful ordering/correct working directory.
- [ ] Run node --test restart.test.js. Expected: failure against the old script because pull failure is ignored.
- [ ] Add Bash strict failure handling, script-relative working directory, fast-forward-only pull, and pre-restart Compose validation; retain the existing service/log commands.
- [ ] Run npm test. Expected: all backend tests pass. Commit this task with the prepared backend package on the isolated branch.

### Task 2: Audit real storage and stage the candidate

**Files:** Existing backend/api.js, db/queries.js, images/filesystem.js, images/hash.js and tests; deployment evidence outside the repository.
**Interfaces:** Consumes the authenticated server configuration and read-only inspection queries; produces a storage report, a tested candidate, and rollback artifacts.
- [ ] Audit actual assigned inspections and their mapped folders without exposing credentials or altering business data.
- [ ] Reproduce any discovered compatibility bug in a failing test before a minimal fix.
- [ ] Verify npm installation and all backend tests under the exact deployed Node 24 image. Expected: no credential-dependent tests or failures.
- [ ] Read-only smoke test database and representative real document paths. Expected: valid assigned content works and unavailable storage is reported explicitly.

### Task 3: Verify error logging and app access

**Files:** backend/api.logging.test.js, existing frontend tests and source; evidence outside the application code.
**Interfaces:** Consumes existing request/database logging and current API handlers; produces correlated error/slow-query tests and device evidence.
- [ ] Run the whole Flutter test suite and flutter analyze. Expected: passing tests and no analyzer errors.
- [ ] Verify existing logging via real HTTP requests: query errors, unavailable storage, slow queries and correlation IDs; assert credentials and request text are absent.
- [ ] Verify actual test-inspection documents/images and offline access on the connected device after rollout; use test records for any writes.
- [ ] Retain the installed app and its data; no older backup redesign or unrelated ticket changes.

### Task 4: Review and roll out

**Files:** Verified backend package; server backups and deployment records.
**Interfaces:** Consumes the candidate and audit; produces deployed services or a concrete storage blocker with production preserved.
- [ ] Obtain one fresh-context code review; fix Important/Critical findings with RED→GREEN regression tests.
- [ ] Back up code/configuration and verify package digests before replacement.
- [ ] Roll out development, verify HTTPS/auth/database and representative downloads, then roll out production only if the assessed storage behavior is acceptable.
- [ ] Verify live Node version, HTTPS, auth, database, logs and file hashes; retain rollback and report any remaining hardware/data dependency.
