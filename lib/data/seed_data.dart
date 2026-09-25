import 'package:sqflite/sqflite.dart';

import '../core/config.dart';
import '../core/formatters.dart';
import '../core/security.dart';

/// First-launch data: default categories, the pre-configured admin account,
/// learning content, app settings and a demo student with sample records
/// (the "test data" referred to in the project documentation).
class SeedData {
  SeedData._();

  static const adminId = 'user-admin-0001';
  static const demoStudentId = 'user-student-0001';

  static const defaultCategories = [
    ['cat-food', 'Food', 'food'],
    ['cat-transport', 'Transport', 'transport'],
    ['cat-education', 'Education', 'education'],
    ['cat-shopping', 'Shopping', 'shopping'],
    ['cat-entertainment', 'Entertainment', 'entertainment'],
    ['cat-bills', 'Bills', 'bills'],
    ['cat-savings', 'Savings', 'savings'],
    ['cat-misc', 'Miscellaneous', 'misc'],
  ];

  static const learning = [
    [
      'Budgeting',
      'What is a budget?',
      'Beginner',
      'education',
      'A budget is a plan for your money. You list the money you expect to receive (income) and decide in advance how much will go to each kind of spending and to savings.\n\n'
          'Example: You get 400 a month. You plan 150 for food, 60 for transport, 40 for phone and bills, 50 for fun, 50 for study materials and 50 for savings. That adds up to 400, so every unit has a job.\n\n'
          'Tip: Review your budget at the end of each month. Move money from categories you did not use to the ones that ran short, and try again next month.'
    ],
    [
      'Budgeting',
      'The 50/30/20 rule',
      'Beginner',
      'bills',
      'A simple starting point for splitting income:\n\n'
          '• 50% for needs – food, rent, transport, bills.\n'
          '• 30% for wants – entertainment, eating out, shopping.\n'
          '• 20% for savings and paying back any debt.\n\n'
          'Students often have fewer fixed bills, so you might save more than 20%. Treat the rule as a guide, not a law – adjust it to your own situation.'
    ],
    [
      'Saving',
      'Pay yourself first',
      'Beginner',
      'savings',
      'Move money into savings as soon as you receive it, instead of saving "whatever is left" at the end of the month – usually nothing is left!\n\n'
          'Example: When your allowance arrives, put 10% straight into your savings goal in PennyPal. Then budget the other 90%.\n\n'
          'Small amounts add up: saving 5 a day becomes about 150 a month and 1,800 a year.'
    ],
    [
      'Saving',
      'Building an emergency fund',
      'Intermediate',
      'savings',
      'An emergency fund is money kept aside for surprises: a broken phone screen, a medical bill or an unexpected trip home.\n\n'
          'Aim for one month of expenses first, then grow it to three months. Keep it separate from your spending money so you are not tempted to use it.\n\n'
          'Create a savings goal called "Emergency fund" in PennyPal and add a small monthly contribution.'
    ],
    [
      'Income',
      'Understanding your income',
      'Beginner',
      'gift',
      'Income is any money you receive: allowance, scholarships, internship stipends, part-time jobs or gifts.\n\n'
          'Some income is regular (a monthly allowance) and some is irregular (freelance work, gifts). Build your budget on the regular income, and treat irregular income as a bonus – save part of it.\n\n'
          'Record every income entry in PennyPal so your available balance is always accurate.'
    ],
    [
      'Expenses',
      'Needs vs. wants',
      'Beginner',
      'shopping',
      'Necessary expenses (needs) are things you must pay for to live and study: food, transport to class, required books, rent and basic bills.\n\n'
          'Optional expenses (wants) make life nicer but can be reduced: takeaway coffee, new clothes, streaming services, concerts.\n\n'
          'Before buying, ask: "Do I need this, or do I want it?" If it is a want, wait 24 hours. If you still want it and it fits your budget, go ahead.'
    ],
    [
      'Expenses',
      'Spotting small leaks',
      'Intermediate',
      'food',
      'Small, frequent purchases are the easiest way to overspend without noticing: snacks, delivery fees, in-app purchases and unused subscriptions.\n\n'
          'Use the Transaction History filter in PennyPal to view one category for the month. If Food shows many small entries, try packing lunch twice a week and compare the next month.'
    ],
    [
      'Requirements',
      'Planning for study requirements',
      'Beginner',
      'education',
      'Every term brings required costs: textbooks, lab fees, printing, software and exam registrations. They are easy to forget because they are not monthly.\n\n'
          'Make a list at the start of the term, estimate the total and divide it by the months until you need the money. Add that amount to your Education budget each month.\n\n'
          'Look for second-hand books, library copies and student discounts before paying full price.'
    ],
    [
      'Saving',
      'Setting SMART savings goals',
      'Intermediate',
      'sport',
      'Good goals are Specific, Measurable, Achievable, Relevant and Time-bound.\n\n'
          'Weak goal: "Save money."\n'
          'SMART goal: "Save 300 for a new laptop bag by 30 June by putting aside 50 a month."\n\n'
          'PennyPal calculates how long your goal will take at your monthly contribution and warns you if you are behind schedule.'
    ],
  ];

