Coding standards

- Keep Dart strict-analysis-clean; explicitly `await` or `unawaited` every future.
- Do not add a Flutter plugin that applies the old Kotlin Gradle Plugin unless the project has been revalidated against that dependency.
- Modify native bridges only in `tool/templates`; `tool/prepare_platforms.py` copies them into CI-generated Android/iOS projects.
- Android motion channels use `EventChannel`; iOS motion channels use `FlutterEventChannel`.
- Keep Android biometric activities based on `FlutterFragmentActivity` for `local_auth`.
- Keep the release APK and unsigned iOS build paths aligned with the CI artifact names.
