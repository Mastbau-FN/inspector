# Offline photo storage after developer reset

The user cleared local data through developer settings, downloaded again, then disabled Internet. The gallery was empty despite cached records. Device logs show unhandled localstore writes to missing KO root files; the fresh backup confirms root records are absent while pic1.jpg exists at 903116 bytes. localstore 1.4.0 caches File handles without recreating deleted parent folders, and DocumentRef.set returns before its filesystem write finishes. Inspector.storeData also discards that future.

Requirements: preserve current user data and the earlier warning/acknowledgement feature. Re-downloaded metadata, image mappings and photo bytes must be durable before successful completion. Validate inspection and actual nonempty defect photos without Internet, also after restarting. The known three empty server files remain data warnings; do not manufacture replacement images or replay uploads.

- [x] Add real filesystem regression tests for reset in the same process, propagated write errors and awaited deletion; observe failures against the installed dependency.
- [x] Vendor the unchanged MIT-licensed localstore 1.4.0 sources with narrowly documented fixes for awaited writes and cached File recreation. Await Inspector record writes and reset deletion, without changing storage paths or formats.
- [x] Run focused tests, full suite and analyzer: 178 tests pass and analysis is clean in both checkouts. Self-review found no important issues. The requested independent reviewer could not start because its service reported exhausted credits; no independent review result is claimed.
- [x] Build and install using the existing signing key. Temporarily reconnect Wi-Fi only for re-downloading assigned test inspections, then restore the original offline state and verify actual image display/zoom at inspection and defect level after restart.

## Device result

Installed `1.2.9-offlinefotos-fix` over the existing application without clearing user data. Both inspections 6006386 and 6006387 completed their downloads. The first attempt stalled during the last image transfer; restarting the app and retrying completed it. The three confirmed zero-byte files in 6006387 are still reported as source-data warnings, and the existing acknowledgement remains effective.

Disabled Wi-Fi, confirmed `Active default network: none`, force-stopped and relaunched the app while still offline. The inspection gallery for 6006387 shows `pic1.jpg` and opens its full image. In 6006386, Rettungsgerät → Typ → first defect shows all seven photos; `05_03_2025_12_51_23.jpg` opens at full size. The second defect also opens `05_03_2025_13_03_39.jpg` at full size. No PathNotFoundException, FileSystemException or unhandled exception was logged after the offline restart.

Wi-Fi, mobile data, airplane mode and screen timeout have been restored to their recorded original settings. The populated phone was not reset again; the same-process reset regression is covered by the real-filesystem tests. Private evidence is in `test-results/2026-11-01-offline-photos/device-verification.json`, the adjacent screenshots and logs. Changes are present in the main checkout and the preserved worktree; nothing has been committed or pushed.

The VS Code Gradle import is pinned to the installed JDK 21 using `java.import.gradle.java.home`. Gradle 8.7 `help --no-daemon` succeeds with that JDK; the Java language server keeps its own runtime. A live IDE reimport has not been verified.
