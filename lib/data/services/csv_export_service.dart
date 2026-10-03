import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../daos/expense_dao.dart';
import '../../domain/models/expense.dart';

class CsvExportService {
  final ExpenseDao _expenseDao;

  CsvExportService({ExpenseDao? expenseDao}) : _expenseDao = expenseDao ?? ExpenseDao();

  /// Escapes CSV values according to RFC 4180 specifications.
  static String escapeCsvValue(dynamic value) {
    if (value == null) return '';
    String str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      str = str.replaceAll('"', '""');
      return '"$str"';
    }
    return str;
  }

  /// Converts a list of expenses into a UTF-8 RFC 4180 formatted CSV string.
  static String generateCsvString(List<Expense> expenses) {
    final buffer = StringBuffer();
    // Include UTF-8 BOM so Excel and spreadsheet applications display characters/currency correctly
    buffer.write('\uFEFF');

    // Header row
    buffer.writeln([
      'Date',
      'Time',
      'Amount',
      'Store/Merchant',
      'Category/Tag',
      'Description',
      'Payment Method',
    ].map(escapeCsvValue).join(','));

    // Data rows
    for (final exp in expenses) {
      final dateStr = DateFormat('yyyy-MM-dd').format(exp.date);
      final timeStr = exp.time ?? '';
      final amountStr = exp.amount.toStringAsFixed(2);
      final storeStr = exp.storeName ?? '';
      final tagStr = exp.tagName ?? '';
      final descStr = exp.description ?? '';
      final pmStr = exp.paymentMethod;

      buffer.writeln([
        dateStr,
        timeStr,
        amountStr,
        storeStr,
        tagStr,
        descStr,
        pmStr,
      ].map(escapeCsvValue).join(','));
    }

    return buffer.toString();
  }

  /// Exports all active expenses to a CSV file and opens the Android native share/save sheet.
  /// Returns the number of expenses exported.
  Future<int> exportExpenses() async {
    final expenses = await _expenseDao.getAllActiveExpenses();
    final csvContent = generateCsvString(expenses);

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fileName = 'expensify_expenses_$dateStr.csv';

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(csvContent, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Expensify Expenses Export ($dateStr)',
    );

    return expenses.length;
  }
}
