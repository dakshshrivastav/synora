import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';
import 'workspace.dart';

class FreonRepository {
  FreonRepository(this.db, {this.photoDirectory});
  final AppDatabase db;
  final Directory? photoDirectory;
  static const _uuid = Uuid();

  Stream<Workspace> watch() => db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          db.meals,
          db.checkIns,
          db.waterLogs,
          db.settings,
          db.messages,
          db.summaries,
        },
      )
      .watch()
      .asyncMap((_) => snapshot());

  Future<Workspace> snapshot() => db.transaction(
    () async => Workspace(
      meals:
          await (db.select(db.meals)..orderBy([
                (m) => OrderingTerm.desc(m.createdAt),
                (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
              ]))
              .get(),
      checkIns:
          await (db.select(db.checkIns)..orderBy([
                (m) => OrderingTerm.asc(m.sample),
                (m) => OrderingTerm.desc(m.createdAt),
                (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
              ]))
              .get(),
      water: await (db.select(
        db.waterLogs,
      )..orderBy([(m) => OrderingTerm.desc(m.createdAt)])).get(),
      settings: await db.select(db.settings).getSingle(),
      messages: await (db.select(
        db.messages,
      )..orderBy([(m) => OrderingTerm.asc(m.sequence)])).get(),
      summaries: await db.select(db.summaries).get(),
    ),
  );

  Future<void> saveMeal(DateTime day, MealDraft draft, {Meal? existing}) async {
    draft.validate();
    await db.transaction(() async {
      await db
          .into(db.meals)
          .insertOnConflictUpdate(
            MealsCompanion.insert(
              id: existing?.id ?? _uuid.v4(),
              day: dayKey(day),
              title: draft.title.trim(),
              kind: draft.kind,
              calories: draft.calories,
              protein: draft.protein,
              carbs: draft.carbs,
              fat: draft.fat,
              notes: Value(draft.notes.trim()),
              imagePath: Value(draft.imagePath),
              source: Value(draft.source),
              estimateJson: Value(draft.estimateJson),
              sample: Value(existing?.sample ?? false),
              createdAt: existing?.createdAt ?? DateTime.now(),
            ),
          );
      await _invalidateSummary(dayKey(day));
    });
    if (existing?.imagePath != null && existing!.imagePath != draft.imagePath) {
      await _deleteUnusedPhoto(existing.imagePath!);
    }
  }

  Future<void> deleteMeal(Meal meal) async {
    await db.transaction(() async {
      await (db.delete(db.meals)..where((m) => m.id.equals(meal.id))).go();
      await _invalidateSummary(meal.day);
    });
    if (meal.imagePath != null) await _deleteUnusedPhoto(meal.imagePath!);
  }

  Future<Directory> _photoRoot() async {
    if (photoDirectory != null) return photoDirectory!;
    final override = Platform.environment['FREON_DATA_DIR'];
    final root = override == null || override.trim().isEmpty
        ? (await getApplicationSupportDirectory()).path
        : override;
    return Directory(p.join(root, 'photos'));
  }

  Future<void> _deleteUnusedPhoto(String path) async {
    if (path.startsWith('assets/')) return;
    final root = await _photoRoot();
    if (!p.isWithin(p.absolute(root.path), p.absolute(path))) return;
    final references =
        await (db.select(db.meals)
              ..where((m) => m.imagePath.equals(path))
              ..limit(1))
            .get();
    if (references.isEmpty && await File(path).exists()) {
      await File(path).delete();
    }
  }

  Future<void> saveCheckIn(
    DateTime day, {
    required int mood,
    required int stress,
    required int energy,
    required int social,
    required double sleep,
    required String note,
    CheckIn? existing,
  }) async {
    if (mood < 1 ||
        mood > 5 ||
        [stress, energy, social].any((v) => v < 0 || v > 100) ||
        !sleep.isFinite ||
        sleep < 0 ||
        sleep > 24 ||
        note.length > 4000) {
      throw const FormatException(
        'Check your mood, scores, sleep hours, and note length.',
      );
    }
    await db.transaction(() async {
      await db
          .into(db.checkIns)
          .insertOnConflictUpdate(
            CheckInsCompanion.insert(
              id: existing?.id ?? _uuid.v4(),
              day: dayKey(day),
              mood: mood,
              stress: stress,
              energy: energy,
              social: social,
              sleep: sleep,
              note: note.trim(),
              sample: Value(existing?.sample ?? false),
              createdAt: existing?.createdAt ?? DateTime.now(),
            ),
          );
      await _invalidateSummary(dayKey(day));
    });
  }

  Future<void> deleteCheckIn(CheckIn check) => db.transaction(() async {
    await (db.delete(db.checkIns)..where((c) => c.id.equals(check.id))).go();
    await _invalidateSummary(check.day);
  });

  Future<void> addWater(DateTime day) => db.transaction(() async {
    await db
        .into(db.waterLogs)
        .insert(
          WaterLogsCompanion.insert(
            id: _uuid.v4(),
            day: dayKey(day),
            milliliters: 250,
            createdAt: DateTime.now(),
          ),
        );
    await _invalidateSummary(dayKey(day));
  });

  Future<void> undoWater(DateTime day) => db.transaction(() async {
    final row =
        await (db.select(db.waterLogs)
              ..where((w) => w.day.equals(dayKey(day)))
              ..orderBy([
                (w) => OrderingTerm.asc(w.sample),
                (w) => OrderingTerm.desc(w.createdAt),
                (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (row != null) {
      await (db.delete(db.waterLogs)..where((w) => w.id.equals(row.id))).go();
    }
    await _invalidateSummary(dayKey(day));
  });

  Future<void> saveSettings({
    required String baseUrl,
    required String textModel,
    required String visionModel,
    required int calorieTarget,
    required int waterTarget,
  }) async {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !['', '/', '/v1', '/v1/'].contains(uri.path)) {
      throw const FormatException(
        'Enter an HTTP(S) server address, such as http://127.0.0.1:1234.',
      );
    }
    if (calorieTarget <= 0 ||
        calorieTarget > 20000 ||
        waterTarget < 250 ||
        waterTarget > 20000) {
      throw const FormatException(
        'Enter positive targets (water: 250–20,000 ml).',
      );
    }
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion(
            id: const Value(1),
            baseUrl: Value(uri.replace(path: '').toString()),
            textModel: Value(textModel.trim()),
            visionModel: Value(visionModel.trim()),
            calorieTarget: Value(calorieTarget),
            waterTarget: Value(waterTarget),
          ),
        );
  }

  Future<String> saveMessage(
    String role,
    String content, {
    String status = 'complete',
    String model = '',
  }) async {
    final id = _uuid.v4();
    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: id,
            role: role,
            content: content,
            status: status,
            model: Value(model),
            createdAt: DateTime.now(),
          ),
        );
    return id;
  }

  Future<void> updateMessage(
    String id,
    String content,
    String status, {
    String? error,
    String? model,
  }) async {
    await (db.update(db.messages)..where((m) => m.id.equals(id))).write(
      MessagesCompanion(
        content: Value(content),
        status: Value(status),
        error: Value(error),
        model: model == null ? const Value.absent() : Value(model),
      ),
    );
  }

  Future<void> clearConversation() async {
    await db.delete(db.messages).go();
  }

  Future<void> saveSummary(
    DateTime day,
    String content,
    String model,
    bool includesSample,
  ) async {
    if (content.trim().isEmpty || content.length > 20000) {
      throw const FormatException(
        'Reflection was empty or too long. Try again.',
      );
    }
    await db
        .into(db.summaries)
        .insertOnConflictUpdate(
          SummariesCompanion.insert(
            day: dayKey(day),
            content: content,
            model: model,
            includesSample: includesSample,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> _invalidateSummary(String day) async {
    await (db.delete(db.summaries)..where((s) => s.day.equals(day))).go();
  }

  Future<void> saveSummaryIfUnchanged(
    DateTime day,
    String content,
    String model,
    String expectedContext,
  ) => db.transaction(() async {
    final current = await snapshot();
    if (current.contextFor(day) != expectedContext) {
      throw const FormatException(
        'Logs changed during generation. Please generate a fresh reflection.',
      );
    }
    await saveSummary(day, content, model, current.sampleFor(day));
  });

  Future<void> loadSampleDay(DateTime day) => db.transaction(() async {
    final key = dayKey(day);
    final existing = await (db.select(
      db.meals,
    )..where((m) => m.day.equals(key) & m.sample.equals(true))).get();
    final existingChecks = await (db.select(
      db.checkIns,
    )..where((c) => c.day.equals(key) & c.sample.equals(true))).get();
    final existingWater = await (db.select(
      db.waterLogs,
    )..where((w) => w.day.equals(key) & w.sample.equals(true))).get();
    if (existing.isNotEmpty ||
        existingChecks.isNotEmpty ||
        existingWater.isNotEmpty) {
      return;
    }
    final samples = [
      (
        'Breakfast',
        'Oatmeal & berries',
        390.0,
        14.0,
        58.0,
        11.0,
        'breakfast',
        8,
      ),
      ('Lunch', 'Quinoa power bowl', 580.0, 42.0, 52.0, 18.0, 'lunch', 13),
      ('Snack', 'Greek yogurt', 140.0, 16.0, 12.0, 3.0, '', 16),
    ];
    for (final (kind, title, cal, protein, carbs, fat, image, hour)
        in samples) {
      await db
          .into(db.meals)
          .insert(
            MealsCompanion.insert(
              id: _uuid.v4(),
              day: key,
              title: title,
              kind: kind,
              calories: cal,
              protein: protein,
              carbs: carbs,
              fat: fat,
              source: const Value('sample'),
              sample: const Value(true),
              imagePath: Value(
                image.isEmpty ? null : 'assets/images/$image.jpg',
              ),
              createdAt: DateTime(day.year, day.month, day.day, hour),
            ),
          );
    }
    for (var i = 0; i < 6; i++) {
      await db
          .into(db.waterLogs)
          .insert(
            WaterLogsCompanion.insert(
              id: _uuid.v4(),
              day: key,
              milliliters: 250,
              sample: const Value(true),
              createdAt: DateTime(day.year, day.month, day.day, 9 + i),
            ),
          );
    }
    await db
        .into(db.checkIns)
        .insert(
          CheckInsCompanion.insert(
            id: _uuid.v4(),
            day: key,
            mood: 4,
            stress: 24,
            energy: 82,
            social: 65,
            sleep: 7.75,
            note: 'Sample journal: A balanced lunch and a short walk helped me take a pause before my presentation.',
            sample: const Value(true),
            createdAt: DateTime(day.year, day.month, day.day, 17),
          ),
        );
    await _invalidateSummary(key);
  });

  Future<void> clearSamples() => db.transaction(() async {
    await (db.delete(db.meals)..where((m) => m.sample.equals(true))).go();
    await (db.delete(db.checkIns)..where((c) => c.sample.equals(true))).go();
    await (db.delete(db.waterLogs)..where((w) => w.sample.equals(true))).go();
    await (db.delete(
      db.summaries,
    )..where((s) => s.includesSample.equals(true))).go();
  });

  Future<String> importPhoto(String source) async {
    final file = File(source);
    final ext = p.extension(source).toLowerCase();
    if (!['.jpg', '.jpeg', '.png'].contains(ext)) {
      throw const FormatException('Choose a JPEG or PNG image.');
    }
    if (await file.length() > 10 * 1024 * 1024) {
      throw const FormatException('Choose an image smaller than 10 MB.');
    }
    final directory = await _photoRoot();
    await directory.create(recursive: true);
    return (await file.copy(p.join(directory.path, '${_uuid.v4()}$ext'))).path;
  }

  /// A saved photo is removed again if its associated database write fails.
  Future<void> savePhotoMeal(
    DateTime day,
    MealDraft draft,
    Uint8List photo, {
    required String id,
  }) async {
    draft.validate();
    if (photo.length < 8 ||
        photo.length > 10 * 1024 * 1024 ||
        photo[0] != 137 ||
        photo[1] != 80 ||
        photo[2] != 78 ||
        photo[3] != 71) {
      throw const FormatException('Invalid prepared photo.');
    }
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(id)) {
      throw const FormatException('Invalid meal identifier.');
    }
    final root = await _photoRoot();
    await root.create(recursive: true);
    final file = File(p.join(root.path, '${_uuid.v4()}.png'));
    try {
      await file.writeAsBytes(photo, flush: true);
      await db.transaction(() async {
        // Stable draft IDs make repeated submissions idempotent.
        final existing = await (db.select(
          db.meals,
        )..where((m) => m.id.equals(id))).getSingleOrNull();
        if (existing != null) {
          await file.delete();
          return;
        }
        await db
            .into(db.meals)
            .insert(
              MealsCompanion.insert(
                id: id,
                day: dayKey(day),
                title: draft.title.trim(),
                kind: draft.kind,
                calories: draft.calories,
                protein: draft.protein,
                carbs: draft.carbs,
                fat: draft.fat,
                notes: Value(draft.notes.trim()),
                imagePath: Value(file.path),
                source: Value(draft.source),
                estimateJson: Value(draft.estimateJson),
                createdAt: DateTime.now(),
              ),
            );
        await _invalidateSummary(dayKey(day));
      });
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }
}
