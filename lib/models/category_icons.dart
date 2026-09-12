import 'package:flutter/material.dart';

/// Resolves a stored category icon (Material icon-name string) to a real
/// [IconData].
///
/// Older builds stored emoji glyphs (🧘, 🎓, …) in the categories table and in
/// task rows that referenced them. [categoryIcon] maps those legacy glyphs to
/// the same modern icon the name would resolve to, so existing data keeps
/// rendering correctly after the emoji removal.
const Map<String, IconData> _namedIcons = {
  'person': Icons.person,
  'school': Icons.school,
  'menu_book': Icons.menu_book,
  'fitness_center': Icons.fitness_center,
  'shopping_bag': Icons.shopping_bag,
  'work': Icons.work,
  'medical_services': Icons.medical_services,
  'account_balance_wallet': Icons.account_balance_wallet,
  'family_restroom': Icons.family_restroom,
  'flight_takeoff': Icons.flight_takeoff,
  'home': Icons.home,
  'music_note': Icons.music_note,
  'sports_esports': Icons.sports_esports,
  'pets': Icons.pets,
  'star': Icons.star,
};

const Map<String, IconData> _legacyEmojiIcons = {
  '\u{1F9D8}': Icons.self_improvement, // 🧘
  '\u{1F393}': Icons.school, // 🎓
  '\u{1F4DA}': Icons.menu_book, // 📚
  '\u{1F4AA}': Icons.fitness_center, // 💪
  '\u{1F6CD}\u{FE0F}': Icons.shopping_bag, // 🛍️
  '\u{1F4BC}': Icons.work, // 💼
  '\u{1FA7A}': Icons.medical_services, // 🩺
  '\u{1F4B0}': Icons.account_balance_wallet, // 💰
  '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}':
      Icons.family_restroom, // 👨‍👩‍👧‍👦
  '\u{2708}\u{FE0F}': Icons.flight_takeoff, // ✈️
  '\u{1F3E0}': Icons.home, // 🏠
  '\u{1F3B5}': Icons.music_note, // 🎵
  '\u{1F3AE}': Icons.sports_esports, // 🎮
  '\u{1F436}': Icons.pets, // 🐶
  '\u{2B50}': Icons.star, // ⭐
  '\u{1F3F7}\u{FE0F}': Icons.label, // 🏷️
};

/// Icon names offered when creating/editing a category.
const List<String> categoryIconNames = [
  'person',
  'school',
  'menu_book',
  'fitness_center',
  'shopping_bag',
  'work',
  'medical_services',
  'account_balance_wallet',
  'family_restroom',
  'flight_takeoff',
  'home',
  'music_note',
  'sports_esports',
  'pets',
  'star',
];

/// Resolves a stored [icon] value (name or legacy emoji) to an [IconData].
/// Unknown/empty values fall back to a neutral tag icon.
IconData categoryIcon(String? icon) {
  if (icon == null || icon.isEmpty) return Icons.label_outline;
  final named = _namedIcons[icon];
  if (named != null) return named;
  return _legacyEmojiIcons[icon] ?? Icons.label_outline;
}