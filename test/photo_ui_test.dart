import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freon/data/meal_estimate.dart';
import 'package:freon/services/meal_photo.dart';
import 'package:freon/state/meal_analysis.dart';
import 'package:freon/ui/photo_meal.dart';
import 'package:freon/ui/theme.dart';

import 'meal_estimate_test.dart' show validEstimate;

class _Picker extends MealPhotoService {
  _Picker(this.photo);
  final MealPhoto photo;
  @override
  Future<MealPhoto?> pick() async => photo;
  @override
  Future<List<String>> cameras() async => [];
}

class _Analysis extends MealAnalysisController {
  @override
  Future<void> analyze(MealPhoto photo, String caption) async {
    state = MealAnalysisState(
      estimate: MealEstimate.fromJson(validEstimate),
      model: 'Fixture vision model',
      caption: caption,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MealPhoto photo;
  setUpAll(() async {
    for (final font in [
      ('Outfit', 'assets/fonts/Outfit.ttf'),
      ('Hanken Grotesk', 'assets/fonts/HankenGrotesk.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
    photo = await MealPhoto.prepare(
      (await rootBundle.load('assets/images/lunch.jpg')).buffer.asUint8List(),
    );
  });

  for (final size in [const Size(1440, 900), const Size(800, 600)]) {
    testWidgets(
      'photo dialog is usable and invalidates estimates when caption changes at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mealPhotoServiceProvider.overrideWithValue(_Picker(photo)),
              mealAnalysisProvider.overrideWith(_Analysis.new),
            ],
            child: RepaintBoundary(
              key: const ValueKey('photo-screen'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: freonTheme(),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: FilledButton(
                        onPressed: () => showPhotoMealEditor(context),
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose photo'));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(photo.bytes),
            tester.element(find.byType(PhotoMealEditor)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        await tester.ensureVisible(find.byKey(const ValueKey('photo-caption')));
        await tester.enterText(
          find.byKey(const ValueKey('photo-caption')),
          '24 cm plate; one cup rice, chicken and one teaspoon of oil.',
        );
        await tester.ensureVisible(find.text('Estimate meal'));
        await tester.tap(find.text('Estimate meal'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Add to meal log').hitTestable(), findsOneWidget);
        if (size.width == 1440) {
          await expectLater(
            find.byKey(const ValueKey('photo-screen')),
            matchesGoldenFile('goldens/photo_meal.png'),
          );
        }
        await tester.ensureVisible(find.byKey(const ValueKey('photo-caption')));
        await tester.enterText(
          find.byKey(const ValueKey('photo-caption')),
          'Actually, I ate only half.',
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Add to meal log'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('a picture of your plate'), findsNothing);
      },
    );
  }
}
