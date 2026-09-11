# Review Fixes Implementation Plan

**Goal:** Repair the six functional findings from the project review without changing the startup-only biometric policy.

**Architecture:** Keep CI-generated native projects. Normalize native motion to a physical gravity vector (+X right, +Y toward the device top, +Z out of screen, m/s²). Extract deterministic maze physics and an active-play clock; retain the existing UI. Recover Android camera results into an application-owned store before authentication, but reveal them only on the authenticated camera route.

**Tech Stack:** Flutter 3.44.9, Dart, Kotlin sensors, Swift Core Motion, Python unittest.

## Steps
1. Migrate iOS registration to FlutterImplicitEngineDelegate; normalize Android gravity and propagate sensor failures on both platforms.
2. Add maze physics tests for wall segments/corners, extract collision handling with bounded substeps, and integrate an active-play clock. Pause on settings and background transitions.
3. Add explicit waiting/error/stale states to the level page and tests using injectable sensor streams.
4. Add an injectable camera recovery store; initiate recovery at app startup, preserve recovered results until consumed after login, and test errors/cancellation/recovery.
5. Strengthen preparation and validation scripts with generated-file checks, idempotence tests, and negative fixtures.
6. Resolve and commit the dependency lockfile, enforce it in CI, correct README, and run Python validation plus Flutter analyze/tests using an isolated temporary SDK if available.

## Verification
- `python -m unittest discover -s tool/tests -v`
- `python tool/validate_templates.py`
- `flutter pub get --enforce-lockfile`
- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze --no-pub`
- `flutter test --no-pub`
- Android/iOS compilation and device posture/camera lifecycle checks remain in CI/device validation.

No automatic commit or push. No new framework dependency. No change to background reauthentication policy.
