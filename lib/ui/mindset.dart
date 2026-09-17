import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/workspace.dart';
import '../state/providers.dart';
import 'components.dart';
import 'dashboard.dart';
import 'dialogs.dart';
import 'theme.dart';

class MindsetPage extends ConsumerWidget {
  const MindsetPage({super.key, required this.workspace});
  final Workspace workspace;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final check = workspace.latestFor(day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          eyebrow: 'your inner rhythm',
          title: 'mindset & wellness',
          subtitle: 'a gentle check-in, on your own terms.',
          action: FilledButton.icon(
            onPressed: () => showCheckInEditor(context),
            icon: const Icon(Icons.add_reaction_outlined),
            label: const Text('Check in with Freon'),
          ),
        ),
        TwoColumns(
          main: Column(
            children: [
              MetroCard(
                color: const Color(0xff00897b),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MicroLabel(
                      'state hub / self-reported',
                      color: FreonColors.mint,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      check == null
                          ? 'a fresh start'
                          : moodNames[check.mood - 1].toLowerCase(),
                      style: displayStyle(48, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      check == null
                          ? 'No check-in for this day yet.'
                          : '${check.mood} / 5 · your latest mood check-in',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 28),
                    const MicroLabel(
                      'seven-day mood rhythm',
                      color: FreonColors.mint,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 112,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 6; i >= 0; i--)
                            Expanded(
                              child: Builder(
                                builder: (_) {
                                  final date = DateTime(
                                    day.year,
                                    day.month,
                                    day.day - i,
                                  );
                                  final mood = workspace.latestFor(date)?.mood;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          mood?.toString() ?? '—',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          height: (mood ?? 0) * 14.0 + 2,
                                          color: i == 0
                                              ? FreonColors.mint
                                              : FreonColors.mint.withValues(
                                                  alpha: .4,
                                                ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          DateFormat('E')
                                              .format(date)
                                              .substring(0, 1),
                                          style: labelStyle.copyWith(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: MicroLabel('four points of awareness'),
              ),
              const SizedBox(height: 12),
              TileGrid(
                children: [
                  MetricTile(
                    label: 'Stress',
                    value: check == null ? '—' : '${check.stress}%',
                    detail: 'self-reported',
                    icon: Icons.favorite_border,
                    color: FreonColors.surface,
                    light: true,
                    progress: (check?.stress ?? 0) / 100,
                  ),
                  MetricTile(
                    label: 'Energy',
                    value: check == null ? '—' : '${check.energy}%',
                    detail: 'self-reported',
                    icon: Icons.bolt,
                    color: FreonColors.surface,
                    light: true,
                    progress: (check?.energy ?? 0) / 100,
                  ),
                  MetricTile(
                    label: 'Sleep',
                    value: check == null ? '—' : '${check.sleep} h',
                    detail: 'hours entered',
                    icon: Icons.bedtime_outlined,
                    color: FreonColors.pale,
                    light: true,
                    progress: (check?.sleep ?? 0) / 8,
                  ),
                  MetricTile(
                    label: 'Social battery',
                    value: check == null ? '—' : '${check.social}%',
                    detail: 'self-reported',
                    icon: Icons.forum_outlined,
                    color: FreonColors.pale,
                    light: true,
                    progress: (check?.social ?? 0) / 100,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (workspace.checkInsFor(day).isEmpty)
                const EmptyCard(
                  title: 'a place for your thoughts',
                  message: 'Your journal starts with a single sentence. There is no right way to feel today.',
                ),
              for (final entry in workspace.checkInsFor(day))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MetroCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: MicroLabel(
                                'journal / ${DateFormat('HH:mm').format(entry.createdAt)}${entry.sample ? ' / sample' : ''}',
                                color: FreonColors.teal,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit check-in',
                              onPressed: () =>
                                  showCheckInEditor(context, check: entry),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                            ),
                            IconButton(
                              tooltip: 'Delete check-in',
                              onPressed: () => runAction(
                                context,
                                () => ref
                                    .read(repositoryProvider)
                                    .deleteCheckIn(entry),
                              ),
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.note.isEmpty
                              ? 'A quiet check-in. No note added.'
                              : entry.note,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          aside: Column(
            children: [
              ReflectionCard(workspace: workspace),
              const SizedBox(height: 24),
              const BreathingCard(),
              const SizedBox(height: 24),
              MetroCard(
                padding: 0,
                color: FreonColors.pale,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/courtyard.jpg',
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MicroLabel(
                            'environmental anchor',
                            color: FreonColors.teal,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'A quieter corner. A slower breath. A little space to be yourself.',
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
      ],
    );
  }
}
