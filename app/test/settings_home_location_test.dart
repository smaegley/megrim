import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/home_location.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/settings_screen.dart';

/// Guards the stateful conversion behind backlog #7 (the home-location label used to go stale until
/// the screen was reopened). Here we verify the tile reads the current location from the repo; the
/// refresh-after-change is confirmed on-device (the change flow needs the geocoder picker).
void main() {
  testWidgets('Settings shows the current home-location label', (tester) async {
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final repo = MegrimRepository(db: db);
    await repo.setHomeLocation(
        const HomeLocation(lat: 40.7, lon: -74.0, label: 'New York'));

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(repo: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Home location'), findsOneWidget);
    expect(find.text('New York'), findsOneWidget);

    await db.close();
  });
}
