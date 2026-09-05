# laundry_app_flutter

Flutter app for Idola One.

## Android releases

Cloud updates are available from version 1.0.3+4. For a user-facing release,
increase `version` in `pubspec.yaml`, run analysis/tests, then run
`../scripts/publish-android.ps1 -ReleaseNotes 'Ringkasan perubahan'` from PowerShell.
This builds and verifies APKs and publishes the cloud version feed last.
Running `flutter build apk` alone does not notify installed apps.
See [the update runbook](../docs/android-cloud-updates.md) for signing continuity,
publishing, verification, and rollback details.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
