import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'state/providers.dart';
import 'ui/components.dart';
import 'ui/dashboard.dart';
import 'ui/nutrition.dart';
import 'ui/mindset.dart';
import 'ui/chat.dart';
import 'ui/settings.dart';
import 'ui/theme.dart';

class FreonApp extends StatelessWidget {
  const FreonApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Freon',
    debugShowCheckedModeBanner: false,
    theme: freonTheme(),
    home: const FreonShell(),
  );
}

class FreonShell extends ConsumerWidget {
  const FreonShell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(navigationProvider);
    final workspace = ref.watch(workspaceProvider);
    final day = ref.watch(selectedDayProvider);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1000;
            return Row(
              children: [
                _Sidebar(compact: compact),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        color: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 16 : 32,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.blur_on,
                              color: FreonColors.teal,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: MicroLabel(
                                'freon / personal workspace',
                                color: FreonColors.teal,
                              ),
                            ),
                            if (constraints.maxWidth > 700)
                              const Padding(
                                padding: EdgeInsets.only(right: 18),
                                child: Text('LOCAL-FIRST', style: labelStyle),
                              ),
                            const Icon(
                              Icons.storage_outlined,
                              size: 16,
                              color: FreonColors.teal,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: workspace.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) => Center(
                            child: SizedBox(
                              width: 480,
                              child: EmptyCard(
                                title: 'Could not open your workspace',
                                message:
                                    'Your local database could not be read. Check available disk space and permissions.\n$error',
                                action: FilledButton(
                                  onPressed: () =>
                                      ref.invalidate(workspaceProvider),
                                  child: const Text('Retry'),
                                ),
                              ),
                            ),
                          ),
                          data: (data) => Column(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 16 : 32,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: data.sampleFor(day)
                                          ? const MicroLabel(
                                              'includes sample data',
                                              color: FreonColors.teal,
                                            )
                                          : const MicroLabel(
                                              'your data, on your device',
                                            ),
                                    ),
                                    IconButton(
                                      tooltip: 'Previous day',
                                      onPressed: () => ref
                                          .read(selectedDayProvider.notifier)
                                          .move(-1),
                                      icon: const Icon(
                                        Icons.chevron_left,
                                        size: 20,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => ref
                                          .read(selectedDayProvider.notifier)
                                          .today(),
                                      child: Text(
                                        DateFormat('MMM d, yyyy').format(day),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Next day',
                                      onPressed: () => ref
                                          .read(selectedDayProvider.notifier)
                                          .move(1),
                                      icon: const Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: destination == Destination.companion
                                    ? ChatPage(workspace: data)
                                    : SingleChildScrollView(
                                        key: PageStorageKey(destination),
                                        padding: EdgeInsets.fromLTRB(
                                          compact ? 16 : 32,
                                          16,
                                          compact ? 16 : 32,
                                          32,
                                        ),
                                        child: Align(
                                          alignment: Alignment.topCenter,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 1200,
                                            ),
                                            child: switch (destination) {
                                              Destination.dashboard =>
                                                DashboardPage(workspace: data),
                                              Destination.nutrition =>
                                                NutritionPage(workspace: data),
                                              Destination.mindset =>
                                                MindsetPage(workspace: data),
                                              Destination.connection =>
                                                SettingsPage(workspace: data),
                                              Destination.companion =>
                                                const SizedBox.shrink(),
                                            },
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.compact});
  final bool compact;
  static const items = [
    (Destination.dashboard, 'Dashboard', Icons.grid_view_outlined),
    (Destination.companion, 'Companion', Icons.forum_outlined),
    (Destination.nutrition, 'Nutrition', Icons.restaurant_outlined),
    (Destination.mindset, 'Mindset', Icons.spa_outlined),
    (Destination.connection, 'Connection', Icons.tune_outlined),
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    width: compact ? 72 : 208,
    color: FreonColors.primary,
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 24,
            vertical: 28,
          ),
          child: Row(
            children: [
              const Icon(Icons.blur_on, color: FreonColors.mint, size: 32),
              if (!compact) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('freon', style: displayStyle(32, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(
                      'YOUR DAILY RHYTHM',
                      style: labelStyle.copyWith(
                        fontSize: 8,
                        color: FreonColors.mint,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 16),
        for (final (destination, title, icon) in items)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Tooltip(
              message: title,
              child: Material(
                color: ref.watch(navigationProvider) == destination
                    ? FreonColors.teal
                    : Colors.transparent,
                child: InkWell(
                  key: ValueKey('nav-${destination.name}'),
                  onTap: () =>
                      ref.read(navigationProvider.notifier).go(destination),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 14 : 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: ref.watch(navigationProvider) == destination
                              ? FreonColors.mint
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: FreonColors.mint),
                        if (!compact) ...[
                          const SizedBox(width: 14),
                          Text(
                            title.toUpperCase(),
                            style: labelStyle.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        Padding(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Row(
            children: [
              const Icon(Icons.person_outline, color: FreonColors.mint),
              if (!compact) ...[
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal space',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Stored on this device',
                        style: TextStyle(color: FreonColors.mint, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
