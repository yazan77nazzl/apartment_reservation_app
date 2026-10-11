import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

class AppConfig {
  static const emulator = bool.fromEnvironment('USE_EMULATORS');
  static const host =
      String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
  static const region = 'us-central1';
  static const projectId = 'apartment-reservation-ap-d7a35';
  static const useFunctions =
      String.fromEnvironment('BACKEND_MODE', defaultValue: 'spark') ==
          'functions';
  static const demoImages =
      String.fromEnvironment('IMAGE_STORAGE', defaultValue: 'demo') !=
          'firebase';
  static FirebaseOptions get options {
    if (emulator) {
      // Non-production Firebase Emulator Suite identifier, deliberately not credentials.
      return const FirebaseOptions(
          apiKey: 'demo-emulator-only',
          appId: '1:000000000000:android:0000000000000000',
          messagingSenderId: '000000000000',
          projectId: 'demo-apartment-reservation',
          storageBucket: 'demo-apartment-reservation.appspot.com');
    }
    const key = String.fromEnvironment('FIREBASE_API_KEY');
    const app = String.fromEnvironment('FIREBASE_APP_ID');
    const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const bucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    final options = [key, app, project, sender].every((x) => x.isNotEmpty)
        ? const FirebaseOptions(
            apiKey: key,
            appId: app,
            projectId: project,
            messagingSenderId: sender,
            storageBucket: bucket)
        : DefaultFirebaseOptions.currentPlatform;
    if (options.projectId != projectId) {
      throw StateError('Configuration must belong to $projectId.');
    }
    return options;
  }
}
