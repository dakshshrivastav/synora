import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/workspace.dart';
import '../state/providers.dart';
import 'components.dart';
import 'theme.dart';

Future<void> showMealEditor(
  BuildContext context, {
  Meal? meal,
  String kind = 'Snack',
}) => showDialog<void>(
  context: context,
  builder: (_) => MealEditor(meal: meal, kind: kind),
);
Future<void> showCheckInEditor(BuildContext context, {CheckIn? check}) =>
    showDialog<void>(
      context: context,
      builder: (_) => CheckInEditor(check: check),
    );

class MealEditor extends ConsumerStatefulWidget {
  const MealEditor({super.key, this.meal, required this.kind});
  final Meal? meal;
  final String kind;
  @override
  ConsumerState<MealEditor> createState() => _MealEditorState();
}

class _MealEditorState extends ConsumerState<MealEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title,
      _calories,
      _protein,
      _carbs,
      _fat,
      _notes;
  late String _kind;
  String? _photo, _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final m = widget.meal;
    _title = TextEditingController(text: m?.title ?? '');
    _calories = TextEditingController(text: m?.calories.toString() ?? '');
    _protein = TextEditingController(text: m?.protein.toString() ?? '0');
    _carbs = TextEditingController(text: m?.carbs.toString() ?? '0');
    _fat = TextEditingController(text: m?.fat.toString() ?? '0');
    _notes = TextEditingController(text: m?.notes ?? '');
    _kind = m?.kind ?? widget.kind;
    _photo = m?.imagePath;
  }

  @override
  void dispose() {
    for (final c in [_title, _calories, _protein, _carbs, _fat, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      var photo = _photo;
      if (photo != null &&
          photo != widget.meal?.imagePath &&
          !photo.startsWith('assets/')) {
        photo = await repo.importPhoto(photo);
      }
      await repo.saveMeal(
        ref.read(selectedDayProvider),
        MealDraft(
          title: _title.text,
          kind: _kind,
          calories: double.parse(_calories.text),
          protein: double.parse(_protein.text),
          carbs: double.parse(_carbs.text),
          fat: double.parse(_fat.text),
          notes: _notes.text,
          imagePath: photo,
          source: widget.meal?.source == 'ai estimate'
              ? 'corrected estimate'
              : widget.meal?.source ?? 'manual',
        ),
        existing: widget.meal,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const MicroLabel('nutrition // local log'),
              const SizedBox(height: 8),
              Text(
                widget.meal == null ? 'add a little fuel' : 'edit your meal',
                style: displayStyle(36),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Meal title'),
                maxLength: 200,
                validator: (s) =>
                    s == null || s.trim().isEmpty ? 'Enter a meal title' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Meal type'),
                items: [
                  for (final kind in mealKinds)
                    DropdownMenuItem(value: kind, child: Text(kind)),
                ],
                onChanged: (v) => setState(() => _kind = v!),
              ),
              const SizedBox(height: 16),
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: item.$1),
                      validator: (s) {
                        final n = double.tryParse(s ?? '');
                        return n == null || !n.isFinite || n < 0 || n > 20000
                            ? 'Enter 0–20,000'
                            : null;
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Caption / portion notes',
                ),
              ),
              const SizedBox(height: 12),
              if (_photo != null)
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: _photo!.startsWith('assets/')
                      ? Image.asset(_photo!, fit: BoxFit.cover)
                      : Image.file(
                          File(_photo!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Text('Image unavailable'),
                        ),
                ),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            try {
                              final file = await FilePicker.pickFile(
                                type: FileType.custom,
                                allowedExtensions: ['jpg', 'jpeg', 'png'],
                              );
                              if (file?.path != null && mounted) {
                                setState(() => _photo = file!.path);
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(
                                  () => _error =
                                      'Could not open the file picker: $e',
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Attach photo'),
                  ),
                  if (_photo != null)
                    TextButton(
                      onPressed: () => setState(() => _photo = null),
                      child: const Text('Remove photo'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Values are your entries or editable estimates, not measured nutritional facts.',
                style: TextStyle(fontSize: 12, color: FreonColors.muted),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? 'Saving…' : 'Save meal'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CheckInEditor extends ConsumerStatefulWidget {
  const CheckInEditor({super.key, this.check});
  final CheckIn? check;
  @override
  ConsumerState<CheckInEditor> createState() => _CheckInEditorState();
}

class _CheckInEditorState extends ConsumerState<CheckInEditor> {
  late int _mood;
  late double _stress, _energy, _social;
  late final TextEditingController _sleep, _note;
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _mood = widget.check?.mood ?? 3;
    _stress = widget.check?.stress.toDouble() ?? 30;
    _energy = widget.check?.energy.toDouble() ?? 60;
    _social = widget.check?.social.toDouble() ?? 50;
    _sleep = TextEditingController(text: widget.check?.sleep.toString() ?? '');
    _note = TextEditingController(text: widget.check?.note ?? '');
  }

  @override
  void dispose() {
    _sleep.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MicroLabel('mindset // self-reported'),
              const SizedBox(height: 8),
              Text('how are you, really?', style: displayStyle(36)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 1; i <= 5; i++)
                    ChoiceChip(
                      label: Text(
                        moodNames[i - 1],
                        style: TextStyle(
                          color: i == _mood ? Colors.white : FreonColors.ink,
                        ),
                      ),
                      selected: i == _mood,
                      onSelected: (_) => setState(() => _mood = i),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              for (final item in [
                ('Stress', _stress, (double v) => setState(() => _stress = v)),
                ('Energy', _energy, (double v) => setState(() => _energy = v)),
                (
                  'Social battery',
                  _social,
                  (double v) => setState(() => _social = v),
                ),
              ]) ...[
                Row(
                  children: [
                    Expanded(child: Text(item.$1)),
                    Text('${item.$2.round()} / 100'),
                  ],
                ),
                Slider(
                  value: item.$2,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: item.$2.round().toString(),
                  onChanged: item.$3,
                ),
              ],
              TextFormField(
                controller: _sleep,
                decoration: const InputDecoration(
                  labelText: 'Sleep last night (hours)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (s) {
                  final n = double.tryParse(s ?? '');
                  return n == null || !n.isFinite || n < 0 || n > 24
                      ? 'Enter 0–24 hours'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'A thought, a memory, a small win…',
                ),
                maxLines: 4,
                maxLength: 4000,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (!_form.currentState!.validate()) return;
                            setState(() {
                              _busy = true;
                              _error = null;
                            });
                            try {
                              await ref
                                  .read(repositoryProvider)
                                  .saveCheckIn(
                                    ref.read(selectedDayProvider),
                                    mood: _mood,
                                    stress: _stress.round(),
                                    energy: _energy.round(),
                                    social: _social.round(),
                                    sleep: double.parse(_sleep.text),
                                    note: _note.text,
                                    existing: widget.check,
                                  );
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (mounted) {
                                setState(() => _error = e.toString());
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: Text(_busy ? 'Saving…' : 'Save check-in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
