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
- Config style: client-safe values in `frontend/.env`, consumed through
  `--dart-define-from-file`

Keep server-only secrets such as DB passwords, SFTP credentials, and private API
tokens out of `frontend/.env`. They belong in the root/backend `.env` files and
must not be passed into Flutter web builds.

Enable the Email/Password and Google providers in Firebase Console:

Authentication > Sign-in method > Email/Password, Google

Copy the web app config values from Firebase Console:

Project settings > General > Your apps > Web app > SDK setup and configuration

Then create a local env file:

```bash
cp .env.example .env
```

Fill in the Firebase values in `.env`, then run or build with:

```bash
flutter run -d chrome --dart-define-from-file=.env
flutter build web --release --dart-define-from-file=.env
```

For Android and iOS, set the real package and bundle identifiers first, then run:

```bash
flutterfire configure --project=kwms-af60c --platforms=android,ios
```
