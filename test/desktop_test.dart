import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freon/app.dart';
import 'package:freon/data/database.dart';
import 'package:freon/data/repository.dart';
import 'package:freon/state/providers.dart';

class _FixedDay extends SelectedDay {
  @override
  DateTime build() => DateTime(2026, 9, 18);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final name in ['Outfit', 'HankenGrotesk']) {
      await (FontLoader(
        name == 'Outfit' ? name : 'Hanken Grotesk',
      )..addFont(rootBundle.load('assets/fonts/$name.ttf'))).load();
    }
  });

  for (final size in [
    const Size(1440, 900),
    const Size(1280, 800),
    const Size(800, 600),
  ]) {
    testWidgets('all desktop screens render at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory());
      final repo = FreonRepository(db);
      await tester.runAsync(() => repo.loadSampleDay(DateTime(2026, 9, 18)));
      final snapshot = await tester.runAsync(repo.snapshot);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            workspaceProvider.overrideWith((ref) => Stream.value(snapshot!)),
            selectedDayProvider.overrideWith(_FixedDay.new),
          ],
          child: const RepaintBoundary(
            key: ValueKey('screen'),
            child: FreonApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final destination in Destination.values) {
        await tester.tap(find.byKey(ValueKey('nav-${destination.name}')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$destination at $size');
        expect(find.text('Could not open your workspace'), findsNothing);
        if (size.width == 1440) {
          await expectLater(
            find.byKey(const ValueKey('screen')),
            matchesGoldenFile('goldens/${destination.name}.png'),
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    });
  }
}
