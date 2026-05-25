# DevizPro Ultra - Developer Guide

Flutter app for Windows + Android with offline-first behavior and optional cloud sync.

## Tech stack

- Flutter / Dart
- Firebase (Auth, Firestore, Storage, Messaging, Functions)
- SharedPreferences for local persistence and offline sync queue

## Project structure

- `lib/app/` app bootstrap and shell
- `lib/core/` shared models, repositories, cloud sync runtime, PDF/document services
- `lib/features/` feature modules (offers, jobs, clients, HR, tools, notifications)
- `test/` unit tests

## Run locally

```bash
flutter pub get
flutter run -d windows
```

Android:

```bash
flutter run -d android
```

## Quality checks

```bash
flutter analyze
flutter test
```

## Build artifacts

Windows release build:

```bash
flutter build windows
```

Output:
- `build/windows/x64/runner/Release/devizpro_ultra.exe`

Android debug build:

```bash
flutter build apk --debug
```

Output:
- `build/app/outputs/flutter-apk/app-debug.apk`

Android release build:

```bash
flutter build apk --release
```

## Offline sync behavior

- local changes are queued in `LocalCloudSyncRepository`
- `OfflineSyncRuntime` retries pending operations periodically
- failed operations are deferred with exponential backoff
- queue entries keep retry metadata (`retryCount`, `lastError`, `nextAttemptAt`)

## Configuration notes

- Firebase bootstrap is handled by `lib/core/cloud/firebase_bootstrap.dart`
- app mode and cloud feature flags are in `lib/core/app_config.dart`
- keep keys/secrets outside source files when possible (build-time env vars)
