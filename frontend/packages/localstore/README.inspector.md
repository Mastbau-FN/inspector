# Inspector storage patch

This is the MIT-licensed localstore 1.4.0 source already used by Inspector, copied from the resolved package. Its public API and storage format are unchanged. No dependency versions were upgraded.

Two local fixes are required for offline downloads following the developer data reset:

- `DocumentRef.set` returns the underlying write future, so callers can await durable writes and receive filesystem errors.
- Native `_getFile` recreates a missing cached file and its parents after the application data directory was deleted in the same process.

Inspector also awaits its record writes and directory reset. Regression tests are in `frontend/test/offline_storage_reset_test.dart` and exercise the real filesystem, cached handles, inspection/defect photo lookups and write failures.

Upstream: https://github.com/chuyentt/localstore, version 1.4.0. Original copyright and license are retained in LICENSE and the source files.

The inherited deprecated dart:html import has a targeted analyzer annotation; its web implementation is otherwise unchanged.
