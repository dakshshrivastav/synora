import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:freon/app.dart';
import 'package:freon/data/database.dart';
import 'package:freon/data/repository.dart';
import 'package:freon/state/providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Linux meal, hydration, journal and persistence flow', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'freon-integration-',
    );
    final file = File('${directory.path}/freon.sqlite');
    final db = AppDatabase(NativeDatabase.createInBackground(file));
    final repo = FreonRepository(db);
    await repo.snapshot();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const FreonApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-nutrition')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log a meal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Meal title'),
      'Linux test lunch',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Calories (kcal)'),
      '420',
    );
    await tester.ensureVisible(find.text('Save meal'));
    await tester.tap(find.text('Save meal'));
    await tester.pumpAndSettle();
    expect((await repo.snapshot()).meals.single.title, 'Linux test lunch');

    await tester.ensureVisible(find.text('+ 250 ml'));
    await tester.tap(find.text('+ 250 ml'));
    await tester.pumpAndSettle();
    expect((await repo.snapshot()).water.single.milliliters, 250);

    await tester.tap(find.byKey(const ValueKey('nav-mindset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check in with Freon'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Sleep last night (hours)'),
      '7.5',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'A thought, a memory, a small win…'),
      'The Linux flow works.',
    );
    await tester.ensureVisible(find.text('Save check-in'));
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();
    expect(
      (await repo.snapshot()).checkIns.single.note,
      'The Linux flow works.',
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await db.close();
    final reopened = AppDatabase(NativeDatabase(file));
    final saved = await FreonRepository(reopened).snapshot();
    expect(saved.meals.single.calories, 420);
    expect(saved.checkIns.single.sleep, 7.5);
    expect(saved.water.single.milliliters, 250);
    await reopened.close();
    await directory.delete(recursive: true);
  });
}
