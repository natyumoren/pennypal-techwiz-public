import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../data/repositories/engagement_repository.dart';
import '../../services/chatbot_service.dart';
import '../../state/finance_state.dart';
import '../../widgets/common.dart';

/// "Ask Penny" – budgeting chatbot (Gemini with offline fallback).
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _service = ChatbotService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[
    const ChatMessage(
        'Hi! I\'m Penny 🐝 your budgeting coach. Ask me about your spending, '
        'budgets or how to save more.'),
  ];
  bool _thinking = false;
  bool? _enabled;

  static const suggestions = [
    'How am I doing this month?',
    'Where does my money go?',
    'How can I save more?',
    'Help me plan a budget',
    'Needs vs wants?',
  ];

  @override
  void initState() {
    super.initState();
    context.read<EngagementRepository>().settings().then((s) {
      if (mounted) setState(() => _enabled = s['chatbot_enabled'] != '0');
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _thinking) return;
    final ctx = context.read<FinanceState>().chatContext();
    final history = List<ChatMessage>.from(_messages.skip(1));
    setState(() {
      _messages.add(ChatMessage(text, fromUser: true));
      _thinking = true;
      _input.clear();
    });
    _scrollDown();
    final reply = await _service.ask(text, history, ctx);
    if (!mounted) return;
    setState(() {
      _messages.add(reply);
      _thinking = false;
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_enabled == false) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ask Penny')),
        body: const EmptyState(
            icon: Icons.smart_toy_outlined,
            title: 'Chatbot unavailable',
            message: 'The administrator has temporarily turned off the assistant. Check the Learning hub for tips.'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask Penny'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(AppConfig.aiEnabled ? Icons.auto_awesome : Icons.rule, size: 16),
              label: Text(AppConfig.aiEnabled ? 'Gemini AI' : 'Offline tips'),
            ),
          ),
        ],
      ),
      body: ResponsiveBody(
        maxWidth: 800,
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: cs.secondaryContainer.withValues(alpha: 0.4),
            child: const Text(
              'Penny gives educational guidance only – not professional financial advice.',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) return const _TypingBubble();
                return _Bubble(message: _messages[i]);
              },
            ),
          ),
          if (_messages.length <= 2)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final s in suggestions)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(label: Text(s), onPressed: () => _send(s)),
                    ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask about budgeting or saving...',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: _thinking ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mine = message.fromUser;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: mine ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(message.text,
              style: TextStyle(color: mine ? cs.onPrimary : cs.onSurface, height: 1.4)),
          if (!mine && message.fromAi)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('✨ AI-generated · educational only',
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ),
        ]),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Penny is thinking...'),
          ]),
        ),
      );
}
