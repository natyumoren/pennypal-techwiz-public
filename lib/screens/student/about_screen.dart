import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../widgets/common.dart';

/// About PennyPal, disclaimer, privacy notice and acknowledgements.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget h(String s) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 6),
          child: Semantics(
              header: true,
              child: Text(s, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        );
    Widget p(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s, style: const TextStyle(height: 1.5)));

    return Scaffold(
      appBar: AppBar(title: const Text('About PennyPal')),
      body: ResponsiveBody(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Center(child: BrandLogo(size: 60)),
          const SizedBox(height: 6),
          Center(child: Text('${AppConfig.tagline} · version 1.0.0')),
          h('Our purpose'),
          p('PennyPal helps students take control of everyday money. Record your '
              'income and expenses, plan a monthly budget with category limits, '
              'get instant alerts before you overspend, save towards goals and '
              'learn the basics of personal finance – all in one simple app that '
              'works on Android, iOS, tablets and the web.'),
          h('What PennyPal is not'),
          p('PennyPal is a personal finance-learning and expense-management tool. '
              'It is not a bank, digital wallet, payment gateway, investment '
              'platform or professional financial advisory service. It never '
              'connects to bank accounts, stores card details or moves real money. '
              'Tips, lessons and chatbot answers are educational guidance only.'),
          h('Privacy notice'),
          p('• We only collect what is needed to run your account: your name, '
              'email, mobile number and the financial records you choose to enter.'),
          p('• Your password is stored as a salted PBKDF2 hash, never in plain text.'),
          p('• Records are stored on your device so the app works offline. If '
              'cloud sync is enabled they are also stored in a secure cloud '
              'database over an encrypted (HTTPS) connection, visible only to your account.'),
          p('• The chatbot receives only summary figures (e.g. monthly totals per '
              'category) – never your name, email or phone number.'),
          p('• Administrators can see account details and usage statistics to '
              'manage the service and answer support requests. We never sell your data.'),
          p('• You can edit or delete any record at any time, and ask support to delete your account.'),
          h('Acknowledgements'),
          p('Built with Flutter and Dart. Open-source packages: provider, sqflite, '
              'fl_chart, intl, http, crypto, uuid, string_similarity, image_picker, '
              'share_plus, connectivity_plus, shared_preferences, '
              'flutter_local_notifications, firebase_core, firebase_auth and '
              'cloud_firestore. Chatbot powered by Google Gemini (Google AI Studio) when configured.'),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
