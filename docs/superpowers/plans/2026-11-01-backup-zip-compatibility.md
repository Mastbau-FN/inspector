# Backup ZIP Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure release-created backups are valid ZIPs in standard readers.
**Architecture:** Keep archive3.6.1 and the current backup flow. Encode generated JSON as UTF-8 bytes with byte lengths; store empty directory entries without compression.
**Tech Stack:** Flutter3.38.4, Dart3.10.3, archive3.6.1.
**Spec:** The release-device test reproduced invalid JSON lengths for non-ASCII text and zero-byte DEFLATE directory entries. Correct both while preserving every source file, backup chain and pending upload. No camera tests after the user's stop instruction.

## Global Constraints

No dependency upgrade, camera changes, database mutation, upload replay or backup restoration. Keep existing backups; verify file/queue hashes independently. Push staging, publish the next release and install it without clearing app data, as already authorized.

## Review Focus

Unicode metadata and empty directories receive direct regression tests; existing incremental backup/restore tests cover chain and payload compatibility. Review both generated JSON sites, existing ASCII payload behavior, data preservation and delta behavior.

### Task 1: Correct ZIP headers and verify the release

**Files:** Modify `frontend/lib/backend/incremental_backup.dart`, `frontend/test/incremental_backup_test.dart`, `release-info.md`.
**Interfaces:** Existing `createIncrementalBackup` interface and format remain unchanged.

- [x] Add tests through real backup creation: metadata uncompressed sizes equal actual UTF-8 bytes; directory compressed data can be decoded by Dart's native ZIP inflater.
- [x] Run the new tests and observe both failures before changing production code.
- [x] Set directory compress=false and construct both generated JSON ArchiveFile entries from UTF-8 bytes.
- [x] Run the entire Flutter suite and analyzer; independently check a generated ZIP using Python zipfile and unzip.
- [ ] Obtain a fresh whole-change review, commit and push staging with release notes for288.
- [ ] Verify CI, publish/install release288 and test backup/delta/import preview plus online/offline smoke checks on the phone. Do not resume camera tests.
- [ ] Update the server checkout to the new staging commit without restarting unchanged backend services; verify runtime and public HTTPS.
