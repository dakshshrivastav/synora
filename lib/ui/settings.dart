import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/connection.dart';
import '../data/workspace.dart';
import '../state/providers.dart';
import 'components.dart';
import 'theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, required this.workspace});
  final Workspace workspace;
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _url, _text, _vision, _calories, _water;
  bool _saving = false;
  LmConnectionState get _connection => ref.watch(connectionProvider);
  List<String> get _models =>
      _connection.baseUrl == _url.text.trim() ? _connection.models : const [];
  String? get _status =>
      _connection.baseUrl == _url.text.trim() ? _connection.message : null;
  bool get _testing => ref.watch(connectionProvider).testing;
  bool get _connected => ref.watch(connectionProvider).connected;
  @override
  void initState() {
    super.initState();
    final settings = widget.workspace.settings;
    _url = TextEditingController(text: settings.baseUrl);
    _text = TextEditingController(text: settings.textModel);
    _vision = TextEditingController(text: settings.visionModel);
    _calories = TextEditingController(text: settings.calorieTarget.toString());
    _water = TextEditingController(text: settings.waterTarget.toString());
  }

  @override
  void dispose() {
    for (final c in [_url, _text, _vision, _calories, _water]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _test() => ref.read(connectionProvider.notifier).test(_url.text);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(repositoryProvider)
          .saveSettings(
            baseUrl: _url.text,
            textModel: _text.text,
            visionModel: _vision.text,
            calorieTarget: int.tryParse(_calories.text) ?? 0,
            waterTarget: int.tryParse(_water.text) ?? 0,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection and targets saved locally.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) await showFailure(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _modelField(String label, TextEditingController controller) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Model identifier from LM Studio',
        ),
      ),
      if (_models.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Available models'),
            isExpanded: true,
            items: [
              for (final model in _models)
                DropdownMenuItem(
                  value: model,
                  child: Text(model, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              controller.text = value!;
            },
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        eyebrow: 'connection // on your terms',
        title: 'local intelligence',
        subtitle: 'your models. your records. your machine.',
      ),
      TwoColumns(
        main: MetroCard(
          border: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MicroLabel('lm studio connection', color: FreonColors.teal),
              const SizedBox(height: 20),
              TextField(
                controller: _url,
                enabled: !_testing,
                decoration: const InputDecoration(labelText: 'Server URL'),
                onChanged: (_) => ref.read(connectionProvider.notifier).reset(),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _testing ? null : _test,
                icon: const Icon(Icons.cable),
                label: Text(
                  _testing ? 'Testing connection…' : 'Test connection',
                ),
              ),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    width: double.infinity,
                    color: _connected
                        ? FreonColors.mint
                        : const Color(0xffffdad6),
                    padding: const EdgeInsets.all(16),
                    child: Text(_status!),
                  ),
                ),
              const SizedBox(height: 24),
              _modelField('Text model / chat & reflection', _text),
              const SizedBox(height: 20),
              _modelField('Vision model / photo meals', _vision),
              const SizedBox(height: 12),
              const Text(
                'Choose an image-capable model for photo meals. Freon sends the photo with your caption and returns editable calorie and macro estimates. The text model is used for chat and reflections.',
                style: TextStyle(fontSize: 12, color: FreonColors.muted),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save settings'),
              ),
            ],
          ),
        ),
        aside: MetroCard(
          color: FreonColors.teal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.storage_outlined,
                color: FreonColors.mint,
                size: 36,
              ),
              const SizedBox(height: 24),
              Text(
                'local by design.',
                style: displayStyle(36, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const MicroLabel(
                'sqlite / on this device',
                color: FreonColors.mint,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your meals, journal, and conversations are saved in your application data folder.',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              const MicroLabel(
                'lm studio / your endpoint',
                color: FreonColors.mint,
              ),
              const SizedBox(height: 8),
              const Text(
                'Freon sends conversation context only to the server you configure. The default is this computer.',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Start the Local Server in LM Studio, load a text model, then test the connection here. No account is needed.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      MetroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MicroLabel('local workspace'),
            const SizedBox(height: 12),
            Text('a few personal defaults', style: displayStyle(30)),
            const SizedBox(height: 16),
            TileGrid(
              children: [
                TextField(
                  controller: _calories,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Daily calorie target (kcal)',
                  ),
                ),
                TextField(
                  controller: _water,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Daily water target (ml)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Targets are personal preferences, not medical recommendations. Use Save settings to apply changes.',
              style: TextStyle(fontSize: 12, color: FreonColors.muted),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => runAction(
                    context,
                    () => ref
                        .read(repositoryProvider)
                        .loadSampleDay(ref.read(selectedDayProvider)),
                  ),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('Load sample day'),
                ),
                TextButton(
                  onPressed: () => runAction(
                    context,
                    () => ref.read(repositoryProvider).clearSamples(),
                  ),
                  child: const Text('Clear sample data'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Sample records are explicitly marked. Clearing them preserves your personal entries.',
              style: TextStyle(fontSize: 12, color: FreonColors.muted),
            ),
          ],
        ),
      ),
    ],
  );
}
