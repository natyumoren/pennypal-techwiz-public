import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';

/// Snapshot of the student's finances given to the chatbot so answers can
/// be personal. Only aggregated figures are shared – never raw records,
/// names or contact details (privacy NFR).
class ChatContext {
  final String currency;
  final double monthIncome;
  final double monthExpense;
  final Map<String, double> topCategories; // name -> amount this month
  final List<String> budgetLines; // "Food: 83.65 of 100.00 (84%)"
  final List<String> goalLines; // "New laptop: 320 of 900, 75/month"

  const ChatContext({
    required this.currency,
    required this.monthIncome,
    required this.monthExpense,
    required this.topCategories,
    required this.budgetLines,
    required this.goalLines,
  });

  String describe() => [
        'Currency: $currency',
        'This month income: ${monthIncome.toStringAsFixed(2)}',
        'This month expenses: ${monthExpense.toStringAsFixed(2)}',
        if (topCategories.isNotEmpty)
          'Top spending categories this month: ${topCategories.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(2)}').join(', ')}',
        if (budgetLines.isNotEmpty) 'Budgets: ${budgetLines.join('; ')}',
        if (goalLines.isNotEmpty) 'Savings goals: ${goalLines.join('; ')}',
      ].join('\n');
}

class ChatMessage {
  final String text;
  final bool fromUser;
  final bool fromAi; // false = offline rule-based answer
  const ChatMessage(this.text, {this.fromUser = false, this.fromAi = false});
}

/// Budgeting assistant. Uses Google Gemini (API key from Google AI Studio)
/// when configured, and falls back to [RuleBasedAdvisor] when there is no
/// key, no network, the call fails or it takes longer than
/// [AppConfig.aiTimeout].
class ChatbotService {
  ChatbotService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const systemPrompt =
      'You are Penny, the friendly budgeting coach inside PennyPal, an app '
      'that helps students track expenses, budgets and savings goals. '
      'Give short (under 120 words), practical, beginner-friendly answers '
      'about budgeting, saving, income and spending habits, using the '
      'student\'s data when it helps. You only give educational guidance: '
      'never recommend specific investments, stocks, crypto, loans or '
      'financial products, never ask for bank or card details, and remind '
      'the student to talk to a qualified adviser for serious decisions. '
      'If a question is not about personal money management, politely steer '
      'back to budgeting.';

  Future<ChatMessage> ask(
      String question, List<ChatMessage> history, ChatContext context) async {
    if (!AppConfig.aiEnabled) {
      return ChatMessage(RuleBasedAdvisor.answer(question, context));
    }
    try {
      final text = await _gemini(question, history, context)
          .timeout(AppConfig.aiTimeout);
      return ChatMessage(text, fromAi: true);
    } catch (_) {
      // Fail gracefully: timeout, offline, quota or bad key.
      return ChatMessage(RuleBasedAdvisor.answer(question, context));
    }
  }

  Future<String> _gemini(
      String question, List<ChatMessage> history, ChatContext context) async {
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${AppConfig.geminiModel}:generateContent');
    final recent = history.length > 8 ? history.sublist(history.length - 8) : history;
    final body = {
      'system_instruction': {
        'parts': [
          {'text': '$systemPrompt\n\nStudent data:\n${context.describe()}'}
        ]
      },
      'contents': [
        for (final m in recent)
          {
            'role': m.fromUser ? 'user' : 'model',
            'parts': [
              {'text': m.text}
            ]
          },
        {
          'role': 'user',
          'parts': [
            {'text': question}
          ]
        },
      ],
      'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 400},
    };
    final res = await _client.post(uri,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': AppConfig.geminiApiKey,
        },
        body: jsonEncode(body));
    if (res.statusCode != 200) {
      throw http.ClientException('Gemini error ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final parts = (json['candidates'] as List?)?.firstOrNull?['content']
        ?['parts'] as List?;
    final text = parts
        ?.map((p) => (p as Map)['text'] as String? ?? '')
        .join()
        .trim();
    if (text == null || text.isEmpty) throw const FormatException('Empty reply');
    return text;
  }
}

/// Offline advisor: keyword intents answered with the student's own numbers.
class RuleBasedAdvisor {
  RuleBasedAdvisor._();

  static bool _has(String q, List<String> words) => words.any(q.contains);

