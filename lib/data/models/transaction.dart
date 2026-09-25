class TransactionRecord {
  final String id;
  final String userId;
  final String type; // 'income' | 'expense'
  final double amount;
  final String? categoryId; // expenses
  final String? source; // income
  final String? description;
  final String date; // yyyy-MM-dd
  final String? paymentMode;
  final String? receiptImageUrl;
  final String createdAt;

  const TransactionRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.categoryId,
    this.source,
    this.description,
    required this.date,
    this.paymentMode,
    this.receiptImageUrl,
    required this.createdAt,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  String get month => date.substring(0, 7);
  DateTime get dateTime => DateTime.parse(date);

  factory TransactionRecord.fromMap(Map<String, Object?> m) =>
      TransactionRecord(
        id: m['TransactionId'] as String,
        userId: m['UserId'] as String,
        type: m['Type'] as String,
        amount: (m['Amount'] as num).toDouble(),
        categoryId: m['CategoryId'] as String?,
        source: m['Source'] as String?,
        description: m['Description'] as String?,
        date: m['Date'] as String,
        paymentMode: m['PaymentMode'] as String?,
        receiptImageUrl: m['ReceiptImageUrl'] as String?,
        createdAt: m['CreatedAt'] as String,
      );

  Map<String, Object?> toMap() => {
        'TransactionId': id,
        'UserId': userId,
        'Type': type,
        'Amount': amount,
        'CategoryId': categoryId,
        'Source': source,
        'Description': description,
        'Date': date,
        'PaymentMode': paymentMode,
        'ReceiptImageUrl': receiptImageUrl,
        'CreatedAt': createdAt,
      };
}
