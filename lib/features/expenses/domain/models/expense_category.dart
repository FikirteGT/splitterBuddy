import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';

class ExpenseCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  static const List<ExpenseCategory> all = [
    ExpenseCategory(
      id: AppConstants.categoryFood,
      name: 'Food & Dining',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFF97316), // Orange
    ),
    ExpenseCategory(
      id: AppConstants.categoryGroceries,
      name: 'Groceries',
      icon: Icons.local_grocery_store_rounded,
      color: Color(0xFF10B981), // Emerald
    ),
    ExpenseCategory(
      id: AppConstants.categoryRent,
      name: 'Rent & Housing',
      icon: Icons.home_rounded,
      color: Color(0xFF6366F1), // Indigo
    ),
    ExpenseCategory(
      id: AppConstants.categoryUtilities,
      name: 'Utilities & Power',
      icon: Icons.bolt_rounded,
      color: Color(0xFFEAB308), // Yellow
    ),
    ExpenseCategory(
      id: AppConstants.categoryTransportation,
      name: 'Transportation',
      icon: Icons.directions_car_rounded,
      color: Color(0xFF06B6D4), // Cyan
    ),
    ExpenseCategory(
      id: AppConstants.categoryEntertainment,
      name: 'Entertainment',
      icon: Icons.movie_creation_rounded,
      color: Color(0xFFEC4899), // Pink
    ),
    ExpenseCategory(
      id: AppConstants.categoryShopping,
      name: 'Shopping',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF8B5CF6), // Purple
    ),
    ExpenseCategory(
      id: AppConstants.categoryInternet,
      name: 'Internet & WiFi',
      icon: Icons.wifi_rounded,
      color: Color(0xFF3B82F6), // Blue
    ),
    ExpenseCategory(
      id: AppConstants.categorySubscription,
      name: 'Subscriptions',
      icon: Icons.subscriptions_rounded,
      color: Color(0xFFD946EF), // Fuchsia
    ),
    ExpenseCategory(
      id: AppConstants.categoryTravel,
      name: 'Travel & Trips',
      icon: Icons.flight_takeoff_rounded,
      color: Color(0xFF14B8A6), // Teal
    ),
    ExpenseCategory(
      id: AppConstants.categoryOther,
      name: 'Other',
      icon: Icons.category_rounded,
      color: Color(0xFF94A3B8), // Slate
    ),
  ];

  static ExpenseCategory find(String? name) {
    if (name == null || name.isEmpty) {
      return all.firstWhere((c) => c.id == AppConstants.categoryOther);
    }
    return all.firstWhere(
      (c) => c.id.toLowerCase() == name.toLowerCase() || c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => all.firstWhere((c) => c.id == AppConstants.categoryOther),
    );
  }
}
