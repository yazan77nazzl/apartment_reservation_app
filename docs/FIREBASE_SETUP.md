# Firebase setup: free Spark plan

Configured project: `apartment-reservation-ap-d7a35`. Android package/iOS bundle: `ps.campushome.apartmentReservationApp` for iOS and `ps.campushome.apartment_reservation_app` for Android (check generated native runners/console for exact IDs).

The Android, iOS and web apps were registered through FlutterFire CLI. Real platform options were generated locally in `lib/firebase_options.dart`. These environment files are ignored by Git. Auth Email/Password and Firestore were enabled by the user. Spark Firestore rules/indexes were deployed successfully on 2026-10-11. No Storage or Functions deployment and no billing upgrade were performed.

For a fresh checkout run `scripts/prepare.ps1` and `scripts/configure-firebase.ps1`. Configuration calls `firebase login`, installs FlutterFire CLI and runs:

```powershell
flutterfire configure --project=apartment-reservation-ap-d7a35 --platforms=android,ios,web --out=lib/firebase_options.dart
firebase deploy --only firestore:rules,firestore:indexes --project apartment-reservation-ap-d7a35
flutter run -d chrome --dart-define=BACKEND_MODE=spark --dart-define=IMAGE_STORAGE=demo
```

Firebase SDK configuration values identify the app; never substitute a service-account key, private key or login token. The application checks the configured project ID at startup. It does not contact Storage in demo-image mode or call Functions in Spark mode.

## Verification and manual platform steps

1. Register a student and owner with your own email addresses in the live app. Profiles are written under their Auth UID; roles cannot subsequently change.
2. With the owner, add an apartment, select a bundled demo image and add a room. The student can browse it and submit a request. Approval and chat use rules-protected Firestore transactions/batches.
3. Reset-email messages and new-email verification use Firebase Authentication. Configure your desired email templates/authorized domains in the Firebase console. Add `localhost`/`127.0.0.1` as authorized domains if your web auth configuration requires them.
4. Indexes can take several minutes to finish provisioning. Queries may temporarily show an index error.
5. Real uploads are intentionally unavailable while Storage is unavailable. `ImageStorage` has `DemoImageStorage` and `FirebaseImageStorage` implementations. Once a bucket is available, deploy the Storage rules, configure the bucket with FlutterFire, and run with `--dart-define=IMAGE_STORAGE=firebase`. No screen rewrite is required.
6. For iOS, use macOS/Xcode, install CocoaPods, set signing/bundle identifier, and run `flutterfire configure` for that bundle. Enable push capabilities/APNs only if a trusted delivery backend is configured. iOS compilation was not possible on Windows.

## Spark boundaries

Spark mode supports Auth, profiles, listing/room create/edit, demo asset selection, search, dated requests, approve/reject/cancel, in-app notices, chat, read status, calendar and read-only payment history. Only a trusted backend may create payments or confirm a paid stay. Real checkout and automatic push delivery are not deployed. Local emulators supply the full explicitly fictional payment/confirmed-stay/renewal/review demonstration.

The Spark approval lock allows one unexpired approved request per room, regardless of period; it expires after 24 hours or is released by cancellation. This conservative lock prevents client-only double approval. The backend emulator supports multiple nonoverlapping dated reservations. It is not accurate to claim production payment or the full dated backend is available on Spark without another trusted runtime.

Spark review average and minimum room price are computed from actual accessible review/room streams. This costs reads and is suitable for a small graduation-project dataset. Production scale needs pagination/denormalization and a trusted aggregate writer. Clients cannot alter stored rating aggregates. Verified historical stays can be reviewed; Spark clients cannot fabricate those stays.

Official references: [FlutterFire setup](https://firebase.google.com/docs/flutter/setup), [Firebase pricing](https://firebase.google.com/pricing), [Local emulator suite](https://firebase.google.com/docs/emulator-suite).
