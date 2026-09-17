import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/workspace.dart';
import '../state/providers.dart';
import '../state/companion.dart';
import 'components.dart';
import 'dialogs.dart';
import 'photo_meal.dart';
import 'theme.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key, required this.workspace});
  final Workspace workspace;
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  String _filter = 'All metrics';
  @override
  Widget build(BuildContext context) {
    final data = widget.workspace;
    final day = ref.watch(selectedDayProvider);
    final check = data.latestFor(day);
    final calories = data.caloriesFor(day);
    final water = data.waterFor(day);
    final completion = data.completionFor(day);
    final tiles = [
      if (_filter == 'All metrics' || _filter == 'Nutrition')
        MetricTile(
          label: 'Nutrition',
          value: '${calories.round()}',
          detail: 'kcal logged · ${data.mealsFor(day).length} meals',
          icon: Icons.restaurant,
          progress: calories / data.settings.calorieTarget,
          onTap: () =>
              ref.read(navigationProvider.notifier).go(Destination.nutrition),
        ),
      if (_filter == 'All metrics' || _filter == 'Mindset')
        MetricTile(
          label: 'Mindset',
          value: check == null ? 'Not logged' : moodNames[check.mood - 1],
          detail: check == null
              ? 'Make room for a check-in'
              : 'self-reported stress: ${check.stress} / 100',
          icon: Icons.mood,
          color: FreonColors.mint,
          light: true,
          progress: (check?.mood ?? 0) / 5,
          onTap: () => showCheckInEditor(context),
        ),
      if (_filter == 'All metrics' || _filter == 'Hydration')
        MetricTile(
          label: 'Water',
          value: '${(water / 1000).toStringAsFixed(2)} L',
          detail:
              'of ${(data.settings.waterTarget / 1000).toStringAsFixed(1)} L personal target',
          icon: Icons.water_drop_outlined,
          color: FreonColors.primary,
          progress: water / data.settings.waterTarget,
          onTap: () => runAction(
            context,
            () => ref.read(repositoryProvider).addWater(day),
          ),
        ),
      if (_filter == 'All metrics' || _filter == 'Rest')
        MetricTile(
          label: 'Sleep / rest',
          value: check == null
              ? 'Not logged'
              : '${check.sleep.toStringAsFixed(1)} h',
          detail: 'from your latest check-in',
          icon: Icons.bedtime_outlined,
          color: FreonColors.cyan,
          progress: (check?.sleep ?? 0) / 8,
          onTap: () => showCheckInEditor(context),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          eyebrow: 'hub telemetry',
          title: DateFormat('EEEE, MMM d').format(day).toLowerCase(),
          subtitle: 'a little awareness. a steadier daily rhythm.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in [
              'All metrics',
              'Nutrition',
              'Mindset',
              'Hydration',
              'Rest',
            ])
              ChoiceChip(
                label: Text(
                  filter.toUpperCase(),
                  style: labelStyle.copyWith(
                    color: _filter == filter ? Colors.white : FreonColors.muted,
                  ),
                ),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
          ],
        ),
        const SizedBox(height: 24),
        TwoColumns(
          main: Column(
            children: [
              MetroCard(
                color: FreonColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: MicroLabel(
                            'daily balance',
                            color: FreonColors.mint,
                          ),
                        ),
                        Icon(Icons.spa_outlined, color: FreonColors.mint),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$completion',
                          style: displayStyle(60, color: Colors.white),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '/100',
                            style: displayStyle(20, color: FreonColors.mint),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Your day, in view',
                                style: TextStyle(
                                  color: FreonColors.mint,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                'logging completion · not a health score',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: completion / 100,
                      color: FreonColors.mint,
                      backgroundColor: Colors.black12,
                      minHeight: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TileGrid(children: tiles),
              const SizedBox(height: 24),
              MetroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MicroLabel('small moments'),
                    const SizedBox(height: 16),
                    _Moment(
                      icon: Icons.water_drop_outlined,
                      title: 'A glass of water',
                      subtitle: 'Add 250 ml to your local log',
                      action: 'QUICK ADD',
                      onTap: () => runAction(
                        context,
                        () => ref.read(repositoryProvider).addWater(day),
                      ),
                    ),
                    const Divider(height: 28),
                    _Moment(
                      icon: Icons.edit_note,
                      title: 'A thought worth keeping',
                      subtitle: 'Write a note about your day',
                      action: 'CHECK IN',
                      onTap: () => showCheckInEditor(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          aside: Column(
            children: [
              MetroCard(
                border: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: FreonColors.teal,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: MicroLabel(
                            'freon companion',
                            color: FreonColors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'a space to connect the dots.',
                      style: displayStyle(28),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bring your meals, feelings, and small wins into one conversation. Your local companion is here when you are.',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => ref
                            .read(navigationProvider.notifier)
                            .go(Destination.companion),
                        icon: const Icon(Icons.forum_outlined, size: 18),
                        label: const Text('Open companion'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => showPhotoMealEditor(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Log a photo meal'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ReflectionCard(workspace: data),
              const SizedBox(height: 24),
              const BreathingCard(),
              const SizedBox(height: 24),
              MetroCard(
                color: FreonColors.pale,
                padding: 16,
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/inspiration.jpg',
                      width: 64,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MicroLabel(
                            'daily inspiration',
                            color: FreonColors.teal,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Small conscious choices build a steadier tomorrow.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (data.totalRecords == 0)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: EmptyCard(
              title: 'make this space yours',
              message: 'Start with a meal or a check-in, or explore a clearly marked sample day.',
              action: FilledButton(
                onPressed: () => runAction(
                  context,
                  () => ref.read(repositoryProvider).loadSampleDay(day),
                ),
                child: const Text('Load sample day'),
              ),
            ),
          ),
      ],
    );
  }
}

class _Moment extends StatelessWidget {
  const _Moment({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: FreonColors.mint,
          child: Icon(icon, color: FreonColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(
                subtitle,
                style: const TextStyle(color: FreonColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward, color: FreonColors.teal, size: 20),
      ],
    ),
  );
}

class ReflectionCard extends ConsumerWidget {
  const ReflectionCard({super.key, required this.workspace});
  final Workspace workspace;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final summary = workspace.summaryFor(day);
    final state = ref.watch(companionProvider);
    return MetroCard(
      color: FreonColors.pale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MicroLabel('freon / daily reflection', color: FreonColors.teal),
          const SizedBox(height: 12),
          Text(
            summary?.content ?? 'A little distance can bring a little clarity. Reflect on the meals and feelings you have logged today.',
          ),
          if (summary != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Generated with ${summary.model}${summary.includesSample ? ' · includes sample logs' : ''}',
                style: const TextStyle(fontSize: 11, color: FreonColors.muted),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: state.busy
                ? null
                : () => ref.read(companionProvider.notifier).summarize(day),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: Text(
              state.busy
                  ? 'Working…'
                  : summary == null
                  ? 'Reflect on this day'
                  : 'Refresh reflection',
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.error!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
