# Attendance App (Flutter)

Employee app for the attendance & pay-monitoring SaaS: one-time activation with an employer-issued code, device-bound sessions (Android Keystore key), PIN/biometric unlock, geofenced punch with selfie + on-device liveness, monthly calendar, leave and earnings.

Backend: [Attendance_Backend](https://github.com/mdfakih/Attendance_Backend).

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000   # Android emulator → host machine
```

Android first; iOS folder is kept compiling for later.