  static String answer(String question, ChatContext c) {
    final q = question.toLowerCase();
    String m(double v) => '${c.currency} ${v.toStringAsFixed(2)}';
    final balance = c.monthIncome - c.monthExpense;

    if (_has(q, ['invest', 'stock', 'crypto', 'bitcoin', 'shares', 'forex', 'loan', 'borrow', 'credit card', 'trading'])) {
      return 'I can only share general budgeting tips, so I can\'t recommend '
          'investments, loans or financial products. A good first step is to '
          'build an emergency fund and keep your spending under your income. '
          'For investment or borrowing decisions, please talk to a qualified '
          'financial adviser or your school\'s financial aid office.';
    }
    if (_has(q, ['hello', 'hi ', 'hey', 'good morning', 'good evening']) || q.trim() == 'hi') {
      return 'Hi! I\'m Penny, your budgeting coach. Ask me things like '
          '"How am I doing this month?", "How can I save more?" or '
          '"Where does my money go?"';
    }
    for (final entry in c.topCategories.entries) {
      if (q.contains(entry.key.toLowerCase())) {
        final share = c.monthExpense == 0 ? 0 : entry.value / c.monthExpense * 100;
        return 'This month you have spent ${m(entry.value)} on ${entry.key}, '
            'about ${share.round()}% of your expenses. '
            '${share > 35 ? 'That is a big share – try setting a category limit in Budgets so PennyPal warns you early.' : 'That looks balanced. Keep recording each purchase to stay on top of it.'}';
      }
    }
    if (_has(q, ['where', 'most', 'biggest', 'spend on', 'spending'])) {
      if (c.topCategories.isEmpty) {
        return 'You have no expenses recorded this month yet. Add them from '
            'the dashboard and I\'ll show you where your money goes.';
      }
      final lines = c.topCategories.entries
          .take(3)
          .map((e) => '• ${e.key}: ${m(e.value)}')
          .join('\n');
      return 'Your top spending categories this month:\n$lines\n\n'
          'Look at the biggest one first – small cuts there make the largest difference.';
    }
    if (_has(q, ['doing', 'status', 'summary', 'month', 'balance', 'left', 'overview'])) {
      final budgets = c.budgetLines.isEmpty
          ? 'You have not set a budget yet – create one in Budgets to get alerts.'
          : 'Budgets: ${c.budgetLines.join('; ')}.';
      return 'This month you received ${m(c.monthIncome)} and spent '
          '${m(c.monthExpense)}, leaving ${m(balance)}. $budgets';
    }
    if (_has(q, ['over budget', 'overspend', 'overspent', 'too much', 'broke', 'out of money'])) {
      return 'If you are overspending:\n'
          '1. Check Transaction History for this month and spot repeated small buys.\n'
          '2. Separate needs (food, transport, books) from wants (takeaway, shopping).\n'
          '3. Set category limits in Budgets with an 80% alert.\n'
          '4. Try a "no-spend" day or two each week.\n'
          'Small changes add up quickly!';
    }
    if (_has(q, ['goal', 'target', 'laptop', 'trip', 'buy'])) {
      if (c.goalLines.isEmpty) {
        return 'Create a savings goal in the Goals tab with a target amount and '
            'date – PennyPal will work out how long it will take and track your progress.';
      }
      return 'Your goals: ${c.goalLines.join('; ')}. Adding even a small '
          'amount each week keeps you on schedule. Consider automating a '
          'transfer on the day your allowance arrives.';
    }
    if (_has(q, ['save', 'saving', 'savings', 'emergency'])) {
      final suggestion = c.monthIncome > 0 ? m(c.monthIncome * 0.1) : 'a small fixed amount';
      return 'Try "pay yourself first": move $suggestion (about 10% of your '
          'income) into a savings goal as soon as you get paid. Build an '
          'emergency fund of one month\'s expenses first, then save for '
          'bigger goals.';
    }
    if (_has(q, ['budget', '50/30/20', 'plan', 'allocate'])) {
      final base = c.monthIncome > 0 ? c.monthIncome : 0;
      if (base > 0) {
        return 'Using the 50/30/20 guide on your income of ${m(base.toDouble())}: '
            'needs ${m(base * .5)}, wants ${m(base * .3)}, savings ${m(base * .2)}. '
            'Adjust it to your situation, then set it in Budgets.';
      }
      return 'A simple plan is 50/30/20: 50% needs, 30% wants, 20% savings. '
          'Record your income first so I can calculate the amounts for you.';
    }
    if (_has(q, ['income', 'earn', 'job', 'money more', 'side'])) {
      return 'Ideas for students: tutoring, campus jobs, freelancing your '
          'skills (design, writing, coding) or selling items you no longer use. '
          'Record every income in PennyPal and save part of any irregular income.';
    }
    if (_has(q, ['need', 'want', 'necessary', 'optional'])) {
      return 'Needs are things you must pay for (food, rent, transport, '
          'required books). Wants are nice extras (eating out, new clothes, '
          'subscriptions). Before a "want" purchase, wait 24 hours and check '
          'it still fits your budget.';
    }
    return 'I\'m not sure about that one. I can help with budgets, saving '
        'tips, savings goals and understanding your spending. Try asking '
        '"How am I doing this month?" or "How can I save more?"\n\n'
        'Tip: check the Learning hub for short finance lessons.';
  }
}
