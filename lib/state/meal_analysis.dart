import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/lm_studio.dart';
import '../data/meal_estimate.dart';
import '../services/meal_photo.dart';
import 'companion.dart';
import 'providers.dart';

class MealAnalysisState {
  const MealAnalysisState({
    this.busy = false,
    this.estimate,
    this.model = '',
    this.caption = '',
    this.error,
  });
  final bool busy;
  final MealEstimate? estimate;
  final String model, caption;
  final String? error;
}

class MealAnalysisController extends Notifier<MealAnalysisState> {
  LmStudio? _client;
  int _request = 0;
  @override
  MealAnalysisState build() {
    ref.onDispose(() => _client?.close());
    return const MealAnalysisState();
  }

  void reset() {
    _request++;
    _client?.close();
    state = const MealAnalysisState();
  }

  Future<void> analyze(MealPhoto photo, String caption) async {
    if (state.busy) return;
    final request = ++_request;
    final client = ref.read(lmStudioFactoryProvider)();
    _client = client;
    state = const MealAnalysisState(busy: true);
    try {
      if (caption.trim().isEmpty || caption.length > 4000) {
        throw const ModelFailure(
          'Add a caption describing the portion, scale, and preparation.',
        );
      }
      final settings = (await ref.read(repositoryProvider).snapshot()).settings;
      if (!ref.mounted || request != _request) return;
      final estimate = await client.estimateMeal(
        settings.baseUrl,
        settings.visionModel,
        photo.bytes,
        caption,
      );
      if (!ref.mounted || request != _request) return;
      state = MealAnalysisState(
        estimate: estimate,
        model: settings.visionModel,
        caption: caption.trim(),
      );
    } catch (e) {
      if (ref.mounted && request == _request) {
        state = MealAnalysisState(error: e.toString());
      }
    } finally {
      client.close();
    }
  }
}

final mealAnalysisProvider =
    NotifierProvider.autoDispose<MealAnalysisController, MealAnalysisState>(
      MealAnalysisController.new,
    );
