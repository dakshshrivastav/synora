import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/lm_studio.dart';
import 'companion.dart';

class LmConnectionState {
  const LmConnectionState({
    this.testing = false,
    this.connected = false,
    this.models = const [],
    this.message,
    this.baseUrl = '',
  });
  final bool testing, connected;
  final List<String> models;
  final String? message;
  final String baseUrl;
}

class ConnectionController extends Notifier<LmConnectionState> {
  LmStudio? _client;
  int _request = 0;
  @override
  LmConnectionState build() {
    ref.onDispose(() => _client?.close());
    return const LmConnectionState();
  }

  void reset() {
    _request++;
    _client?.close();
    state = const LmConnectionState();
  }

  Future<void> test(String baseUrl) async {
    final request = ++_request;
    _client?.close();
    final client = ref.read(lmStudioFactoryProvider)();
    _client = client;
    state = LmConnectionState(testing: true, baseUrl: baseUrl.trim());
    try {
      final models = await client.models(baseUrl.trim());
      if (!ref.mounted || request != _request) return;
      state = LmConnectionState(
        connected: true,
        models: models,
        baseUrl: baseUrl.trim(),
        message: models.isEmpty
            ? 'Server reachable. Load a model in LM Studio, then test again.'
            : 'Server reachable · ${models.length} models available. Select a loaded model for inference.',
      );
    } catch (e) {
      if (ref.mounted && request == _request) {
        state = LmConnectionState(
          message: e.toString(),
          baseUrl: baseUrl.trim(),
        );
      }
    } finally {
      client.close();
    }
  }
}

final connectionProvider =
    NotifierProvider<ConnectionController, LmConnectionState>(
      ConnectionController.new,
    );
