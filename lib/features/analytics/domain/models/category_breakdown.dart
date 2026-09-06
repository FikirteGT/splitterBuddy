import 'package:flutter/material.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense_category.dart';

class CategoryBreakdown {
  final String categoryId;
  final String categoryName;
  final IconData icon;
  final Color color;
  final double totalAmount;
  final double percentage;
  final int expenseCount;

  const CategoryBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.totalAmount,
    required this.percentage,
    required this.expenseCount,
  });

  factory CategoryBreakdown.fromExpenses({
    required String categoryId,
    required double totalAmount,
    required double overallTotal,
    required int expenseCount,
  }) {
    final cat = ExpenseCategory.find(categoryId);
    final percentage = overallTotal > 0 ? (totalAmount / overallTotal) * 100.0 : 0.0;
    return CategoryBreakdown(
      categoryId: categoryId,
      categoryName: cat.name,
      icon: cat.icon,
      color: cat.color,
      totalAmount: totalAmount,
      percentage: double.parse(percentage.toStringAsFixed(1)),
      expenseCount: expenseCount,
    );
  }
}
