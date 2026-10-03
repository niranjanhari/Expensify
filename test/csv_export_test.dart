import 'package:flutter_test/flutter_test.dart';
import 'package:expensify_mobile/data/services/csv_export_service.dart';
import 'package:expensify_mobile/domain/models/expense.dart';

void main() {
  group('CsvExportService Tests', () {
    test('escapeCsvValue correctly escapes special characters', () {
      expect(CsvExportService.escapeCsvValue(null), '');
      expect(CsvExportService.escapeCsvValue('Coffee'), 'Coffee');
      expect(CsvExportService.escapeCsvValue(123.45), '123.45');
      // Commas
      expect(CsvExportService.escapeCsvValue('Coffee, Tea'), '"Coffee, Tea"');
      // Quotes
      expect(CsvExportService.escapeCsvValue('Book "Flutter"'), '"Book ""Flutter"""');
      // Newlines
      expect(CsvExportService.escapeCsvValue('Line 1\nLine 2'), '"Line 1\nLine 2"');
      // Both quotes and commas
      expect(
        CsvExportService.escapeCsvValue('Item "A", Item "B"'),
        '"Item ""A"", Item ""B"""',
      );
    });

    test('generateCsvString handles empty list (no expenses)', () {
      final csv = CsvExportService.generateCsvString([]);
      expect(csv.startsWith('\uFEFF'), isTrue); // Has UTF-8 BOM
      final lines = csv.replaceFirst('\uFEFF', '').trim().split('\n');
      expect(lines.length, 1); // Header only
      expect(
        lines[0].trim(),
        'Date,Time,Amount,Store/Merchant,Category/Tag,Description,Payment Method',
      );
    });

    test('generateCsvString handles single expense', () {
      final exp = Expense(
        id: '1',
        amount: 45.50,
        date: DateTime(2026, 10, 1),
        time: '14:30',
        storeName: 'Starbucks',
        tagName: 'Food',
        description: 'Iced Latte',
        paymentMethod: 'UPI',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deletedAt: null,
      );

      final csv = CsvExportService.generateCsvString([exp]);
      final lines = csv.replaceFirst('\uFEFF', '').trim().split('\n');
      expect(lines.length, 2);
      expect(
        lines[1].trim(),
        '2026-10-01,14:30,45.50,Starbucks,Food,Iced Latte,UPI',
      );
    });

    test('generateCsvString handles multiple expenses', () {
      final expenses = [
        Expense(
          id: '1',
          amount: 100.00,
          date: DateTime(2026, 10, 1),
          time: '09:00',
          storeName: 'Metro',
          tagName: 'Transport',
          description: 'Monthly pass',
          paymentMethod: 'Card',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deletedAt: null,
        ),
        Expense(
          id: '2',
          amount: 250.75,
          date: DateTime(2026, 10, 2),
          time: '19:45',
          storeName: 'Supermarket',
          tagName: 'Groceries',
          description: 'Weekly veggies',
          paymentMethod: 'Cash',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deletedAt: null,
        ),
      ];

      final csv = CsvExportService.generateCsvString(expenses);
      final lines = csv.replaceFirst('\uFEFF', '').trim().split('\n');
      expect(lines.length, 3);
      expect(lines[1].trim(), '2026-10-01,09:00,100.00,Metro,Transport,Monthly pass,Card');
      expect(lines[2].trim(), '2026-10-02,19:45,250.75,Supermarket,Groceries,Weekly veggies,Cash');
    });

    test('generateCsvString handles commas, quotes, and newlines in merchant and description', () {
      final exp = Expense(
        id: '1',
        amount: 1599.99,
        date: DateTime(2026, 10, 1),
        time: '12:00',
        storeName: 'Barnes & Noble, 5th Ave',
        tagName: 'Shopping',
        description: 'Bought "Clean Code", "Design Patterns"\n2 books',
        paymentMethod: 'Credit Card',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deletedAt: null,
      );

      final csv = CsvExportService.generateCsvString([exp]);
      expect(csv.contains('"Barnes & Noble, 5th Ave"'), isTrue);
      expect(csv.contains('"Bought ""Clean Code"", ""Design Patterns""\n2 books"'), isTrue);
    });
  });
}
