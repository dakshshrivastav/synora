import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

class MicroLabel extends StatelessWidget {
  const MicroLabel(this.text, {super.key, this.color = FreonColors.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: labelStyle.copyWith(color: color));
}

class MetroCard extends StatelessWidget {
  const MetroCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = 24,
    this.border = false,
  });
  final Widget child;
  final Color color;
  final double padding;
  final bool border;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color,
      border: border
          ? Border.all(color: FreonColors.outline.withValues(alpha: .5))
          : null,
    ),
    child: child,
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String eyebrow, title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MicroLabel(eyebrow, color: FreonColors.teal),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: displayStyle(constraints.maxWidth < 550 ? 36 : 48),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(color: FreonColors.muted),
                    ),
                  ),
              ],
            );
            if (action == null) return heading;
            if (constraints.maxWidth < 700) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 16), action!],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: heading),
                const SizedBox(width: 16),
                action!,
              ],
            );
          },
        ),
      ],
    ),
  );
}

class TwoColumns extends StatelessWidget {
  const TwoColumns({
    super.key,
    required this.main,
    required this.aside,
    this.ratio = 2,
  });
  final Widget main, aside;
  final int ratio;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth < 850) {
        return Column(children: [main, const SizedBox(height: 24), aside]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: ratio, child: main),
          const SizedBox(width: 24),
          Expanded(child: aside),
        ],
      );
    },
  );
}

class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.columns = 2});
  final List<Widget> children;
  final int columns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final count = box.maxWidth < 320 ? 1 : columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children)
            SizedBox(
              width: (box.maxWidth - 12 * (count - 1)) / count,
              child: child,
            ),
        ],
      );
    },
  );
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.color = FreonColors.teal,
    this.light = false,
    this.progress,
    this.onTap,
  });
  final String label, value, detail;
  final IconData icon;
  final Color color;
  final bool light;
  final double? progress;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final foreground = light ? FreonColors.primary : Colors.white;
    final accent = light ? FreonColors.teal : FreonColors.mint;
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: MicroLabel(label, color: accent)),
                  Icon(icon, size: 19, color: accent),
                ],
              ),
              const SizedBox(height: 28),
              Text(value, style: displayStyle(34, color: foreground)),
              const SizedBox(height: 6),
              Text(
                detail,
                style: TextStyle(
                  color: foreground.withValues(alpha: .8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              LinearProgressIndicator(
                value: progress?.clamp(0, 1) ?? 0,
                minHeight: 4,
                color: accent,
                backgroundColor: foreground.withValues(alpha: .12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.spa_outlined,
  });
  final String title, message;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => MetroCard(
    color: FreonColors.pale,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: FreonColors.teal, size: 30),
        const SizedBox(height: 16),
        Text(title, style: displayStyle(28)),
        const SizedBox(height: 8),
        Text(message),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 16), child: action!),
      ],
    ),
  );
}

Future<void> showFailure(BuildContext context, Object error) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
  );
}

Future<void> runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) await showFailure(context, error);
  }
}

class BreathingCard extends StatefulWidget {
  const BreathingCard({super.key});
  @override
  State<BreathingCard> createState() => _BreathingCardState();
}

class _BreathingCardState extends State<BreathingCard> {
  Timer? _timer;
  int _elapsed = 0;
  bool _running = false;
  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_elapsed >= 64) _elapsed = 0;
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed++;
        if (_elapsed >= 64) {
          _running = false;
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MetroCard(
    color: FreonColors.mint,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MicroLabel('a moment to pause', color: FreonColors.primary),
        const SizedBox(height: 12),
        Text(
          'find your rhythm',
          style: displayStyle(30, color: FreonColors.primary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Four gentle rounds. Breathe at a pace that feels comfortable.',
        ),
        const SizedBox(height: 20),
        MetroCard(
          padding: 16,
          child: Row(
            children: [
              const Icon(Icons.air, color: FreonColors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _elapsed >= 64
                      ? 'Session complete'
                      : _running
                      ? [
                          'Breathe in',
                          'Hold gently',
                          'Breathe out',
                          'Rest',
                        ][(_elapsed ~/ 4) % 4]
                      : _elapsed == 0
                      ? 'Box breathing'
                      : 'Paused',
                ),
              ),
              Text(
                '${(64 - _elapsed) ~/ 60}:${((64 - _elapsed) % 60).toString().padLeft(2, '0')}',
                style: displayStyle(24),
              ),
            ],
          ),
        ),
        LinearProgressIndicator(value: _elapsed / 64, minHeight: 3),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _toggle,
            icon: Icon(_running ? Icons.pause : Icons.play_arrow),
            label: Text(
              _running
                  ? 'Pause breathing'
                  : _elapsed >= 64
                  ? 'Start again'
                  : _elapsed > 0
                  ? 'Resume breathing'
                  : 'Start breathing',
            ),
          ),
        ),
      ],
    ),
  );
}
