import 'dart:io';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:freon/app.dart';
import 'package:freon/data/database.dart';
import 'package:freon/data/repository.dart';
import 'package:freon/state/providers.dart';
import 'package:freon/services/meal_photo.dart';

class _PhotoPicker extends MealPhotoService {
  _PhotoPicker(this.photo);
  final MealPhoto photo;
  @override
  Future<List<String>> cameras() async => [];
  @override
  Future<MealPhoto?> pick() async => photo;
}

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
    await tester.tap(find.text('Log a meal'));
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

  testWidgets(
    'photo and caption reach the model and corrected estimates persist',
    (tester) async {
      final folder = await Directory.systemTemp.createTemp('freon-photo-flow-');
      final db = AppDatabase(
        NativeDatabase.createInBackground(File('${folder.path}/data.sqlite')),
      );
      final repo = FreonRepository(
        db,
        photoDirectory: Directory('${folder.path}/photos'),
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final input = await rootBundle.load('assets/images/lunch.jpg');
      final photo = await MealPhoto.prepare(input.buffer.asUint8List());
      var requests = 0;
      Map<String, dynamic>? capturedRequest;
      const caption =
          '24 cm plate. One cup of rice and 120 g chicken, cooked in 1 tsp oil.';
      server.listen((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        capturedRequest = body as Map<String, dynamic>;
        requests++;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {
                  'content': jsonEncode({
                    'food_visible': true,
                    'title': 'Chicken rice plate',
                    'foods': ['Chicken', 'Rice'],
                    'portion': 'One plate, all eaten',
                    'calories': 520,
                    'protein': 38,
                    'carbs': 55,
                    'fat': 15,
                    'assumptions': ['One teaspoon of oil'],
                    'uncertainty': 'medium',
                  }),
                },
              },
            ],
          }),
        );
        await request.response.close();
      });
      await repo.saveSettings(
        baseUrl: 'http://127.0.0.1:${server.port}',
        textModel: '',
        visionModel: 'fixture-vision',
        calorieTarget: 2200,
        waterTarget: 2000,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
            mealPhotoServiceProvider.overrideWithValue(_PhotoPicker(photo)),
          ],
          child: const FreonApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-nutrition')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Photo meal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('photo-caption')),
        caption,
      );
      await tester.tap(find.text('Estimate meal'));
      await tester.pumpAndSettle();
      expect(find.text('Chicken rice plate'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Calories (kcal)'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Calories (kcal)'),
        '480',
      );
      await tester.ensureVisible(find.text('Add to meal log'));
      await tester.tap(find.text('Add to meal log'));
      await tester.pumpAndSettle();
      final saved = (await repo.snapshot()).meals.single;
      expect(requests, 1);
      expect(capturedRequest!['model'], 'fixture-vision');
      final parts = capturedRequest!['messages'][1]['content'];
      expect(parts[0]['text'], contains(caption));
      expect(
        parts[1]['image_url']['url'],
        'data:image/png;base64,${base64Encode(photo.bytes)}',
      );
      expect(saved.notes, caption);
      expect(saved.calories, 480);
      expect(saved.source, 'corrected estimate');
      expect(jsonDecode(saved.estimateJson!)['calories'], 520);
      expect(await File(saved.imagePath!).readAsBytes(), photo.bytes);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await server.close(force: true);
      await db.close();
      final reopened = AppDatabase(
        NativeDatabase(File('${folder.path}/data.sqlite')),
      );
      expect(
        (await FreonRepository(reopened).snapshot()).meals.single.notes,
        caption,
      );
      await reopened.close();
      await folder.delete(recursive: true);
    },
  );
}
