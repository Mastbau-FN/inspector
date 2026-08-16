# [DOKU](https://mastbau-fn.github.io/inspector/doc/)

# Try [here](https://mastbau-fn.github.io/inspector/app/)

# inspector

inOffizielles Repo für die Mastbau FN GmBH Inspektions APP

## Getting Started

### Flutter

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

### Environment

create a .env file in the frontend dir containing a field `API_KEY=xxx`

### Build

- `flutter pub run build_runner build --delete-conflicting-outputs` to run code gen (probably optional)
- `flutter build` {apk, web, ..}

### Sign

All distributed Android builds must use the shared Inspector signing key. Do
not fall back to a generated debug keystore, because Android will reject later
updates signed by a different key.

For local builds, add a git-ignored `key.properties` file in the
`frontend/android` directory that points to a securely obtained copy of the
shared keystore:

```properties
storePassword=TODO
keyPassword=TODO
keyAlias=TODO
storeFile=/secure/path/to/inspector-signing.keystore
```

GitHub Actions receives the same keystore from the encrypted repository secret
`ANDROID_SIGNING_KEYSTORE_BASE64` and verifies its certificate fingerprint
before building.
