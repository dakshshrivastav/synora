import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/workspace.dart';
import '../state/providers.dart';
import 'components.dart';
import 'dialogs.dart';
import 'photo_meal.dart';
import 'theme.dart';

class NutritionPage extends ConsumerWidget {
  const NutritionPage({super.key, required this.workspace});
  final Workspace workspace;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final meals = workspace.mealsFor(day);
    final calories = workspace.caloriesFor(day);
    double sum(double Function(Meal) get) =>
        meals.fold(0, (total, meal) => total + get(meal));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          eyebrow: 'telemetry // intake',
          title: 'nutrition & macros',
          subtitle: 'a clear view of what fuels your day.',
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => showMealEditor(context),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Log a meal'),
              ),
              FilledButton.icon(
                onPressed: () => showPhotoMealEditor(context),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Photo meal'),
              ),
            ],
          ),
        ),
        TwoColumns(
          main: Column(
            children: [
              MetroCard(
                color: FreonColors.teal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MicroLabel(
                      'consumed energy',
                      color: FreonColors.mint,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        Text(
                          '${calories.round()}',
                          style: displayStyle(60, color: Colors.white),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: MicroLabel('kcal', color: FreonColors.mint),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Personal target ${workspace.settings.calorieTarget}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    for (final (label, value, color) in [
                      ('Carbohydrates', sum((m) => m.carbs), FreonColors.mint),
                      ('Protein', sum((m) => m.protein), FreonColors.ice),
                      (
                        'Dietary fats',
                        sum((m) => m.fat),
                        const Color(0xffa0f2e1),
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: MicroLabel(label, color: color),
                                ),
                                Text(
                                  '${value.toStringAsFixed(1)} g',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value:
                                  value /
                                  ((sum((m) => m.carbs + m.protein + m.fat)) ==
                                          0
                                      ? 1
                                      : sum(
                                          (m) => m.carbs + m.protein + m.fat,
                                        )),
                              color: color,
                              backgroundColor: Colors.white12,
                              minHeight: 6,
                            ),
                          ],
                        ),
                      ),
                    const Text(
                      'Bars show each macro’s share of logged grams.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: MicroLabel('meal log modules')),
                  Text(
                    '${meals.length} entries',
                    style: const TextStyle(color: FreonColors.teal),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TileGrid(
                children: [
                  for (var index = 0; index < mealKinds.length; index++)
                    Builder(
                      builder: (_) {
                        final kind = mealKinds[index];
                        final entries = meals
                            .where((m) => m.kind == kind)
                            .toList();
                        return MetricTile(
                          label:
                              '${(index + 1).toString().padLeft(2, '0')} // $kind',
                          value: entries.isEmpty
                              ? '+ log ${kind.toLowerCase()}'
                              : '${entries.fold(0.0, (s, m) => s + m.calories).round()} kcal',
                          detail: entries.isEmpty
                              ? 'Add your first entry'
                              : entries.map((m) => m.title).join(' · '),
                          icon: [
                            Icons.bakery_dining,
                            Icons.lunch_dining,
                            Icons.dinner_dining,
                            Icons.eco_outlined,
                          ][index],
                          color: [
                            FreonColors.secondary,
                            FreonColors.primary,
                            FreonColors.surface,
                            FreonColors.mint,
                          ][index],
                          light: index > 1,
                          onTap: () => showMealEditor(context, kind: kind),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (meals.isEmpty)
                const EmptyCard(
                  title: 'your first bite',
                  message:
                      'Add a meal to see your daily calories and macros here.',
                  icon: Icons.restaurant_outlined,
                ),
              for (final meal in meals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MetroCard(
                    padding: 16,
                    child: Row(
                      children: [
                        if (meal.imagePath != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: SizedBox(
                              width: 84,
                              height: 84,
                              child: meal.imagePath!.startsWith('assets/')
                                  ? Image.asset(
                                      meal.imagePath!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(meal.imagePath!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.broken_image_outlined,
                                      ),
                                    ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MicroLabel(
                                '${meal.kind} / ${meal.sample ? 'sample data' : meal.source}',
                                color: FreonColors.teal,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                meal.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${meal.calories.round()} kcal · P ${meal.protein.round()}g  C ${meal.carbs.round()}g  F ${meal.fat.round()}g',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: FreonColors.muted,
                                ),
                              ),
                              if (meal.notes.isNotEmpty)
                                Text(
                                  meal.notes,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Meal actions',
                          onSelected: (v) {
                            if (v == 'edit') {
                              showMealEditor(context, meal: meal);
                            } else {
                              runAction(
                                context,
                                () => ref
                                    .read(repositoryProvider)
                                    .deleteMeal(meal),
                              );
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit meal'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete meal'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          aside: Column(
            children: [
              HydrationCard(workspace: workspace),
              const SizedBox(height: 24),
              MetroCard(
                color: FreonColors.pale,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MicroLabel('micronutrients', color: FreonColors.teal),
                    const SizedBox(height: 8),
                    Text('the finer details', style: displayStyle(28)),
                    const SizedBox(height: 16),
                    for (final nutrient in [
                      'Sodium',
                      'Dietary fiber',
                      'Sugars',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: MetroCard(
                          padding: 12,
                          child: Row(
                            children: [
                              Expanded(child: Text(nutrient)),
                              const Text(
                                'Not recorded',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: FreonColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const Text(
                      'Micronutrients need a reliable label or data source. Freon does not infer them from calories.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              MetroCard(
                padding: 0,
                color: FreonColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/salmon.jpg',
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MicroLabel(
                            'meal inspiration / sample',
                            color: FreonColors.teal,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'something fresh for tonight',
                            style: displayStyle(28),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Salmon, greens, and a moment to slow down. Log your own portion and nutrition values.',
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () =>
                                showMealEditor(context, kind: 'Dinner'),
                            child: const Text('Log your dinner'),
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

class HydrationCard extends ConsumerWidget {
  const HydrationCard({super.key, required this.workspace});
  final Workspace workspace;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final volume = workspace.waterFor(day);
    final count = volume ~/ 250;
    final repo = ref.read(repositoryProvider);
    return MetroCard(
      color: FreonColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MicroLabel('hydration matrix', color: FreonColors.ice),
          const SizedBox(height: 12),
          Text('water intake', style: displayStyle(30, color: Colors.white)),
          const SizedBox(height: 12),
          Text('$volume ml', style: displayStyle(38, color: FreonColors.ice)),
          Text(
            'of ${workspace.settings.waterTarget} ml personal target',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              for (var i = 0; i < 8; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 7 ? 0 : 5),
                    child: Tooltip(
                      message: i < count ? 'Undo last 250 ml' : 'Add 250 ml',
                      child: Material(
                        color: i < count ? FreonColors.ice : Colors.white12,
                        child: InkWell(
                          onTap: () => runAction(
                            context,
                            () => i < count
                                ? repo.undoWater(day)
                                : repo.addWater(day),
                          ),
                          child: SizedBox(
                            height: 44,
                            child: Icon(
                              Icons.water_drop_outlined,
                              size: 16,
                              color: i < count
                                  ? FreonColors.cyan
                                  : Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$count glasses logged',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: FreonColors.ice,
                  foregroundColor: FreonColors.primary,
                ),
                onPressed: () => runAction(context, () => repo.addWater(day)),
                child: const Text('+ 250 ml'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: count == 0
                    ? null
                    : () => runAction(context, () => repo.undoWater(day)),
                child: const Text('Undo last'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
