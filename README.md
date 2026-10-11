# Campus Home — Apartment Reservation

Functional Flutter reconstruction of **Mobile Application for Reservation of Apartments**, a Palestinian university housing graduation project. The original report was analyzed before implementation; the requirements and screenshot mapping are in [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md).

## Run on this computer

The SDK and Firebase CLI installed for this session are in `.tools/` and are deliberately excluded from Git. The current demo runs on **http://127.0.0.1:7357** while its local services are running.

Fictional local accounts:

| Role | Email | Password |
|---|---|---|
| Student | demo-student@example.test | DemoOnly!2026 |
| Owner | demo-owner@example.test | DemoOnly!2026 |

These accounts exist only in the emulator. They do not sign in to the real project.

For a fresh checkout install Flutter stable (3.35+), Node 22+, Java 21, Firebase CLI and Chrome. Open PowerShell in the repository:

```powershell
.\scripts\prepare.ps1
npm install --prefix functions
```

Use three terminals for the local demo:

```powershell
# Terminal 1: leave running
.\scripts\start-emulators.ps1
```

```powershell
# Terminal 2: install fictional sample data once
.\scripts\seed-demo.ps1
```

```powershell
# Terminal 3: launch Flutter in Chrome
.\scripts\run-demo.ps1
```

To serve a compiled demo independently of Chrome's debugger:

```powershell
flutter build web --no-web-resources-cdn --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=127.0.0.1 --dart-define=BACKEND_MODE=functions
node scripts/serve-preview.cjs --port 7357
```

## Use the real Firebase project without upgrading billing

Project: **apartment-reservation-ap-d7a35**. Android/iOS/web registration is complete on this computer; the real generated configuration is local and ignored by Git. Spark rules and indexes have been deployed. After a fresh checkout:

```powershell
.\scripts\configure-firebase.ps1 -Platforms android,ios,web
.\scripts\run-live.ps1
```

The live app uses Firebase Authentication and Firestore directly, with Supabase for apartment/profile photos. Complete [Supabase image setup](docs/SUPABASE_IMAGES.md) and fill the ignored local `config/image-storage.json` before uploading. Create your own student/owner accounts and listings; production data is never seeded. Optional demo image mode selects bundled fictional illustrations. Firebase Storage is inactive in Supabase mode. See [Firebase setup](docs/FIREBASE_SETUP.md) for platform instructions.

| Capability | Spark live project | Local Functions emulator |
|---|---|---|
| Auth, profiles, apartment/room create/edit, search, images from bundled assets | Yes | Yes |
| Requests, owner decisions, cancellation, in-app notices, chat/read status/calendar | Yes | Yes |
| Confirmed payments, paid reservation renewal and tenant review demonstration | Trusted historical stays only; no checkout | Explicitly fictional sandbox checkout |
| Booking conflict policy | One unexpired approval per room | Multiple nonoverlapping dated stays |
| Real photo uploads | Supabase after its auth/bucket setup | Bundled demo assets or optional emulated Firebase Storage |
| Automatic push notifications | No delivery backend deployed | In-app notices; FCM delivery skipped |

No real payment provider or client-side real-payment success exists. Do not deploy Functions/Storage to the Spark project. No billing upgrade is required for the current setup.

## Architecture

The supplied logo is bundled as `assets/images/logo.png` and appears in the login/header and Android/iOS/web icons. After replacing the image, run `scripts/apply-logo.ps1` and rebuild/restart Flutter to update all icons.

For the locally installed Android SDK and CampusHome virtual device, run `./scripts/run-android.ps1` to open the emulator and connect to the real Spark Firebase project. Accounts and application records are stored in `apartment-reservation-ap-d7a35`. For optional local testing, use `./scripts/run-android.ps1 -Mode demo`, keep Firebase emulators running in another terminal (`./scripts/start-emulators.ps1`), and run `./scripts/seed-demo.ps1` once. Demo payment confirmation requires the local backend.

Use `demo-student@example.test` on Android and `demo-owner@example.test` in the web preview to check both sides of a request. Both use `DemoOnly!2026`. Request an available room as the student, approve it as the owner, return to the student to make a sandbox payment, then check the reservation, owner calendar, messages, and renewal. A review requires a confirmed stay that has already started. These accounts and payments are local demo data.

`lib/core/` contains configuration, localization, theme, guards and async/form widgets. Feature screens cover auth, listings/rooms, reservations/payments, owner dashboard/calendar, chat, reviews, profiles and notices. Riverpod owns session/repository/locale state; GoRouter applies role guards. Firestore streams render live data.

`HousingRepository` selects `SparkActions` by default or callable Functions when `BACKEND_MODE=functions`. `ImageStorage` selects bundled `DemoImageStorage` by default or `FirebaseImageStorage` when `IMAGE_STORAGE=firebase`. UI consumers keep the same interface. Asset paths and future download URLs are both renderable.

`functions/src/` contains trusted backend validation, reservation transactions, sandbox payment and review aggregation. It runs locally for complete demonstrations. [Schema/security documentation](docs/SCHEMA.md) describes access boundaries; [assumptions](ASSUMPTIONS.md) documents reconstruction choices and Spark limitations.

## Verify and build

```powershell
dart format lib test
flutter analyze
flutter test
node --test functions/test/domain.test.js
# With local emulators running:
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
node --test functions/test/emulator.test.js
node --test functions/test/spark.test.js
```

Each emulator test suite installs its appropriate rules into the local emulator. Run the suites sequentially. They do not contact production. Backend tests cover actual callable operations/concurrent approval, sandbox decline/retry/idempotency, chat/review permissions and Storage permissions; Spark tests cover direct client writes and denial of fabricated payments. Flutter tests cover auth validation, role routing, Arabic RTL and duplicate submission prevention.

For Android install Android Studio/SDK, accept licenses, configure your device, then:

```powershell
flutter doctor
flutter doctor --android-licenses
flutter build apk --debug
```

Output is `build/app/outputs/flutter-apk/app-debug.apk`. Both demo and live Spark debug builds were installed and launched on the local CampusHome Android emulator; the currently installed APK connects to the real Firebase project with `USE_EMULATORS=false` and `BACKEND_MODE=spark`. iOS builds require macOS/Xcode and signing. Full Android UI flows and native device integrations remain manual checks. See [test results](docs/TEST_RESULTS.md) for measured results and remaining limitations.

## Limitations

This reconstructs the report's documented flows; it does not recover the original source. Real provider settlement/refunds, university identity verification, video uploads, parent monitoring and bank integration are not implemented. Spark approval deliberately uses a conservative single-room lock. Arabic UI/RTL is implemented; arbitrary Firebase/backend diagnostic messages may remain English. Catalog streams currently read all accessible rooms/reviews for live derived pricing/ratings; pagination is needed at scale. Source report and extracted personal material remain on the original computer and are excluded from the public repository.
