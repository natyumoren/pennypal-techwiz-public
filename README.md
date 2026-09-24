# PennyPal – Fresh All Along

PennyPal is a cross-platform Flutter app (Android, iOS, tablets and the web) that helps
students record income and expenses, plan monthly budgets, get instant alerts before they
overspend, save towards goals, read short finance lessons and ask a budgeting chatbot.
A pre-configured administrator manages students, learning content, support queries and
app settings.

> PennyPal is a finance-learning and expense-management tool. It is **not** a bank,
> wallet, payment gateway, investment platform or financial adviser, and it never moves
> real money or connects to bank accounts.

---

## User credentials

| Role | Login ID (email) | Password |
|---|---|---|
| Administrator (pre-configured) | `admin@pennypal.app` | `Admin@123` |
| Demo student (with test data) | `student@pennypal.app` | `Student@123` |

New students can register from the login screen. The login screen also has one-tap
buttons that fill in the demo accounts.

---

## Installation

### Prerequisites

* Flutter **3.27.4** (Dart **3.6**): <https://docs.flutter.dev/get-started/install>
* Android Studio with an Android SDK (API 35) and an emulator or an Android phone
  (Android 6.0 / API 23 or newer)
* For iOS: a Mac with Xcode 15+ and CocoaPods
* JDK 17

Check your setup with `flutter doctor`.

### Run the app

```bash
git clone https://github.com/natyumoren/pennypal-techwiz-ai.git
cd pennypal-techwiz-ai
flutter pub get

flutter run                 # on the connected phone or emulator
flutter run -d chrome       # in a web browser
```

On first launch the app creates its local database and loads the demo data. The first
start on the web can take a few seconds.

### Build the Android APK

```bash
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

Install it on a phone with `adb install build/app/outputs/flutter-apk/app-release.apk`,
or copy the file to the phone and open it (allow "install unknown apps").

The GitHub Actions workflow (`.github/workflows/build.yml`) also runs the tests and builds
the APK and the web app on every push. Download them from the run's **Artifacts**
(`PennyPal-apk`, `PennyPal-web`).

### Other builds

```bash
flutter build web --release --no-web-resources-cdn   # -> build/web (static files)
flutter build ios --release                           # on macOS
```

---

## Optional configuration

Everything works offline with no configuration. Two cloud features can be switched on at
build time with `--dart-define` (keys are never stored in the source code):

### AI chatbot (Google Gemini via Google AI Studio)

1. Create an API key at <https://aistudio.google.com/app/apikey>.
2. Run or build with the key:

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key
# optional: --dart-define=GEMINI_MODEL=gemini-2.5-flash   (default)
```

Without a key, or if a request fails or takes more than 10 seconds, "Ask Penny" answers
with the built-in rule-based advisor, which uses the student's own figures. The chatbot
only receives monthly totals, never names or contact details. Restrict the key to the
Gemini API in Google Cloud, because a key built into an app can be extracted.

### Cloud sync (Firebase Authentication + Cloud Firestore)

