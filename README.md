# Attendance App (Flutter)

Employee app for the attendance & pay-monitoring SaaS: one-time activation with an employer-issued code, device-bound sessions (Android Keystore key), PIN/biometric unlock, geofenced punch with selfie + on-device liveness, monthly calendar, leave and earnings.

Backend: [Attendance_Backend](https://github.com/mdfakih/Attendance_Backend).

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000   # Android emulator → host machine
```

Android first; iOS folder is kept compiling for later.

## Environments and Firebase (not in git)

- **API per environment:** copy `env/prod.example.json` to `env/prod.json`, set `API_BASE_URL`, then
  `flutter run --dart-define-from-file=env/prod.json` (or `flutter build apk --dart-define-from-file=env/prod.json`).
  `env/*.json` is ignored; only the `*.example.json` templates are committed.
- **Push (Firebase):** the Android build applies the Google Services plugin, so it needs
  `android/app/google-services.json` (Firebase console → project settings → Android app). iOS uses
  `ios/Runner/GoogleService-Info.plist`. Both are ignored; get them from the Firebase console, never commit them.
