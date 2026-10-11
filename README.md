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

The live app uses Firebase Authentication and Firestore directly. Create your own student/owner accounts and listings; production data is never seeded. Demo image mode selects bundled fictional illustrations and never contacts Firebase Storage. See [Firebase setup](docs/FIREBASE_SETUP.md) for exact platform and migration instructions.

| Capability | Spark live project | Local Functions emulator |
|---|---|---|
| Auth, profiles, apartment/room create/edit, search, images from bundled assets | Yes | Yes |
| Requests, owner decisions, cancellation, in-app notices, chat/read status/calendar | Yes | Yes |
| Confirmed payments, paid reservation renewal and tenant review demonstration | Trusted historical stays only; no checkout | Explicitly fictional sandbox checkout |
| Booking conflict policy | One unexpired approval per room | Multiple nonoverlapping dated stays |
| Real photo uploads | Unavailable; demo assets instead | Optional emulated Storage adapter |
| Automatic push notifications | No delivery backend deployed | In-app notices; FCM delivery skipped |

No real payment provider or client-side real-payment success exists. Do not deploy Functions/Storage to the Spark project. No billing upgrade is required for the current setup.

## Architecture

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

Output is `build/app/outputs/flutter-apk/app-debug.apk`. An APK was **not** produced here: the build reported `No Android SDK found`. iOS builds require macOS/Xcode and signing. Android/iOS device integrations remain to be tested; web compilation is available. See [test results](docs/TEST_RESULTS.md) for measured results and remaining limitations.

## Limitations

This reconstructs the report's documented flows; it does not recover the original source. Real provider settlement/refunds, university identity verification, video uploads, parent monitoring and bank integration are not implemented. Spark approval deliberately uses a conservative single-room lock. Arabic UI/RTL is implemented; arbitrary Firebase/backend diagnostic messages may remain English. Catalog streams currently read all accessible rooms/reviews for live derived pricing/ratings; pagination is needed at scale. Source report and extracted personal material remain on the original computer and are excluded from the public repository.
