# Inspection download warnings implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task with test-driven development.

**Goal:** Complete inspection downloads with actionable persistent warnings for confirmed empty server photos.

**Architecture:** Classify explicitly empty successful HTTP image responses with a typed exception, collect warnings while preserving references, and store them locally with SharedPreferences. The inspection download button shows a green check with an optional warning count and a details dialog.

**Tech Stack:** Flutter 3.38.4, Dart, existing http and shared_preferences packages.

**Spec:** docs/superpowers/specs/2026-11-01-download-warnings-design.md

## Global constraints

- No dependency updates, database changes, source-photo deletion, pending-upload replay or app-data reset.
- Only confirmed server emptiness is nonblocking; network, truncated transfer, storage and document errors remain failures.
- Preserve image references and local warning persistence across navigation/restart.

## Review focus

- Truncated or failed responses must not be classified as permanent empty source photos.
- Ordinary image viewing must tolerate empty photos without throwing unhandled exceptions.
- Warnings survive page recreation but disappear after a successful repair and redownload.
- Multiple references to one empty file produce a useful, deduplicated warning list.
- An actual photo/document failure must still prevent marking the inspection offline.

### Task 1: Empty-server-photo warnings and completion UI

**Files:** backend/remote.dart, backend/api.dart, backend/failedRequestManager.dart, classes/exceptions.dart, classes/data/inspection_location.dart under frontend/lib; new backend/inspection_download_warnings.dart; frontend/test/inspection_download_test.dart and a new warning-widget test.

**Interfaces:** Add EmptyServerImageException(hash, filename). Keep cacheInspectionImagesForDownload returning Future<bool> and add an optional warning callback. Persist filename/hash/owner identity and label in a standalone local warning store keyed by inspectionDownloadKey.

- [x] Run the existing Flutter suite to establish the baseline.
- [x] Add failing parser and orchestration tests for explicitly zero-byte HTTP 200 images, continuing remaining images, preserved references, and rejecting truncated responses.
- [x] Add failing persistence/widget tests for warning details after page recreation and clearing resolved warnings.
- [x] Implement the typed condition, warning collection/store and green completion check with a warning-count details button.
- [x] Run focused tests, then the full Flutter suite and analyzer. Expected: all tests pass, no analyzer findings.
- [x] Obtain fresh review, fix important findings with regression coverage, and report local verification and remaining server access limitations.

### Task 2: Read-only source-file investigation

- [x] Reconnect over the user's VPN using an accepted SSH identity.
- [x] Inspect server/source file stats, filesystem mapping, available original copies and relevant logs.
- [x] Record confirmed provenance and distinguish it from hypotheses without modifying original data.

## Validation

### Follow-up: acknowledge reviewed warnings with Fertig

- [x] Reproduce the missing completion action with widget tests for persistence, repeat downloads, new files and a repaired file becoming empty again.
- [x] Add per-file local acknowledgements, notifications for live views and a Fertig dialog action that acknowledges only its displayed snapshot.
- [x] Run focused and full Flutter tests/analyzer, obtain fresh review, then build/install and verify Fertig plus persistence on the connected phone.

Baseline 161 tests. Final 171 tests passed; Flutter analyzer clean. Parser, warning flow, warning persistence, detailed locations and page-lifecycle tests were observed failing before their fixes. Fresh review found three issues (warning refresh after page changes, disposed snackbar context, non-200 empty responses); all three have regression coverage and were corrected.

Server inspection confirmed three unchanged zero-byte originals dating to February 25/26 2025, with no matching-name replacement copies in the image tree. Available logs cannot establish the original historical creation/upload failure. No server data was changed.

Signed local release-mode APK built with Flutter 3.38.4, versionCode 288, versionName 1.2.9-downloadhinweise; certificate matches the installed app. Installed in place after a fresh local backup; on-device download completed successfully with a green check, three file/location warnings, and the same warning details after a full process restart. Original screen timeout restored. The main workspace also passes all 171 tests and has a clean analyzer result. No shared branch or public release has been published.

Follow-up completed: Fertig acknowledges the displayed file warnings per inspection, leaves the green completion check and suppresses repeat warnings for those same files. Four new regression tests were RED before implementation; all 175 tests and the analyzer pass in both worktree and main workspace. Independent review found no important defects. Signed local APK 1.2.9-downloadhinweise-fertig (versionCode 288) installed in place; on-device Fertig action, disappearance of the badge, and persistence after process restart verified. Source files and pending uploads unchanged; original screen timeout restored.
