import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freon/data/database.dart';
import 'package:freon/data/repository.dart';
import 'package:freon/data/workspace.dart';
import 'package:freon/services/meal_photo.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'meal_estimate_test.dart' show validEstimate;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final day = DateTime(2026, 9, 18);
  const meal = MealDraft(
    title: 'Rice bowl',
    kind: 'Lunch',
    calories: 450,
    protein: 20,
    carbs: 60,
    fat: 12,
  );
  late AppDatabase db;
  late FreonRepository repo;
  var closed = false;
  setUp(() {
    closed = false;
    db = AppDatabase(NativeDatabase.memory());
    repo = FreonRepository(db);
  });
  tearDown(() async {
    if (!closed) await db.close();
  });

  test(
    'creates defaults, computes totals, and invalidates stale summaries',
    () async {
      expect((await repo.snapshot()).settings.baseUrl, 'http://127.0.0.1:1234');
      await repo.saveMeal(day, meal);
      await repo.addWater(day);
      await repo.saveSummary(day, 'Saved reflection', 'test', false);
      expect((await repo.snapshot()).summaryFor(day), isNotNull);
      await repo.saveCheckIn(
        day,
        mood: 4,
        stress: 20,
        energy: 80,
        social: 50,
        sleep: 7.5,
        note: 'A quiet morning.',
      );
      final data = await repo.snapshot();
      expect(data.caloriesFor(day), 450);
      expect(data.waterFor(day), 250);
      expect(data.completionFor(day), 100);
      expect(data.summaryFor(day), isNull);
      expect(data.caloriesFor(DateTime(2026, 9, 17)), 0);
      await repo.undoWater(day);
      await repo.undoWater(day);
      expect((await repo.snapshot()).waterFor(day), 0);
    },
  );

  test('repository stream changes after a committed write', () async {
    final first = Completer<void>();
    final changed = Completer<Workspace>();
    final sub = repo.watch().listen((data) {
      if (!first.isCompleted) first.complete();
      if (data.meals.isNotEmpty && !changed.isCompleted) changed.complete(data);
    });
    await first.future;
    await repo.saveMeal(day, meal);
    expect(
      (await changed.future.timeout(const Duration(seconds: 3)))
          .caloriesFor(day),
      450,
    );
    await sub.cancel();
  });

  test(
    'sample seeding is idempotent and removal preserves personal records',
    () async {
      await repo.loadSampleDay(day);
      await repo.loadSampleDay(day);
      await repo.saveMeal(day, meal);
      await repo.addWater(day);
      await repo.saveCheckIn(
        day,
        mood: 2,
        stress: 40,
        energy: 60,
        social: 50,
        sleep: 6,
        note: 'My own note',
      );
      expect((await repo.snapshot()).latestFor(day)!.note, 'My own note');
      expect((await repo.snapshot()).meals.length, 4);
      await repo.undoWater(day);
      expect((await repo.snapshot()).waterFor(day), 1500);
      await repo.clearSamples();
      final data = await repo.snapshot();
      expect(data.meals.single.title, 'Rice bowl');
      expect(data.checkIns.single.note, 'My own note');
      expect(data.water, isEmpty);
      expect(data.sampleFor(day), false);
    },
  );

  test(
    'rejects nonfinite inputs and invalid endpoints without writes',
    () async {
      await expectLater(
        repo.saveMeal(
          day,
          const MealDraft(
            title: 'Bad',
            kind: 'Lunch',
            calories: double.nan,
            protein: 0,
            carbs: 0,
            fat: 0,
          ),
        ),
        throwsFormatException,
      );
      await expectLater(
        repo.saveSettings(
          baseUrl: 'file:///etc/passwd',
          textModel: '',
          visionModel: '',
          calorieTarget: 2200,
          waterTarget: 2000,
        ),
        throwsFormatException,
      );
      expect((await repo.snapshot()).meals, isEmpty);
    },
  );

  test('message order and retry history survive same-second writes', () async {
    await repo.saveMessage('user', 'First');
    await repo.saveMessage('assistant', 'Second');
    await repo.saveMessage('user', 'Third');
    final messages = (await repo.snapshot()).messages;
    expect(messages.map((m) => m.content), ['First', 'Second', 'Third']);
    expect(messages[1].sequence, greaterThan(messages[0].sequence));
  });

  test('reflection commits only against the unchanged source logs', () async {
    await repo.saveMeal(day, meal);
    final context = (await repo.snapshot()).contextFor(day);
    await repo.saveSummaryIfUnchanged(day, 'A reflection', 'test', context);
    expect((await repo.snapshot()).summaryFor(day)!.content, 'A reflection');
    await repo.addWater(day);
    await expectLater(
      repo.saveSummaryIfUnchanged(day, 'Stale reflection', 'test', context),
      throwsFormatException,
    );
    expect((await repo.snapshot()).summaryFor(day), isNull);
  });

  test(
    'photo meals persist captions and estimates with idempotent saves',
    () async {
      final folder = await Directory.systemTemp.createTemp('freon-photo-test-');
      final photoRepo = FreonRepository(db, photoDirectory: folder);
      final bytes = (await MealPhoto.prepare(
        await File('assets/images/lunch.jpg').readAsBytes(),
      )).bytes;
      final draft = MealDraft(
        title: 'Rice and chicken',
        kind: 'Lunch',
        calories: 520,
        protein: 38,
        carbs: 55,
        fat: 15,
        notes: '24 cm plate, one cup of rice',
        source: 'ai estimate',
        estimateJson: jsonEncode({
          ...validEstimate,
          'model': 'vision-local',
          'caption': '24 cm plate, one cup of rice',
        }),
      );
      await photoRepo.savePhotoMeal(day, draft, bytes, id: 'stable-draft');
      await photoRepo.savePhotoMeal(day, draft, bytes, id: 'stable-draft');
      final data = await repo.snapshot();
      expect(data.meals.length, 1);
      expect(data.caloriesFor(day), 520);
      expect(data.meals.single.notes, contains('24 cm'));
      expect(
        jsonDecode(data.meals.single.estimateJson!)['portion'],
        validEstimate['portion'],
      );
      expect(await File(data.meals.single.imagePath!).readAsBytes(), bytes);
      expect(await folder.list().length, 1);
      await photoRepo.deleteMeal(data.meals.single);
      expect(await folder.list().length, 0);
      await folder.delete(recursive: true);
    },
  );

  test('upgrades a v1 database without losing existing meals', () async {
    await db.close();
    closed = true;
    final folder = await Directory.systemTemp.createTemp('freon-migration-');
    final file = File('${folder.path}/old.sqlite');
    final first = AppDatabase(NativeDatabase(file));
    await FreonRepository(first).saveMeal(day, meal);
    await first.close();
    final old = sqlite.sqlite3.open(file.path);
    old.execute('ALTER TABLE meals DROP COLUMN estimate_json');
    old.execute('PRAGMA user_version = 1');
    old.close();
    final migrated = AppDatabase(NativeDatabase(file));
    try {
      final data = await FreonRepository(migrated).snapshot();
      expect(data.meals.single.title, 'Rice bowl');
      expect(data.meals.single.estimateJson, isNull);
      expect(migrated.schemaVersion, 2);
    } finally {
      await migrated.close();
      await folder.delete(recursive: true);
    }
  });

  test(
    'persists data and recovers interrupted generation after reopen',
    () async {
      await db.close();
      closed = true;
      final directory = await Directory.systemTemp.createTemp('freon-test-');
      final file = File('${directory.path}/freon.sqlite');
      final first = AppDatabase(NativeDatabase(file));
      final firstRepo = FreonRepository(first);
      await firstRepo.saveMeal(day, meal);
      await firstRepo.saveMessage('assistant', '', status: 'pending');
      await first.close();
      final second = AppDatabase(NativeDatabase(file));
      try {
        final data = await FreonRepository(second).snapshot();
        expect(data.caloriesFor(day), 450);
        expect(data.messages.single.status, 'failed');
        expect(data.messages.single.error, contains('interrupted'));
      } finally {
        await second.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
