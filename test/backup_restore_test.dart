import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:expensify_mobile/data/services/backup_restore_service.dart';

void main() {
  group('BackupRestoreService Validation Tests', () {
    late BackupRestoreService service;

    setUp(() {
      service = BackupRestoreService();
    });

    test('rejects empty input', () {
      expect(
        () => service.validateBackupJson(''),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => service.validateBackupJson('   '),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid JSON syntax', () {
      expect(
        () => service.validateBackupJson('{invalid json}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-object root JSON', () {
      expect(
        () => service.validateBackupJson('[1, 2, 3]'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => service.validateBackupJson('"string"'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects missing or unsupported backup_version', () {
      final missingVersion = jsonEncode({
        'created_at': '2026-10-01T12:00:00Z',
        'data': {},
      });
      expect(
        () => service.validateBackupJson(missingVersion),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('missing "backup_version"'),
        )),
      );

      final unsupportedVersion = jsonEncode({
        'backup_version': 999,
        'data': {},
      });
      expect(
        () => service.validateBackupJson(unsupportedVersion),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Unsupported backup version'),
        )),
      );
    });

    test('rejects missing or invalid data property', () {
      final missingData = jsonEncode({
        'backup_version': 1,
        'created_at': '2026-10-01T12:00:00Z',
      });
      expect(
        () => service.validateBackupJson(missingData),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('missing "data" object'),
        )),
      );

      final invalidData = jsonEncode({
        'backup_version': 1,
        'data': 'not an object',
      });
      expect(
        () => service.validateBackupJson(invalidData),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('missing "data" object'),
        )),
      );
    });

    test('rejects invalid table type inside data', () {
      final invalidTable = jsonEncode({
        'backup_version': 1,
        'data': {
          'expenses': 'not a list',
        },
      });
      expect(
        () => service.validateBackupJson(invalidTable),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Invalid table data for "expenses"'),
        )),
      );
    });

    test('accepts valid empty backup and calculates correct counts', () {
      final validEmpty = jsonEncode({
        'backup_version': 1,
        'created_at': '2026-10-01T12:00:00Z',
        'app': 'Expensify',
        'data': {
          'tags': [],
          'stores': [],
          'expenses': [],
          'account_balances': [],
          'budgets': [],
          'recurring_expenses': [],
          'quick_add_pins': [],
        },
      });

      final summary = service.validateBackupJson(validEmpty);
      expect(summary['backupVersion'], 1);
      expect(summary['createdAt'], '2026-10-01T12:00:00Z');
      expect(summary['expensesCount'], 0);
      expect(summary['storesCount'], 0);
      expect(summary['tagsCount'], 0);
      expect(summary['budgetsCount'], 0);
      expect(summary['recurringCount'], 0);
      expect(summary['quickAddCount'], 0);
      expect(summary['balancesCount'], 0);
    });

    test('accepts valid backup with comprehensive data and preserves relationships', () {
      final validFull = jsonEncode({
        'backup_version': 1,
        'created_at': '2026-10-01T14:00:00Z',
        'app': 'Expensify',
        'data': {
          'tags': [
            {'id': 't1', 'name': 'Groceries', 'created_at': '2026-10-01', 'updated_at': '2026-10-01'},
            {'id': 't2', 'name': 'Transport', 'created_at': '2026-10-01', 'updated_at': '2026-10-01'},
          ],
          'stores': [
            {'id': 's1', 'name': 'Trader Joe\'s', 'normalized_name': 'trader joes', 'default_tag_id': 't1', 'usage_count': 5, 'created_at': '2026-10-01', 'updated_at': '2026-10-01'},
          ],
          'expenses': [
            {
              'id': 'e1',
              'amount': 78.50,
              'date': '2026-10-01',
              'time': '12:30',
              'description': 'Weekly haul',
              'store_id': 's1',
              'tag_id': 't1',
              'payment_method': 'Credit Card',
              'is_recurring': 0,
              'created_at': '2026-10-01',
              'updated_at': '2026-10-01',
              'deleted_at': null,
            },
            {
              'id': 'e2',
              'amount': 22.00,
              'date': '2026-10-01',
              'time': '16:00',
              'description': 'Metro refill',
              'store_id': null,
              'tag_id': 't2',
              'payment_method': 'Cash',
              'is_recurring': 0,
              'created_at': '2026-10-01',
              'updated_at': '2026-10-01',
              'deleted_at': null,
            },
          ],
          'account_balances': [
            {'id': 'b1', 'baseline_amount': 5000.0, 'set_at': '2026-10-01', 'created_at': '2026-10-01', 'updated_at': '2026-10-01'},
          ],
          'budgets': [
            {'id': 'bg1', 'tag_id': 't1', 'amount': 400.0, 'period': 'monthly', 'created_at': '2026-10-01', 'updated_at': '2026-10-01'},
          ],
          'recurring_expenses': [
            {
              'id': 'r1',
              'description': 'Subway pass',
              'amount': 80.0,
              'frequency': 'Monthly',
              'next_due_date': '2026-11-01',
              'active': 1,
              'created_at': '2026-10-01',
              'updated_at': '2026-10-01',
            },
          ],
          'quick_add_pins': [
            {
              'id': 'q1',
              'store_id': 's1',
              'tag_id': 't1',
              'amount': 15.0,
              'is_pinned': 1,
              'created_at': '2026-10-01',
              'updated_at': '2026-10-01',
            },
          ],
        },
      });

      final summary = service.validateBackupJson(validFull);
      expect(summary['backupVersion'], 1);
      expect(summary['expensesCount'], 2);
      expect(summary['storesCount'], 1);
      expect(summary['tagsCount'], 2);
      expect(summary['budgetsCount'], 1);
      expect(summary['recurringCount'], 1);
      expect(summary['quickAddCount'], 1);
      expect(summary['balancesCount'], 1);

      final parsedData = summary['parsedData'] as Map<String, dynamic>;
      expect(parsedData['expenses'][0]['amount'], 78.50);
      expect(parsedData['expenses'][0]['store_id'], 's1');
      expect(parsedData['expenses'][0]['tag_id'], 't1');
    });
  });
}
