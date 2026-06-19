# KWMS Frontend

Flutter frontend for the KWMS warehouse management system.

## Development

```bash
flutter analyze
flutter test
flutter build web --release
```

## Firebase Auth

Email/password and Google sign-in are wired through Firebase Auth.

- Firebase project: `kwms-af60c`
- Registered platform: Web
- Config style: `--dart-define` values consumed by `lib/firebase_options.dart`

Enable the Email/Password and Google providers in Firebase Console:

Authentication > Sign-in method > Email/Password, Google

Copy the web app config values from Firebase Console:

Project settings > General > Your apps > Web app > SDK setup and configuration

Then run the app with:

```bash
flutter run -d chrome \
  --dart-define=FIREBASE_WEB_API_KEY=... \
  --dart-define=FIREBASE_WEB_APP_ID=... \
  --dart-define=FIREBASE_WEB_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_WEB_PROJECT_ID=kwms-af60c \
  --dart-define=FIREBASE_WEB_AUTH_DOMAIN=kwms-af60c.firebaseapp.com \
  --dart-define=FIREBASE_WEB_STORAGE_BUCKET=kwms-af60c.firebasestorage.app
```

Use the same defines with `flutter build web --release`.

For Android and iOS, set the real package and bundle identifiers first, then run:

```bash
flutterfire configure --project=kwms-af60c --platforms=android,ios
```
