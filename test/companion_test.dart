import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freon/ai/lm_studio.dart';
import 'package:freon/data/database.dart';
import 'package:freon/data/repository.dart';
import 'package:freon/state/companion.dart';
import 'package:freon/state/providers.dart';

class _Studio extends LmStudio {
  _Studio(this.respond);
  final Stream<String> Function(List<Map<String, dynamic>>) respond;
  @override
  Stream<String> chat(
    String base,
    String model,
    List<Map<String, dynamic>> messages,
  ) => respond(messages);
}

void main() {
  late AppDatabase db;
  late FreonRepository repo;
  late ProviderContainer container;
  late Stream<String> Function(List<Map<String, dynamic>>) respond;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FreonRepository(db);
    await repo.saveSettings(
      baseUrl: 'http://127.0.0.1:1234',
      textModel: 'test-local',
      visionModel: '',
      calorieTarget: 2200,
      waterTarget: 2000,
    );
    respond = (_) => Stream.fromIterable(['Hello ', 'there.']);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        lmStudioFactoryProvider.overrideWithValue(() => _Studio(respond)),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('persists one user turn and a completed streamed answer', () async {
    await container.read(companionProvider.notifier).send('How was today?');
    final data = await repo.snapshot();
    expect(data.messages.map((m) => m.content), [
      'How was today?',
      'Hello there.',
    ]);
    expect(data.messages.last.status, 'complete');
    expect(container.read(companionProvider).busy, false);
  });

  test(
    'retry includes same-second user prompt and never duplicates it',
    () async {
      respond = (_) => Stream.error(const ModelFailure('Server stopped.'));
      await container
          .read(companionProvider.notifier)
          .send('Remember this prompt');
      final failed = (await repo.snapshot()).messages.last;
      expect(failed.status, 'failed');
      respond = (messages) {
        expect(messages.last['role'], 'user');
        expect(messages.last['content'], 'Remember this prompt');
        return Stream.value('Retried answer');
      };
      await container
          .read(companionProvider.notifier)
          .send('retry', retry: failed);
      final data = await repo.snapshot();
      expect(data.messages.length, 2);
      expect(data.messages.last.id, failed.id);
      expect(data.messages.last.content, 'Retried answer');
      expect(data.messages.last.status, 'complete');
    },
  );

  test('double-send is suppressed while a generation is in progress', () async {
    final stream = StreamController<String>();
    final started = Completer<void>();
    respond = (_) {
      started.complete();
      return stream.stream;
    };
    final controller = container.read(companionProvider.notifier);
    final pending = controller.send('One request');
    await started.future;
    await controller.send('Accidental double click');
    stream.add('One answer');
    await stream.close();
    await pending;
    expect((await repo.snapshot()).messages.length, 2);
  });

  test('a cancelled turn is never presented as a complete answer', () async {
    final stream = StreamController<String>();
    final started = Completer<void>();
    respond = (_) {
      started.complete();
      return stream.stream;
    };
    final controller = container.read(companionProvider.notifier);
    final pending = controller.send('A long thought');
    await started.future;
    stream.add('Partial thought');
    controller.cancel();
    await stream.close();
    await pending;
    expect((await repo.snapshot()).messages.last.status, 'cancelled');
  });
}
