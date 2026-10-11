import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'services/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: AppConfig.options);
    if (AppConfig.emulator) {
      await FirebaseAuth.instance.useAuthEmulator(AppConfig.host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(AppConfig.host, 8080);
      if (AppConfig.useFunctions) {
        FirebaseFunctions.instanceFor(region: AppConfig.region)
            .useFunctionsEmulator(AppConfig.host, 5001);
      }
      if (AppConfig.imageStorage == 'firebase') {
        await FirebaseStorage.instance.useStorageEmulator(AppConfig.host, 9199);
      }
    }
    runApp(const ProviderScope(child: HousingApp()));
  } catch (error) {
    runApp(MaterialApp(
        theme: appTheme(),
        home: Scaffold(
            body: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                        'Setup required\n\n$error\n\nRead README.md for Firebase and emulator setup.'))))));
  }
}

class HousingApp extends ConsumerWidget {
  const HousingApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
      title: 'Campus Home',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      locale: Locale(ref.watch(localeProvider)),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider));
}
