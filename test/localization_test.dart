import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apartment_reservation_app/core/l10n.dart';
import 'package:apartment_reservation_app/core/widgets/common.dart';

void main() {
  testWidgets('Arabic renders RTL and translated primary controls',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
            builder: (context) => Scaffold(
                body: BusyButton(
                    label: 'Submit request', action: () async {})))));
    await tester.pumpAndSettle();
    expect(find.text(arabic['Submit request']!), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(BusyButton))),
        TextDirection.rtl);
  });
}