  static const settings = {
    'default_alert_threshold': '80',
    'chatbot_enabled': '1',
    'support_email': 'support@pennypal.app',
  };

  static Future<void> apply(Database db,
      {bool includeDemoStudent = true}) async {
    final now = Fmt.nowIso();
    final batch = db.batch();

    for (final c in defaultCategories) {
      batch.insert('Categories', {
        'CategoryId': c[0],
        'CategoryName': c[1],
        'CategoryType': 'expense',
        'Icon': c[2],
        'IsDefault': 1,
        'CreatedBy': null,
      });
    }

    batch.insert('Users', {
      'UserId': adminId,
      'FullName': 'PennyPal Administrator',
      'Email': AppConfig.adminEmail,
      'MobileNumber': '+10000000000',
      'PasswordHash': PasswordHasher.hash(AppConfig.adminPassword),
      'Role': 'admin',
      'IsActive': 1,
      'CreatedAt': now,
    });
    batch.insert('UserProfiles', {
      'ProfileId': 'profile-admin-0001',
      'UserId': adminId,
      'StudentStatus': null,
      'CurrencyPreference': 'USD',
      'NotificationPreference': 1,
    });

    for (var i = 0; i < learning.length; i++) {
      final l = learning[i];
      batch.insert('LearningContent', {
        'ContentId': 'learn-${(i + 1).toString().padLeft(3, '0')}',
        'Topic': l[0],
        'Title': l[1],
        'DifficultyLevel': l[2],
        'ImageUrl': l[3],
        'Body': l[4],
        'IsActive': 1,
      });
    }

    settings.forEach((k, v) =>
        batch.insert('AppSettings', {'SettingKey': k, 'SettingValue': v}));

    if (includeDemoStudent) _demoStudent(batch, now);
    await batch.commit(noResult: true);
  }

