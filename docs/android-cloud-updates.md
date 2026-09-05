# Android cloud updates

Bootstrap release: 1.0.3+4. Phones with 1.0.2 or earlier must install the bootstrap APK once, over their existing installation. Those old binaries cannot check the release feed.

The app checks the public `app-releases/android/latest.json` Supabase Storage object at startup, on resume (one-minute throttle), every five minutes while foregrounded, and manually under **Lainnya > Pembaruan aplikasi**. It does not wake a closed application or send background push notifications. Network failures do not block laundry operations. A visible banner opens release notes and an explicit Update button.

The Update button requests Android's per-app install permission when needed, downloads the matching ABI APK into private cache, verifies size, SHA-256, application ID, version code, and the installed signing certificate, then opens Android's confirmation screen. Canceling installation preserves the update offer; retry reuses a verified download. No uninstall, operational data reset, or automatic installation is performed.

## Publish the next release

1. Update code, run `flutter analyze` and `flutter test`.
2. Increase both the version and numeric build in `laundry_app_flutter/pubspec.yaml`.
3. From the repository run:

```powershell
./scripts/publish-android.ps1 -ReleaseNotes 'Describe the changes for staff here.'
```

The script uses the linked Supabase project and authenticated CLI. It builds ABI-specific APKs plus the universal bootstrap export, checks package/version/signature, uploads immutable content-addressed APKs, downloads each back to verify hashes, and publishes the manifest **last**. `-SkipBuild` is only for already-built and verified artifacts; the script still validates their signatures and versions. APKs are below the bucket's 50 MiB limit. Upload/download storage traffic consumes the project's existing quota.

The publisher builds each target with `--target-platform` rather than `--split-per-abi`, which adds ABI-specific versionCode offsets. All artifacts use the exact numeric build from pubspec. This allows universal-to-ABI and ABI-to-universal updates without Android downgrade errors. The publisher rejects mismatched build codes before publishing. Verified artifacts are kept in `laundry_app_flutter/build/release-artifacts`.

The public bucket contains only APKs and version information, never contact/order data. It allows public downloads but no app-user upload/update/delete policies. Only server-side deployment credentials can publish. Service-role credentials must never enter Dart defines, source, APKs, or logs.

## Signing continuity

Existing sideloaded APKs use this computer's Android debug keystore. The release script pins its certificate SHA-256 `ad35e77c429a49be539baf341ee18645195058abf65bbb9561e40c2b43da2794` to avoid publishing an incompatible APK. Preserve and securely back up that keystore outside Git. Do not regenerate or switch keys without a deliberate migration plan. A future Play Store rollout requires a separate signing/distribution review.

## Rollback

Do not publish a lower build as an update: Android and the app reject downgrades. To withdraw a problematic offer, restore the previous `latest.json` using deployment credentials; users who already installed it need a corrected APK with a higher build. Retain immutable APKs referenced by the restored manifest. Do not publish a fictitious higher version just to test notifications on production phones.
