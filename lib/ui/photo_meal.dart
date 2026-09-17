import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/workspace.dart';
import '../services/meal_photo.dart';
import '../state/meal_analysis.dart';
import '../state/providers.dart';
import 'components.dart';
import 'theme.dart';

Future<void> showPhotoMealEditor(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const PhotoMealEditor(),
);

class PhotoMealEditor extends ConsumerStatefulWidget {
  const PhotoMealEditor({super.key});
  @override
  ConsumerState<PhotoMealEditor> createState() => _PhotoMealEditorState();
}

class _PhotoMealEditorState extends ConsumerState<PhotoMealEditor> {
  final _caption = TextEditingController();
  final _title = TextEditingController();
  final _calories = TextEditingController(),
      _protein = TextEditingController(),
      _carbs = TextEditingController(),
      _fat = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _id = const Uuid().v4();
  late final DateTime _day;
  late final Future<List<String>> _cameras;
  MealPhoto? _photo;
  String _kind = 'Lunch';
  String? _device, _error;
  bool _acquiring = false, _saving = false;

  @override
  void initState() {
    super.initState();
    _day = ref.read(selectedDayProvider);
    _cameras = ref.read(mealPhotoServiceProvider).cameras();
  }

  @override
  void dispose() {
    for (final c in [_caption, _title, _calories, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _getPhoto({bool camera = false}) async {
    setState(() {
      _acquiring = true;
      _error = null;
    });
    try {
      final service = ref.read(mealPhotoServiceProvider);
      final photo = camera
          ? await service.capture(_device!)
          : await service.pick();
      if (photo != null && mounted) {
        ref.read(mealAnalysisProvider.notifier).reset();
        setState(() => _photo = photo);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e.toString().replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _acquiring = false);
    }
  }

  Future<void> _save() async {
    final state = ref.read(mealAnalysisProvider);
    final estimate = state.estimate;
    if (_saving ||
        estimate == null ||
        _photo == null ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final calories = double.parse(_calories.text),
          protein = double.parse(_protein.text),
          carbs = double.parse(_carbs.text),
          fat = double.parse(_fat.text);
      final corrected =
          _title.text.trim() != estimate.title ||
          calories != estimate.calories ||
          protein != estimate.protein ||
          carbs != estimate.carbs ||
          fat != estimate.fat;
      await ref
          .read(repositoryProvider)
          .savePhotoMeal(
            _day,
            MealDraft(
              title: _title.text,
              kind: _kind,
              calories: calories,
              protein: protein,
              carbs: carbs,
              fat: fat,
              notes: state.caption,
              source: corrected ? 'corrected estimate' : 'ai estimate',
              estimateJson: jsonEncode({
                ...estimate.toJson(),
                'model': state.model,
                'caption': state.caption,
              }),
            ),
            _photo!.bytes,
            id: _id,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo meal saved. Your daily totals are updated.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e.toString().replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mealPhotoServiceProvider);
    final state = ref.watch(mealAnalysisProvider);
    final busy = _acquiring || _saving || state.busy;
    final estimate = state.estimate;
    ref.listen(mealAnalysisProvider, (previous, next) {
      if (next.estimate != null && next.estimate != previous?.estimate) {
        _title.text = next.estimate!.title;
        _calories.text = next.estimate!.calories.toString();
        _protein.text = next.estimate!.protein.toString();
        _carbs.text = next.estimate!.carbs.toString();
        _fat.text = next.estimate!.fat.toString();
      }
    });
    final input = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MicroLabel('01 / the photo', color: FreonColors.teal),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 230,
          color: FreonColors.pale,
          child: _photo == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 44,
                      color: FreonColors.teal,
                    ),
                    SizedBox(height: 14),
                    Text('Show Freon what’s on your plate'),
                  ],
                )
              : Image.memory(_photo!.bytes, fit: BoxFit.contain),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : _getPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_photo == null ? 'Choose photo' : 'Replace photo'),
            ),
            FutureBuilder<List<String>>(
              future: _cameras,
              builder: (context, snapshot) {
                final cameras = snapshot.data ?? [];
                _device ??= cameras.firstOrNull;
                return Tooltip(
                  message: cameras.isEmpty
                      ? 'No webcam detected. You can choose a photo from a phone or camera.'
                      : 'Capture one frame with FFmpeg, then review it here.',
                  child: OutlinedButton.icon(
                    onPressed: busy || _device == null
                        ? null
                        : () => _getPhoto(camera: true),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Take photo'),
                  ),
                );
              },
            ),
          ],
        ),
        FutureBuilder<List<String>>(
          future: _cameras,
          builder: (_, snapshot) {
            final cameras = snapshot.data ?? [];
            if (cameras.length < 2) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DropdownButtonFormField<String>(
                initialValue: _device ?? cameras.first,
                decoration: const InputDecoration(labelText: 'Camera'),
                items: [
                  for (final camera in cameras)
                    DropdownMenuItem(value: camera, child: Text(camera)),
                ],
                onChanged: busy ? null : (v) => setState(() => _device = v),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          _acquiring
              ? 'Preparing photo…'
              : 'JPEG or PNG · up to 10 MB · resized locally to 1280 px',
          style: const TextStyle(fontSize: 11, color: FreonColors.muted),
        ),
        const SizedBox(height: 24),
        const MicroLabel('02 / add some context', color: FreonColors.teal),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('photo-caption'),
          controller: _caption,
          enabled: !busy,
          minLines: 3,
          maxLines: 5,
          maxLength: 4000,
          onChanged: (_) {
            ref.read(mealAnalysisProvider.notifier).reset();
            setState(() => _error = null);
          },
          decoration: const InputDecoration(
            labelText: 'Caption / portion and preparation',
            hintText: 'A 24 cm plate: 1 cup rice and chicken cooked in 1 tsp oil. I ate everything shown.',
          ),
        ),
        const Text(
          'Include scale, ingredients, cooking method, and how much you ate. Details help resolve what a photo cannot show.',
          style: TextStyle(fontSize: 12, color: FreonColors.muted),
        ),
      ],
    );
    final result = Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MicroLabel('03 / estimate & log', color: FreonColors.teal),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Meal type'),
            items: [
              for (final kind in mealKinds)
                DropdownMenuItem(value: kind, child: Text(kind)),
            ],
            onChanged: busy ? null : (v) => setState(() => _kind = v!),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy || _photo == null
                  ? null
                  : () {
                      setState(() => _error = null);
                      ref
                          .read(mealAnalysisProvider.notifier)
                          .analyze(_photo!, _caption.text);
                    },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                state.busy
                    ? 'Estimating your meal…'
                    : estimate == null
                    ? 'Estimate meal'
                    : 'Estimate again',
              ),
            ),
          ),
          if (state.busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            TextButton(
              onPressed: () => ref.read(mealAnalysisProvider.notifier).reset(),
              child: const Text('Cancel analysis'),
            ),
          ],
          const SizedBox(height: 20),
          if (estimate == null)
            const EmptyCard(
              title: 'a little more detail.',
              message: 'Freon sends your photo and caption together to the vision model selected in Connection. Estimated calories and macros will appear here.',
              icon: Icons.restaurant_outlined,
            ),
          if (estimate != null) ...[
            MetroCard(
              color: FreonColors.mint,
              padding: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MicroLabel(
                    'estimated / editable',
                    color: FreonColors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(estimate.foods.join(' · ')),
                  const SizedBox(height: 8),
                  Text(estimate.portion),
                  const SizedBox(height: 10),
                  Text(
                    'Model uncertainty: ${estimate.uncertainty}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  for (final assumption in estimate.assumptions)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '• $assumption',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Meal title'),
              validator: (v) => v == null || v.trim().isEmpty || v.length > 200
                  ? 'Enter a title under 200 characters'
                  : null,
            ),
            const SizedBox(height: 12),
            TileGrid(
              children: [
                for (final item in [
                  ('Calories (kcal)', _calories),
                  ('Protein (g)', _protein),
                  ('Carbohydrates (g)', _carbs),
                  ('Fat (g)', _fat),
                ])
                  TextFormField(
                    controller: item.$2,
                    enabled: !busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: item.$1),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      return n == null || !n.isFinite || n < 0 || n > 20000
                          ? 'Enter 0–20,000'
                          : null;
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Estimated with ${state.model}. Adjust anything before saving.',
              style: const TextStyle(fontSize: 12, color: FreonColors.muted),
            ),
          ],
          if (_error != null || state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                width: double.infinity,
                color: const Color(0xffffdad6),
                padding: const EdgeInsets.all(12),
                child: Text(_error ?? state.error!),
              ),
            ),
        ],
      ),
    );
    return PopScope(
      canPop: !_saving && !_acquiring,
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 820),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MicroLabel('freon / photo meal', color: FreonColors.teal),
                const SizedBox(height: 8),
                Text('a picture of your plate', style: displayStyle(36)),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: LayoutBuilder(
                      builder: (_, constraints) => constraints.maxWidth >= 700
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: input),
                                const SizedBox(width: 28),
                                Expanded(child: result),
                              ],
                            )
                          : Column(
                              children: [
                                input,
                                const SizedBox(height: 24),
                                result,
                              ],
                            ),
                    ),
                  ),
                ),
                const Divider(height: 32),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving || _acquiring
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      FilledButton.icon(
                        onPressed: busy || estimate == null ? null : _save,
                        icon: const Icon(Icons.add_task),
                        label: Text(_saving ? 'Saving…' : 'Add to meal log'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
