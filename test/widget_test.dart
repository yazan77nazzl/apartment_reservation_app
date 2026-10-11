import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apartment_reservation_app/core/widgets/common.dart';

void main() {
  testWidgets('submission disables duplicate taps and restores button',
      (tester) async {
    final result = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BusyButton(
                label: 'Submit request',
                action: () async {
                  calls++;
                  await result.future;
                }))));
    await tester.tap(find.text('Submit request'));
    await tester.pump();
    await tester.tap(find.text('Submit request'));
    expect(calls, 1);
    result.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });
}
