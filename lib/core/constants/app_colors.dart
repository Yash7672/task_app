import 'package:flutter/material.dart';

class AppColors {
  // Category Colors
  static const Color categoryPersonal = Color(0xFF4CAF50); // Green
  static const Color categoryCollege = Color(0xFF2196F3); // Blue
  static const Color categoryStudy = Color(0xFF9C27B0); // Purple
  static const Color categoryGym = Color(0xFFFF9800); // Orange
  static const Color categoryShopping = Color(0xFFE91E63); // Pink
  static const Color categoryWork = Color(0xFF607D8B); // Blue Grey
  static const Color categoryHealth = Color(0xFFF44336); // Red
  static const Color categoryFinance = Color(0xFFFFC107); // Amber
  static const Color categoryFamily = Color(0xFF795548); // Brown
  static const Color categoryTravel = Color(0xFF00BCD4); // Cyan

  // Priority Colors
  static const Color priorityCritical = Color(0xFFD32F2F);
  static const Color priorityHigh = Color(0xFFF57C00);
  static const Color priorityMedium = Color(0xFFFBC02D);
  static const Color priorityLow = Color(0xFF388E3C);
  static const Color priorityNone = Colors.grey;

  // Helpers to get colors based on strings
  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'personal':
        return categoryPersonal;
      case 'college':
        return categoryCollege;
      case 'study':
        return categoryStudy;
      case 'gym':
        return categoryGym;
      case 'shopping':
        return categoryShopping;
      case 'work':
        return categoryWork;
      case 'health':
        return categoryHealth;
      case 'finance':
        return categoryFinance;
      case 'family':
        return categoryFamily;
      case 'travel':
        return categoryTravel;
      default:
        return categoryPersonal;
    }
  }

  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return priorityCritical;
      case 'high':
        return priorityHigh;
      case 'medium':
        return priorityMedium;
      case 'low':
        return priorityLow;
      default:
        return priorityNone;
    }
  }
}
