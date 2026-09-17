import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Meals extends Table {
  TextColumn get id => text()();
  TextColumn get day => text()();
  TextColumn get title => text()();
  TextColumn get kind => text()();
  RealColumn get calories => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get imagePath => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get estimateJson => text().nullable()();
  BoolColumn get sample => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class CheckIns extends Table {
  TextColumn get id => text()();
  TextColumn get day => text()();
  IntColumn get mood => integer()();
  IntColumn get stress => integer()();
  IntColumn get energy => integer()();
  IntColumn get social => integer()();
  RealColumn get sleep => real()();
  TextColumn get note => text()();
  BoolColumn get sample => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class WaterLogs extends Table {
  TextColumn get id => text()();
  TextColumn get day => text()();
  IntColumn get milliliters => integer()();
  BoolColumn get sample => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get baseUrl =>
      text().withDefault(const Constant('http://127.0.0.1:1234'))();
  TextColumn get textModel => text().withDefault(const Constant(''))();
  TextColumn get visionModel => text().withDefault(const Constant(''))();
  IntColumn get calorieTarget => integer().withDefault(const Constant(2200))();
  IntColumn get waterTarget => integer().withDefault(const Constant(2000))();
  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  IntColumn get sequence => integer().autoIncrement()();
  TextColumn get id => text().unique()();
  TextColumn get role => text()();
  TextColumn get content => text()();
  TextColumn get status => text()();
  TextColumn get model => text().withDefault(const Constant(''))();
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class Summaries extends Table {
  TextColumn get day => text()();
  TextColumn get content => text()();
  TextColumn get model => text()();
  BoolColumn get includesSample => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {day};
}

@DriftDatabase(
  tables: [Meals, CheckIns, WaterLogs, Settings, Messages, Summaries],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  AppDatabase.local()
    : super(
        LazyDatabase(() async {
          final override = Platform.environment['FREON_DATA_DIR'];
          final directory = override == null || override.trim().isEmpty
              ? await getApplicationSupportDirectory()
              : Directory(override);
          await directory.create(recursive: true);
          return NativeDatabase.createInBackground(
            File(p.join(directory.path, 'freon.sqlite')),
          );
        }),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(meals, meals.estimateJson);
    },
    onCreate: (m) async {
      await m.createAll();
      await into(settings).insert(const SettingsCompanion());
      await customStatement('CREATE INDEX meals_day ON meals(day)');
      await customStatement('CREATE INDEX check_ins_day ON check_ins(day)');
      await customStatement('CREATE INDEX water_logs_day ON water_logs(day)');
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await (update(
        messages,
      )..where((m) => m.status.isIn(['pending', 'streaming']))).write(
        const MessagesCompanion(
          status: Value('failed'),
          error: Value('Generation was interrupted. You can retry.'),
        ),
      );
    },
  );
}
