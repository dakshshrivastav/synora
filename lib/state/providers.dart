import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../data/workspace.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.local();
  ref.onDispose(database.close);
  return database;
});
final repositoryProvider = Provider(
  (ref) => FreonRepository(ref.watch(databaseProvider)),
);
final workspaceProvider = StreamProvider<Workspace>(
  (ref) => ref.watch(repositoryProvider).watch(),
);

class SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void move(int offset) =>
      state = DateTime(state.year, state.month, state.day + offset);
  void today() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, now.day);
  }
}

final selectedDayProvider = NotifierProvider<SelectedDay, DateTime>(
  SelectedDay.new,
);

enum Destination { dashboard, companion, nutrition, mindset, connection }

class Navigation extends Notifier<Destination> {
  @override
  Destination build() => Destination.dashboard;
  void go(Destination destination) => state = destination;
}

final navigationProvider = NotifierProvider<Navigation, Destination>(
  Navigation.new,
);
