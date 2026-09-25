/// Build-time configuration.
///
/// Secrets are never hard-coded. They are passed with --dart-define, e.g.
///   flutter run --dart-define=GEMINI_API_KEY=xxxx
/// When a value is missing the related feature falls back to an offline
/// alternative (rule-based chatbot, local-only storage).
class AppConfig {
  AppConfig._();

  static const appName = 'PennyPal';
  static const tagline = 'Fresh All Along';

  // --- Google AI Studio (Gemini) -------------------------------------
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const geminiModel =
      String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-2.5-flash');
  static bool get aiEnabled => geminiApiKey.isNotEmpty;

  /// The SRS asks for AI replies "within a few seconds"; after this we give
  /// up and show the offline answer instead.
  static const aiTimeout = Duration(seconds: 10);

  // --- Firebase (optional cloud sync) ---------------------------------
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const firebaseStorageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static bool get cloudConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseSenderId.isNotEmpty;

  // --- Pre-configured accounts (SRS 1.6: admin logins are preconfigured) --
  static const adminEmail = 'admin@pennypal.app';
  static const adminPassword = 'Admin@123';
  static const demoStudentEmail = 'student@pennypal.app';
  static const demoStudentPassword = 'Student@123';

  /// Screens wider than this get a navigation rail instead of a bottom bar.
  static const wideLayoutBreakpoint = 840.0;
}