  /// Demo student with three months of realistic records, relative to today
  /// so the dashboard and reports always have something to show.
  static void _demoStudent(Batch batch, String now) {
    batch.insert('Users', {
      'UserId': demoStudentId,
      'FullName': 'Ada Student',
      'Email': AppConfig.demoStudentEmail,
      'MobileNumber': '+15550100200',
      'PasswordHash': PasswordHasher.hash(AppConfig.demoStudentPassword),
      'Role': 'student',
      'IsActive': 1,
      'CreatedAt': now,
    });
    batch.insert('UserProfiles', {
      'ProfileId': 'profile-student-0001',
      'UserId': demoStudentId,
      'StudentStatus': 'Undergraduate',
      'CurrencyPreference': 'USD',
      'NotificationPreference': 1,
    });

    final today = DateTime.now();
    var n = 0;
    void tx(int monthOffset, int day, String type, double amount,
        {String? cat, String? source, String? desc, String mode = 'Cash'}) {
      final month = DateTime(today.year, today.month - monthOffset, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      var d = DateTime(month.year, month.month, day.clamp(1, lastDay));
      if (d.isAfter(today)) d = today; // never create future records
      n++;
      batch.insert('Transactions', {
        'TransactionId': 'tx-demo-${n.toString().padLeft(3, '0')}',
        'UserId': demoStudentId,
        'Type': type,
        'Amount': amount,
        'CategoryId': cat,
        'Source': source,
        'Description': desc,
        'Date': Fmt.isoDate(d),
        'PaymentMode': mode,
        'ReceiptImageUrl': null,
        'CreatedAt': now,
      });
    }

    for (var m = 2; m >= 0; m--) {
      tx(m, 1, 'income', 500, source: 'Monthly allowance', mode: 'Bank transfer');
      if (m != 1) {
        tx(m, 15, 'income', 180, source: 'Part-time tutoring', mode: 'Bank transfer');
      }
      tx(m, 2, 'expense', 42.5, cat: 'cat-food', desc: 'Groceries at supermarket', mode: 'Card');
      tx(m, 3, 'expense', 25, cat: 'cat-transport', desc: 'Monthly bus pass', mode: 'Card');
      tx(m, 5, 'expense', 12.99, cat: 'cat-entertainment', desc: 'Netflix subscription', mode: 'Card');
      tx(m, 7, 'expense', 18.4, cat: 'cat-food', desc: 'Pizza with friends');
      tx(m, 9, 'expense', 35, cat: 'cat-bills', desc: 'Phone data plan', mode: 'Mobile money');
      tx(m, 11, 'expense', 60 + m * 15.0, cat: 'cat-education', desc: 'Textbooks and printing', mode: 'Card');
      tx(m, 13, 'expense', 22.75, cat: 'cat-food', desc: 'Cafeteria lunches');
      tx(m, 16, 'expense', 45 - m * 5.0, cat: 'cat-shopping', desc: 'New t-shirt', mode: 'Card');
      tx(m, 20, 'expense', 50, cat: 'cat-savings', desc: 'Transfer to savings');
      tx(m, 22, 'expense', 9.5, cat: 'cat-transport', desc: 'Uber ride home', mode: 'Card');
      tx(m, 25, 'expense', 15, cat: 'cat-entertainment', desc: 'Cinema tickets');
    }

    final month = Fmt.monthKey(today);
    void budget(String id, String? cat, double limit) => batch.insert('Budgets', {
          'BudgetId': id,
          'UserId': demoStudentId,
          'Month': month,
          'CategoryId': cat,
          'LimitAmount': limit,
          'AlertThreshold': 80,
          'CreatedAt': now,
        });
    budget('budget-demo-001', null, 450);
    budget('budget-demo-002', 'cat-food', 100);
    budget('budget-demo-003', 'cat-entertainment', 30);
    budget('budget-demo-004', 'cat-shopping', 60);

    batch.insert('SavingsGoals', {
      'GoalId': 'goal-demo-001',
      'UserId': demoStudentId,
      'GoalName': 'New laptop',
      'TargetAmount': 900,
      'CurrentAmount': 320,
      'TargetDate': Fmt.isoDate(DateTime(today.year, today.month + 10, 1)),
      'MonthlyContribution': 75,
      'Status': 'active',
      'Milestones': '25',
      'CreatedAt': now,
    });
    batch.insert('SavingsGoals', {
      'GoalId': 'goal-demo-002',
      'UserId': demoStudentId,
      'GoalName': 'Emergency fund',
      'TargetAmount': 500,
      'CurrentAmount': 150,
      'TargetDate': Fmt.isoDate(DateTime(today.year, today.month + 5, 1)),
      'MonthlyContribution': 50,
      'Status': 'active',
      'Milestones': '25',
      'CreatedAt': now,
    });
    batch.insert('SavingsGoals', {
      'GoalId': 'goal-demo-003',
      'UserId': demoStudentId,
      'GoalName': 'Concert ticket',
      'TargetAmount': 120,
      'CurrentAmount': 120,
      'TargetDate': Fmt.isoDate(DateTime(today.year, today.month - 1, 1)),
      'MonthlyContribution': 40,
      'Status': 'completed',
      'Milestones': '25,50,75,100',
      'CreatedAt': now,
      'CompletedAt': now,
    });

    batch.insert('SupportQueries', {
      'QueryId': 'query-demo-001',
      'UserId': demoStudentId,
      'Subject': 'How do I change my currency?',
      'Message': 'I moved abroad for my exchange semester. Can I show amounts in EUR?',
      'Status': 'resolved',
      'AdminResponse':
          'Yes! Open More > Profile & settings and choose EUR under Currency.',
      'SubmittedOn': now,
    });
    batch.insert('Feedback', {
      'FeedbackId': 'feedback-demo-001',
      'UserId': demoStudentId,
      'Name': 'Ada Student',
      'Email': AppConfig.demoStudentEmail,
      'Rating': 5,
      'Comments': 'The budget alerts helped me stop overspending on food.',
      'SubmittedOn': now,
    });
    batch.insert('Notifications', {
      'NotificationId': 'notif-demo-001',
      'UserId': demoStudentId,
      'Title': 'Welcome to PennyPal!',
      'Message':
          'Start by adding your income, then set a monthly budget to get alerts before you overspend.',
      'Type': 'system',
      'ReadStatus': 0,
      'CreatedAt': now,
    });
  }
}
