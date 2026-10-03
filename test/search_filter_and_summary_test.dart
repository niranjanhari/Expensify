import 'package:flutter_test/flutter_test.dart';
import 'package:expensify_mobile/data/services/analytics_service.dart';
import 'package:expensify_mobile/domain/models/expense.dart';

void main() {
  group('MonthlySpendingSummary Model & Calculation Tests', () {
    test('calculates correct difference and percentage increase', () {
      final summary = MonthlySpendingSummary(
        selectedMonth: DateTime(2026, 10, 1),
        selectedMonthTotal: 1500.0,
        selectedMonthCount: 15,
        previousMonthTotal: 1000.0,
        previousMonthCount: 10,
        difference: 500.0,
        percentageChange: 50.0,
        categoryBreakdown: [
          CategorySlice(category: 'Food', amount: 900.0, percentage: 60.0),
          CategorySlice(category: 'Transport', amount: 600.0, percentage: 40.0),
        ],
        topStores: [
          StoreSlice(store: 'Supermarket', amount: 900.0, count: 8, percentage: 60.0),
        ],
      );

      expect(summary.selectedMonthTotal, 1500.0);
      expect(summary.previousMonthTotal, 1000.0);
      expect(summary.difference, 500.0);
      expect(summary.percentageChange, 50.0);
      expect(summary.selectedMonthCount, 15);
      expect(summary.categoryBreakdown.length, 2);
      expect(summary.categoryBreakdown.first.category, 'Food');
      expect(summary.topStores.first.store, 'Supermarket');
    });

    test('handles spending decrease from previous month', () {
      const diff = 800.0 - 1000.0;
      const pct = ((800.0 - 1000.0) / 1000.0) * 100;

      final summary = MonthlySpendingSummary(
        selectedMonth: DateTime(2026, 10, 1),
        selectedMonthTotal: 800.0,
        selectedMonthCount: 8,
        previousMonthTotal: 1000.0,
        previousMonthCount: 12,
        difference: diff,
        percentageChange: pct,
        categoryBreakdown: [],
        topStores: [],
      );

      expect(summary.difference, -200.0);
      expect(summary.percentageChange, -20.0);
    });

    test('handles empty month with 0 expenses gracefully', () {
      final summary = MonthlySpendingSummary(
        selectedMonth: DateTime(2026, 10, 1),
        selectedMonthTotal: 0.0,
        selectedMonthCount: 0,
        previousMonthTotal: 0.0,
        previousMonthCount: 0,
        difference: 0.0,
        percentageChange: 0.0,
        categoryBreakdown: [],
        topStores: [],
      );

      expect(summary.selectedMonthTotal, 0.0);
      expect(summary.selectedMonthCount, 0);
      expect(summary.previousMonthTotal, 0.0);
      expect(summary.difference, 0.0);
      expect(summary.percentageChange, 0.0);
      expect(summary.categoryBreakdown, isEmpty);
      expect(summary.topStores, isEmpty);
    });
  });

  group('In-Memory Search & Multi-Filter Logic Tests', () {
    late List<Expense> expenses;

    setUp(() {
      expenses = [
        Expense(
          id: '1',
          amount: 250.0,
          date: DateTime(2026, 9, 15),
          time: '12:00',
          storeId: 's_starbucks',
          storeName: 'Starbucks',
          tagId: 't_food',
          tagName: 'Food & Dining',
          description: 'Caramel Macchiato and Croissant',
          paymentMethod: 'UPI',
          createdAt: DateTime(2026, 9, 15),
          updatedAt: DateTime(2026, 9, 15),
        ),
        Expense(
          id: '2',
          amount: 1200.0,
          date: DateTime(2026, 9, 20),
          time: '18:30',
          storeId: 's_walmart',
          storeName: 'Walmart',
          tagId: 't_groceries',
          tagName: 'Groceries',
          description: 'Monthly supplies',
          paymentMethod: 'Credit Card',
          createdAt: DateTime(2026, 9, 20),
          updatedAt: DateTime(2026, 9, 20),
        ),
        Expense(
          id: '3',
          amount: 45.0,
          date: DateTime(2026, 10, 2),
          time: '09:15',
          storeId: 's_uber',
          storeName: 'Uber',
          tagId: 't_transport',
          tagName: 'Transport',
          description: 'Ride to office',
          paymentMethod: 'UPI',
          createdAt: DateTime(2026, 10, 2),
          updatedAt: DateTime(2026, 10, 2),
        ),
        Expense(
          id: '4',
          amount: 600.0,
          date: DateTime(2026, 10, 5),
          time: '20:00',
          storeId: 's_starbucks',
          storeName: 'Starbucks',
          tagId: 't_food',
          tagName: 'Food & Dining',
          description: 'Coffee with colleagues',
          paymentMethod: 'Cash',
          createdAt: DateTime(2026, 10, 5),
          updatedAt: DateTime(2026, 10, 5),
        ),
      ];
    });

    List<Expense> applyFilters(
      List<Expense> source, {
      String? query,
      DateTime? startDate,
      DateTime? endDate,
      String? tagId,
      String? storeId,
      String? paymentMethod,
    }) {
      return source.where((e) {
        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim().toLowerCase();
          final descMatch = (e.description ?? '').toLowerCase().contains(q);
          final storeMatch = (e.storeName ?? '').toLowerCase().contains(q);
          final tagMatch = (e.tagName ?? '').toLowerCase().contains(q);
          final pmMatch = e.paymentMethod.toLowerCase().contains(q);
          if (!descMatch && !storeMatch && !tagMatch && !pmMatch) return false;
        }

        if (startDate != null && e.date.isBefore(startDate)) return false;
        if (endDate != null && e.date.isAfter(endDate)) return false;
        if (tagId != null && e.tagId != tagId) return false;
        if (storeId != null && e.storeId != storeId) return false;
        if (paymentMethod != null && e.paymentMethod.toLowerCase() != paymentMethod.toLowerCase()) {
          return false;
        }

        return true;
      }).toList();
    }

    test('case-insensitive search by store/merchant', () {
      final res = applyFilters(expenses, query: 'starbucks');
      expect(res.length, 2);
      expect(res.every((e) => e.storeName == 'Starbucks'), isTrue);

      final uppercaseRes = applyFilters(expenses, query: 'STARBUCKS');
      expect(uppercaseRes.length, 2);
    });

    test('case-insensitive search by category/tag', () {
      final res = applyFilters(expenses, query: 'groceries');
      expect(res.length, 1);
      expect(res.first.tagName, 'Groceries');
    });

    test('case-insensitive search by description', () {
      final res = applyFilters(expenses, query: 'macchiato');
      expect(res.length, 1);
      expect(res.first.id, '1');
    });

    test('case-insensitive search by payment method', () {
      final res = applyFilters(expenses, query: 'credit card');
      expect(res.length, 1);
      expect(res.first.id, '2');
    });

    test('filters by date range', () {
      final septemberRes = applyFilters(
        expenses,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );
      expect(septemberRes.length, 2);
      expect(septemberRes.map((e) => e.id), containsAll(['1', '2']));
    });

    test('combines multiple filters (Food + UPI + September 2026)', () {
      final res = applyFilters(
        expenses,
        tagId: 't_food',
        paymentMethod: 'UPI',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );

      expect(res.length, 1);
      expect(res.first.id, '1');
      expect(res.first.storeName, 'Starbucks');
      expect(res.first.paymentMethod, 'UPI');
    });

    test('clearing all filters returns all items', () {
      final filtered = applyFilters(
        expenses,
        tagId: 't_food',
        paymentMethod: 'UPI',
      );
      expect(filtered.length, 1);

      // Clearing all filters
      final cleared = applyFilters(expenses);
      expect(cleared.length, 4);
    });
  });
}
