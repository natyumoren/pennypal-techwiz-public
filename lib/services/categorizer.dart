import 'package:string_similarity/string_similarity.dart';

import '../data/models/category.dart';
import '../data/models/transaction.dart';

class CategorySuggestion {
  final Category category;
  final double confidence; // 0..1
  final String reason;
  const CategorySuggestion(this.category, this.confidence, this.reason);
}

/// On-device "AI" expense categorisation (optional SRS feature).
///
/// Works offline and without an API key in three steps:
///  1. Personal history – if the student has categorised a very similar
///     description before, reuse that choice (learns from corrections).
///  2. Keyword match – a vocabulary of common student expenses per category.
///  3. Fuzzy match – Dice-coefficient similarity (string_similarity package)
///     between each word and the vocabulary, to tolerate typos like "piza".
class ExpenseCategorizer {
  static const Map<String, List<String>> vocabulary = {
    'food': [
      'food', 'lunch', 'dinner', 'breakfast', 'snack', 'pizza', 'burger',
      'coffee', 'tea', 'cafe', 'cafeteria', 'canteen', 'restaurant',
      'groceries', 'grocery', 'supermarket', 'meal', 'kfc', 'mcdonalds',
      'delivery', 'drinks', 'juice', 'bakery', 'fruit', 'rice', 'noodles',
    ],
    'transport': [
      'bus', 'taxi', 'uber', 'bolt', 'lyft', 'train', 'metro', 'fuel',
      'petrol', 'gas', 'parking', 'fare', 'ticket', 'transport', 'ride',
      'bike', 'scooter', 'subway', 'tram', 'flight',
    ],
    'education': [
      'book', 'books', 'textbook', 'textbooks', 'tuition', 'course', 'exam',
      'printing', 'print', 'stationery', 'notebook', 'pen', 'lab', 'fees',
      'school', 'college', 'university', 'udemy', 'coursera', 'library',
      'calculator', 'software',
    ],
    'shopping': [
      'clothes', 'shirt', 't-shirt', 'shoes', 'jeans', 'dress', 'amazon',
      'shopping', 'mall', 'jacket', 'bag', 'makeup', 'cosmetics',
      'accessories', 'gadget', 'headphones', 'watch',
    ],
    'entertainment': [
      'movie', 'cinema', 'netflix', 'spotify', 'game', 'games', 'concert',
      'party', 'club', 'streaming', 'youtube', 'disney', 'playstation',
      'xbox', 'steam', 'bowling', 'theatre', 'festival',
    ],
    'bills': [
      'rent', 'electricity', 'water', 'internet', 'wifi', 'phone', 'data',
      'airtime', 'bill', 'bills', 'subscription', 'insurance', 'hostel',
      'utility', 'recharge', 'topup',
    ],
    'savings': [
      'savings', 'save', 'deposit', 'piggy', 'emergency', 'fund',
      'transfer to savings',
    ],
  };

  /// Returns the best suggestion, or null when nothing is convincing.
  static CategorySuggestion? suggest(
    String description,
    List<Category> categories, {
    List<TransactionRecord> history = const [],
  }) {
    final text = description.trim().toLowerCase();
    if (text.length < 3 || categories.isEmpty) return null;

    // 1. Personal history.
    TransactionRecord? best;
    var bestScore = 0.0;
    for (final t in history) {
      if (!t.isExpense || t.description == null || t.categoryId == null) {
        continue;
      }
      final score = text.similarityTo(t.description!.toLowerCase());
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }
    if (best != null && bestScore >= 0.72) {
      final cat = _byId(categories, best.categoryId!);
      if (cat != null) {
        return CategorySuggestion(cat, bestScore, 'Similar to "${best.description}"');
      }
    }

    // 2 + 3. Vocabulary (exact word, then fuzzy).
    final words = text
        .split(RegExp(r'[^a-z0-9-]+'))
        .where((w) => w.length >= 3)
        .toList();
    String? bestKey;
    var bestKeyScore = 0.0;
    String? matched;
    for (final entry in vocabulary.entries) {
      for (final keyword in entry.value) {
        final double score;
        if (keyword.contains(' ')) {
          score = text.contains(keyword) ? 1.0 : 0.0;
        } else if (words.contains(keyword)) {
          score = 1.0;
        } else {
          score = words.isEmpty
              ? 0.0
              : words
                  .map((w) => w.similarityTo(keyword))
                  .reduce((a, b) => a > b ? a : b);
        }
        if (score > bestKeyScore) {
          bestKeyScore = score;
          bestKey = entry.key;
          matched = keyword;
        }
      }
    }
    // Custom categories: compare against their names too.
    Category? bestCustom;
    var bestCustomScore = 0.0;
    for (final c in categories.where((c) => !c.isDefault)) {
      for (final w in words) {
        final score = w.similarityTo(c.name.toLowerCase());
        if (score > bestCustomScore) {
          bestCustomScore = score;
          bestCustom = c;
        }
      }
    }
    if (bestCustom != null &&
        bestCustomScore >= 0.6 &&
        bestCustomScore > bestKeyScore) {
      return CategorySuggestion(
          bestCustom, bestCustomScore, 'Matches your "${bestCustom.name}" category');
    }
    if (bestKey == null || bestKeyScore < 0.6) return null;
    final cat = categories.where((c) => c.icon == bestKey && c.isDefault);
    if (cat.isEmpty) return null;
    return CategorySuggestion(cat.first, bestKeyScore,
        bestKeyScore == 1 ? 'Keyword "$matched"' : 'Looks like "$matched"');
  }

  static Category? _byId(List<Category> cats, String id) {
    for (final c in cats) {
      if (c.id == id) return c;
    }
    return null;
  }
}
