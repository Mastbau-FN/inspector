# Inspector staging and server deployment

User authorization: integrate the completed backend/frontend changes, push staging, and deploy the server.

- [x] Fetch origin/staging; merge reviewed backend 6cc970d41 and frontend 25aa8d4ea in an isolated integration worktree.
- [x] Keep release versions ahead of installed test build286: workflow run283 produces Android versionCode287 and matching release metadata; later runs increment normally.
- [x] Pin CI to tested Flutter3.38.4 so camera rendering matches the validated APK. Its Android API24 minimum is stated in release notes; code generation succeeded locally with this SDK.
- [x] Run combined backend/Flutter suites, analyzer, workflow validation and final integration review:53 backend/158 Flutter passed, analyzer clean; actionlint excludes only the pre-existing intentionally disabled PlayStore job warning.
- [x] Inspect and privately back up server source, Git state and service configuration. All67 backend files already match the target. Private backup: /home/administrator/inspector-deployments/20261031-staging-103633/. Latest Node24.22.2 image passes53 tests in a network-isolated read-only container before service changes.
- [ ] Push the verified merge to staging without force. Let release-info.md trigger the APK pipeline.
- [ ] Update server checkout to the exact staging commit; validate Compose, deploy development and production services, and verify Node24/HTTPS/API responses.
- [ ] Verify CI and published APK signature/version, reconcile the main local staging checkout without overwriting local files, and record commit, release URL and rollback location.

Constraints: no database migrations, no upload replay, no deletion/restoration of old inspection folders, no image-data cleanup, no secrets or private device artifacts in Git. Generated env.g.dart is restored after local code-generation verification and excluded from deployment changes.
