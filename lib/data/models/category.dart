import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String type; // 'expense' | 'income'
  final String icon; // key into [iconFor]
  final bool isDefault;
  final String? createdBy;

  const Category({
    required this.id,
    required this.name,
    this.type = 'expense',
    this.icon = 'misc',
    this.isDefault = false,
    this.createdBy,
  });

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['CategoryId'] as String,
        name: m['CategoryName'] as String,
        type: m['CategoryType'] as String? ?? 'expense',
        icon: m['Icon'] as String? ?? 'misc',
        isDefault: (m['IsDefault'] as int? ?? 0) == 1,
        createdBy: m['CreatedBy'] as String?,
      );

  Map<String, Object?> toMap() => {
        'CategoryId': id,
        'CategoryName': name,
        'CategoryType': type,
        'Icon': icon,
        'IsDefault': isDefault ? 1 : 0,
        'CreatedBy': createdBy,
      };

  IconData get iconData => iconFor(icon);
  Color get color => colorFor(icon);

  static const iconKeys = <String, IconData>{
    'food': Icons.restaurant_rounded,
    'transport': Icons.directions_bus_rounded,
    'education': Icons.school_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'entertainment': Icons.movie_rounded,
    'bills': Icons.receipt_long_rounded,
    'savings': Icons.savings_rounded,
    'misc': Icons.category_rounded,
    'health': Icons.favorite_rounded,
    'gift': Icons.card_giftcard_rounded,
    'phone': Icons.phone_iphone_rounded,
    'sport': Icons.sports_soccer_rounded,
  };

  static const _colors = <String, Color>{
    'food': Color(0xFFEF6C00),
    'transport': Color(0xFF1E88E5),
    'education': Color(0xFF6A1B9A),
    'shopping': Color(0xFFD81B60),
    'entertainment': Color(0xFF00897B),
    'bills': Color(0xFF5D4037),
    'savings': Color(0xFF2E7D32),
    'misc': Color(0xFF546E7A),
    'health': Color(0xFFC62828),
    'gift': Color(0xFFAD1457),
    'phone': Color(0xFF3949AB),
    'sport': Color(0xFF7CB342),
  };

  static IconData iconFor(String key) =>
      iconKeys[key] ?? Icons.category_rounded;
  static Color colorFor(String key) => _colors[key] ?? const Color(0xFF546E7A);
}
