import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/lm_studio.dart';
import '../data/database.dart';
import 'providers.dart';

class CompanionState {
  const CompanionState({
    this.busy = false,
    this.partial = '',
    this.messageId,
    this.error,
  });
  final bool busy;
  final String partial;
  final String? messageId, error;
}

final lmStudioFactoryProvider = Provider<LmStudio Function()>(
  (ref) =>
      () => LmStudio(),
);

class CompanionController extends Notifier<CompanionState> {
  LmStudio? _active;
  bool _cancelled = false;
  @override
  CompanionState build() {
    ref.onDispose(() => _active?.close());
    return const CompanionState();
  }

  Future<void> send(String input, {Message? retry}) async {
    if (state.busy || input.trim().isEmpty) return;
    if (input.length > 8000) {
      state = const CompanionState(
        error: 'Keep messages under 8,000 characters.',
      );
      return;
    }
    final repo = ref.read(repositoryProvider);
    final day = ref.read(selectedDayProvider);
    _cancelled = false;
    state = const CompanionState(busy: true);
    String? id;
    var partial = '';
    try {
      final snapshot = await repo.snapshot();
      if (!ref.mounted) return;
      final settings = snapshot.settings;
      if (settings.textModel.isEmpty) {
        throw const ModelFailure(
          'Choose a text model in Connection settings first.',
        );
      }
      if (retry == null) await repo.saveMessage('user', input.trim());
      id =
          retry?.id ??
          await repo.saveMessage(
            'assistant',
            '',
            status: 'pending',
            model: settings.textModel,
          );
      if (retry != null) {
        await repo.updateMessage(id, '', 'pending', model: settings.textModel);
      }
      final previous = snapshot.messages
          .where(
            (m) =>
                m.status == 'complete' &&
                (retry == null || m.sequence < retry.sequence),
          )
          .toList();
      // Bounded history prevents the entire database from being sent to the model.
      final recent = previous.reversed.take(16).toList().reversed;
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': companionPrompt},
        {
          'role': 'system',
          'content':
              'Context data for the selected day:\n${snapshot.contextFor(day)}',
        },
        for (final message in recent)
          {
            'role': message.role,
            'content': message.content.length > 4000
                ? message.content.substring(0, 4000)
                : message.content,
          },
        if (retry == null) {'role': 'user', 'content': input.trim()},
      ];
      if (!ref.mounted) return;
      _active = ref.read(lmStudioFactoryProvider)();
      if (_cancelled) throw const ModelFailure('Generation cancelled.');
      await for (final chunk in _active!.chat(
        settings.baseUrl,
        settings.textModel,
        messages,
      )) {
        partial += chunk;
        if (ref.mounted) {
          state = CompanionState(busy: true, partial: partial, messageId: id);
        }
      }
      if (!ref.mounted) return;
      await repo.updateMessage(
        id,
        partial,
        _cancelled ? 'cancelled' : 'complete',
      );
      if (ref.mounted) state = const CompanionState();
    } catch (e) {
      if (!ref.mounted) return;
      if (id != null) {
        await repo.updateMessage(
          id,
          partial,
          _cancelled ? 'cancelled' : 'failed',
          error: e.toString(),
        );
      }
      if (ref.mounted) {
        state = CompanionState(error: _cancelled ? null : e.toString());
      }
    } finally {
      _active?.close();
      _active = null;
    }
  }

  void cancel() {
    _cancelled = true;
    _active?.close();
  }

  Future<void> summarize(DateTime day) async {
    if (state.busy) return;
    final repo = ref.read(repositoryProvider);
    _cancelled = false;
    state = const CompanionState(busy: true);
    try {
      final snapshot = await repo.snapshot();
      if (!ref.mounted) return;
      if (snapshot.mealsFor(day).isEmpty &&
          snapshot.latestFor(day) == null &&
          snapshot.waterFor(day) == 0) {
        throw const ModelFailure(
          'Log a meal, water, or a check-in before reflecting on the day.',
        );
      }
      _active = ref.read(lmStudioFactoryProvider)();
      if (_cancelled) throw const ModelFailure('Generation cancelled.');
      var result = '';
      await for (final chunk in _active!.chat(
        snapshot.settings.baseUrl,
        snapshot.settings.textModel,
        [
          {'role': 'system', 'content': companionPrompt},
          {
            'role': 'user',
            'content':
                'Summarize these logs in three short paragraphs: observations, one gentle reflection, and one small next step. Cite only logged facts.\n${snapshot.contextFor(day)}',
          },
        ],
      )) {
        result += chunk;
      }
      // Do not publish a summary for records edited while generation was running.
      if (_cancelled) throw const ModelFailure('Generation cancelled.');
      await repo.saveSummaryIfUnchanged(
        day,
        result,
        snapshot.settings.textModel,
        snapshot.contextFor(day),
      );
      if (ref.mounted) state = const CompanionState();
    } catch (e) {
      if (ref.mounted) state = CompanionState(error: e.toString());
    } finally {
      _active?.close();
      _active = null;
    }
  }
}

final companionProvider = NotifierProvider<CompanionController, CompanionState>(
  CompanionController.new,
);