1. Create a Firebase project, enable **Email/Password** sign-in and **Cloud Firestore**.
2. Add a Web app in the Firebase console and copy its config values.
3. Deploy the security rules: `firebase deploy --only firestore:rules` (`firestore.rules`).
4. Run or build with:

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_SENDER_ID=...
```

Changes are always saved to the local database first and added to a sync queue, which is
pushed to Firestore when the device is online. The cloud icon on the dashboard shows the
sync status.

---

## Features

| SRS requirement | Where it lives in the app |
|---|---|
| Registration (name, email, mobile, password) with validation and duplicate check; login; logout | Login → *Create an account*; *More → Log out* |
| Dashboard: total income, expenses, available balance, budget status, charts, empty-state messages, quick navigation | *Home* tab |
| Income and expenses: add, view, edit, delete; 8 default categories plus custom ones | *Add* button, *History* tab, *More → Categories* |
| Transaction history search and filters (date range, category, type) | *History* tab |
| Monthly budget, category limits, remaining and overspending, update and delete | *Budget* tab |
| Instant alerts when spending reaches the alert threshold or goes over the limit | Pop-up message + *Notifications* (and a phone notification on Android/iOS) |
| Savings goals: target, current, date, monthly contribution; % progress, remaining, estimated completion; contributions; milestones; archived history | *Goals* tab |
| Reports: summary, category breakdown, 6-month trend, CSV export | *More → Spending reports* |
| Learning hub with topic cards and lesson pages | *Learning* quick action |
| About, Feedback (name, email, rating, comments), Contact Support (subject, message) with confirmations | *More* menu |
| AI chatbot for budgeting questions | *Ask Penny* |
| Optional: AI expense categorisation | The *Add expense* form suggests a category while you type |
| Optional: receipt photos from the camera | *Attach receipt photo* on the transaction form |
| Offline entry with automatic sync | Local SQLite + sync queue (see above) |
| Admin: manage students, statistics, analytics report, learning content, support queries, feedback, app settings | Log in as the administrator |

---

## Project structure

```
lib/
  core/          config (dart-defines), theme, validators, formatters, password hashing
  data/          SQLite database, seed data, models, repositories
  services/      categoriser, analytics, budget monitor, chatbot, sync, reports, notifications
  state/         session and per-student finance state (provider)
  screens/       auth/, student/, admin/
  widgets/       shared UI (cards, charts, transaction tile)
database/
  pennypal_schema.sql      database and table definitions (also used by the app at runtime)
  pennypal_seed_data.sql   seed + test data (generated from the app's seed code)
test/            unit and database tests
tool/            icon generator and seed-SQL exporter
firestore.rules  Firestore security rules for the optional cloud sync
```

## Database

The app creates its local database from `database/pennypal_schema.sql`, so the submitted
script and the app always match. To inspect it outside the app:

```bash
sqlite3 pennypal.db < database/pennypal_schema.sql
sqlite3 pennypal.db < database/pennypal_seed_data.sql
```

To regenerate the seed file after changing `lib/data/seed_data.dart`:
`flutter test tool/export_seed_sql_test.dart`.

## Tests

```bash
flutter analyze
flutter test
```

The tests cover validation rules, password hashing, the categoriser, budget and report
calculations, real-time alerts, goal milestones, the offline advisor, registration and
login, the sync queue and admin actions (against an in-memory copy of the real schema).

---

## Assumptions

* Each device keeps its own local database. Without Firebase, the admin portal manages
  the accounts and data stored on that device. With Firebase it also backs everything up
  to the cloud.
* Amounts use one currency per student (chosen in *Profile & settings*). There is no
  currency conversion.
* "Available balance" means all income recorded minus all expenses recorded. Savings
  contributions can optionally be recorded as a *Savings* expense.
* Budgets are set per calendar month. One overall budget and one limit per category are
  allowed per month, and *Copy last month* reuses the previous month's budgets.
* Alert thresholds default to the administrator's setting (80%) and can be changed per
  budget.
* A goal is completed when its current amount reaches the target. It then moves to goal
  history, and it re-opens if the target is raised later.
* Receipt photos are stored on the device (as an embedded image on the web). They are not
  uploaded to the cloud.
* The administrator account is pre-configured and cannot be created through registration.

## Acknowledgements

* Built with [Flutter](https://flutter.dev) and Dart.
* Packages: provider, sqflite, sqflite_common_ffi_web, fl_chart, intl, http, crypto,
  uuid, string_similarity, image_picker, share_plus, connectivity_plus, path_provider,
  shared_preferences, flutter_local_notifications, firebase_core, firebase_auth,
  cloud_firestore.
* Font: [Nunito](https://github.com/googlefonts/nunito) (SIL Open Font License,
  `assets/fonts/OFL.txt`).
* Chatbot: Google Gemini API (Google AI Studio), when configured.
* **AI tools used:** Claude Code (Anthropic) was used as a coding assistant for this
  project. No AI-generated images are used; the app icon is drawn by
  `tool/generate_icons.py`.
