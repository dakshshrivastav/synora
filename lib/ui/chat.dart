import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/workspace.dart';
import '../state/companion.dart';
import '../state/providers.dart';
import 'components.dart';
import 'dialogs.dart';
import 'theme.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.workspace});
  final Workspace workspace;
  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    if (_input.text.trim().isEmpty || ref.read(companionProvider).busy) return;
    if (widget.workspace.settings.textModel.isEmpty) {
      showFailure(context, 'Choose a text model in Connection settings first.');
      return;
    }
    final message = _input.text;
    if (message.length > 8000) {
      showFailure(context, 'Keep messages under 8,000 characters.');
      return;
    }
    _input.clear();
    ref.read(companionProvider.notifier).send(message);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.workspace;
    final state = ref.watch(companionProvider);
    final day = ref.watch(selectedDayProvider);
    ref.listen(companionProvider, (_, next) {
      if (_scroll.hasClients && _scroll.position.extentAfter < 150) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    });
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        children: [
          PageHeading(
            eyebrow: 'freon companion',
            title: 'let’s make space.',
            action: TextButton.icon(
              onPressed: state.busy || data.messages.isEmpty
                  ? null
                  : () async {
                      final clear = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear this conversation?'),
                          content: const Text(
                            'Meals and journal entries will stay in your workspace.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Keep conversation'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Clear conversation'),
                            ),
                          ],
                        ),
                      );
                      if (clear == true && context.mounted) {
                        await runAction(
                          context,
                          () =>
                              ref.read(repositoryProvider).clearConversation(),
                        );
                      }
                    },
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('New conversation'),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          color: FreonColors.pale,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.dns_outlined,
                                color: FreonColors.teal,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  data.settings.textModel.isEmpty
                                      ? 'LM Studio model not configured'
                                      : 'MODEL / ${data.settings.textModel}',
                                  style: labelStyle,
                                ),
                              ),
                              TextButton(
                                onPressed: () => ref
                                    .read(navigationProvider.notifier)
                                    .go(Destination.connection),
                                child: const Text('Configure'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: data.messages.isEmpty
                              ? SingleChildScrollView(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: EmptyCard(
                                    title: 'hello, I’m Freon.',
                                    message: 'A little space to think out loud. Tell me about your day, your lunch, or whatever is on your mind.\n\nConnect a model in LM Studio to start a real conversation.',
                                    icon: Icons.auto_awesome,
                                    action: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final prompt in [
                                          'Help me reflect on today',
                                          'How can I build a gentler routine?',
                                        ])
                                          OutlinedButton(
                                            onPressed: () {
                                              _input.text = prompt;
                                            },
                                            child: Text(prompt),
                                          ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scroll,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                  ),
                                  itemCount: data.messages.length,
                                  itemBuilder: (context, index) {
                                    final message = data.messages[index];
                                    final user = message.role == 'user';
                                    final live = state.messageId == message.id;
                                    final text = live
                                        ? state.partial
                                        : message.content;
                                    return Align(
                                      alignment: user
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              box.maxWidth *
                                              (box.maxWidth > 850 ? .55 : .9),
                                        ),
                                        margin: const EdgeInsets.only(
                                          bottom: 20,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: user
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                          children: [
                                            MicroLabel(
                                              '${user ? 'you' : 'freon companion'} / ${DateFormat('HH:mm').format(message.createdAt)}',
                                              color: user
                                                  ? FreonColors.muted
                                                  : FreonColors.teal,
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(18),
                                              color: user
                                                  ? FreonColors.primary
                                                  : Colors.white,
                                              child: SelectableText(
                                                text.isEmpty
                                                    ? state.busy
                                                          ? 'Thinking…'
                                                          : 'No response received.'
                                                    : text,
                                                style: TextStyle(
                                                  color: user
                                                      ? Colors.white
                                                      : FreonColors.ink,
                                                  height: 1.6,
                                                ),
                                              ),
                                            ),
                                            if ([
                                                  'failed',
                                                  'cancelled',
                                                ].contains(message.status) &&
                                                !live)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 6,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      message.error ?? 'Generation cancelled.',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .error,
                                                      ),
                                                    ),
                                                    if (index ==
                                                        data.messages.length -
                                                            1)
                                                      TextButton.icon(
                                                        onPressed: state.busy
                                                            ? null
                                                            : () => ref
                                                                  .read(
                                                                    companionProvider
                                                                        .notifier,
                                                                  )
                                                                  .send(
                                                                    'retry',
                                                                    retry:
                                                                        message,
                                                                  ),
                                                        icon: const Icon(
                                                          Icons.refresh,
                                                          size: 16,
                                                        ),
                                                        label: const Text(
                                                          'Retry response',
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (state.error != null)
                          Container(
                            width: double.infinity,
                            color: const Color(0xffffdad6),
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              state.error!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Log a meal with a photo',
                                onPressed: () => showMealEditor(context),
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: FreonColors.teal,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  minLines: 1,
                                  maxLines: 4,
                                  maxLength: 8000,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _send(),
                                  decoration: const InputDecoration(
                                    hintText: 'Talk to Freon…',
                                    counterText: '',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton.filled(
                                tooltip: state.busy
                                    ? 'Stop generation'
                                    : 'Send message',
                                style: IconButton.styleFrom(
                                  backgroundColor: FreonColors.mint,
                                  foregroundColor: FreonColors.primary,
                                ),
                                onPressed: state.busy
                                    ? () => ref
                                          .read(companionProvider.notifier)
                                          .cancel()
                                    : _send,
                                icon: Icon(
                                  state.busy ? Icons.stop : Icons.arrow_upward,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'A reflective companion, not a medical professional. AI responses can be inaccurate.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: FreonColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (box.maxWidth > 950) ...[
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 280,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            MetroCard(
                              color: FreonColors.teal,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const MicroLabel(
                                    'today in context',
                                    color: FreonColors.mint,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    '${data.caloriesFor(day).round()}',
                                    style: displayStyle(
                                      40,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const MicroLabel(
                                    'kcal logged',
                                    color: FreonColors.mint,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    '${data.waterFor(day)} ml water',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    data.latestFor(day) == null
                                        ? 'No mood check-in yet'
                                        : 'Feeling ${moodNames[data.latestFor(day)!.mood - 1].toLowerCase()}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  if (data.sampleFor(day))
                                    const Padding(
                                      padding: EdgeInsets.only(top: 16),
                                      child: MicroLabel(
                                        'includes sample logs',
                                        color: FreonColors.mint,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const BreathingCard(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
