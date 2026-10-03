import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';

class AnalyticsSummary {
  final double todayTotal;
  final int todayCount;
  final double thisMonthTotal;
  final int thisMonthCount;
  final double dailyAvg;
  final int daysElapsed;

  AnalyticsSummary({
    required this.todayTotal,
    required this.todayCount,
    required this.thisMonthTotal,
    required this.thisMonthCount,
    required this.dailyAvg,
    required this.daysElapsed,
  });
}

class MonthlySpendingSummary {
  final DateTime selectedMonth;
  final double selectedMonthTotal;
  final int selectedMonthCount;
  final double previousMonthTotal;
  final int previousMonthCount;
  final double difference;
  final double percentageChange;
  final List<CategorySlice> categoryBreakdown;
  final List<StoreSlice> topStores;

  MonthlySpendingSummary({
    required this.selectedMonth,
    required this.selectedMonthTotal,
    required this.selectedMonthCount,
    required this.previousMonthTotal,
    required this.previousMonthCount,
    required this.difference,
    required this.percentageChange,
    required this.categoryBreakdown,
    required this.topStores,
  });
}

class CategorySlice {
  final String category;
  final double amount;
  final double percentage;

  CategorySlice({
    required this.category,
    required this.amount,
    required this.percentage,
  });
}

class DailyTrendPoint {
  final String date;
  final String displayDate;
  final double amount;

  DailyTrendPoint({
    required this.date,
    required this.displayDate,
    required this.amount,
  });
}

class StoreSlice {
  final String store;
  final double amount;
  final int count;
  final double percentage;

  StoreSlice({
    required this.store,
    required this.amount,
    required this.count,
    required this.percentage,
  });
}

class PaymentMethodSlice {
  final String method;
  final double amount;
  final int count;
  final double percentage;

  PaymentMethodSlice({
    required this.method,
    required this.amount,
    required this.count,
    required this.percentage,
  });
}

class AnalyticsService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<AnalyticsSummary> getDashboardSummary() async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final monthStartStr = DateFormat('yyyy-MM-01').format(today);

    // Today metrics
    final todayRes = await db.rawQuery('''
      SELECT COUNT(id) as count, COALESCE(SUM(amount), 0.0) as total
      FROM expenses
      WHERE date = ? AND deleted_at IS NULL
    ''', [todayStr]);
    final todayCount = (todayRes.first['count'] as num?)?.toInt() ?? 0;
    final todayTotal = (todayRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // This month metrics
    final monthRes = await db.rawQuery('''
      SELECT COUNT(id) as count, COALESCE(SUM(amount), 0.0) as total
      FROM expenses
      WHERE date >= ? AND date <= ? AND deleted_at IS NULL
    ''', [monthStartStr, todayStr]);
    final monthCount = (monthRes.first['count'] as num?)?.toInt() ?? 0;
    final monthTotal = (monthRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final daysElapsed = today.day.clamp(1, 31);
    final dailyAvg = daysElapsed > 0 ? monthTotal / daysElapsed : 0.0;

    return AnalyticsSummary(
      todayTotal: todayTotal,
      todayCount: todayCount,
      thisMonthTotal: monthTotal,
      thisMonthCount: monthCount,
      dailyAvg: dailyAvg,
      daysElapsed: daysElapsed,
    );
  }

  Future<List<DailyTrendPoint>> getDailySpendingTrend({int days = 14}) async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final startDate = today.subtract(Duration(days: days - 1));
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(today);

    final rows = await db.rawQuery('''
      SELECT date, COALESCE(SUM(amount), 0.0) as total
      FROM expenses
      WHERE date >= ? AND date <= ? AND deleted_at IS NULL
      GROUP BY date
    ''', [startStr, endStr]);

    final dateMap = <String, double>{};
    for (final r in rows) {
      dateMap[r['date'] as String] = (r['total'] as num).toDouble();
    }

    final trend = <DailyTrendPoint>[];
    var cur = startDate;
    while (!cur.isAfter(today)) {
      final dStr = DateFormat('yyyy-MM-dd').format(cur);
      final disp = DateFormat('d MMM').format(cur);
      trend.add(
        DailyTrendPoint(
          date: dStr,
          displayDate: disp,
          amount: dateMap[dStr] ?? 0.0,
        ),
      );
      cur = cur.add(const Duration(days: 1));
    }

    return trend;
  }

  Future<List<CategorySlice>> getCategoryBreakdown({int days = 30}) async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final startDate = today.subtract(Duration(days: days - 1));
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(today);

    final rows = await db.rawQuery('''
      SELECT COALESCE(t.name, 'Uncategorized') as category,
             COALESCE(SUM(e.amount), 0.0) as total
      FROM expenses e
      LEFT JOIN tags t ON e.tag_id = t.id
      WHERE e.date >= ? AND e.date <= ? AND e.deleted_at IS NULL
      GROUP BY category
      ORDER BY total DESC
    ''', [startStr, endStr]);

    double totalSum = 0.0;
    for (final r in rows) {
      totalSum += (r['total'] as num).toDouble();
    }

    return rows.map((r) {
      final amt = (r['total'] as num).toDouble();
      final pct = totalSum > 0 ? (amt / totalSum) * 100 : 0.0;
      return CategorySlice(
        category: r['category'] as String,
        amount: amt,
        percentage: pct,
      );
    }).toList();
  }

  Future<List<StoreSlice>> getTopStores({int days = 30, int limit = 6}) async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final startDate = today.subtract(Duration(days: days - 1));
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(today);

    final rows = await db.rawQuery('''
      SELECT COALESCE(s.name, 'Unspecified Merchant') as store_name,
             COALESCE(SUM(e.amount), 0.0) as total,
             COUNT(e.id) as count
      FROM expenses e
      LEFT JOIN stores s ON e.store_id = s.id
      WHERE e.date >= ? AND e.date <= ? AND e.deleted_at IS NULL
      GROUP BY store_name
      ORDER BY total DESC
      LIMIT ?
    ''', [startStr, endStr, limit]);

    double totalSum = 0.0;
    for (final r in rows) {
      totalSum += (r['total'] as num).toDouble();
    }

    return rows.map((r) {
      final amt = (r['total'] as num).toDouble();
      final cnt = (r['count'] as num).toInt();
      final pct = totalSum > 0 ? (amt / totalSum) * 100 : 0.0;
      return StoreSlice(
        store: r['store_name'] as String,
        amount: amt,
        count: cnt,
        percentage: pct,
      );
    }).toList();
  }

  Future<List<PaymentMethodSlice>> getPaymentMethodBreakdown({int days = 30}) async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final startDate = today.subtract(Duration(days: days - 1));
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(today);

    final rows = await db.rawQuery('''
      SELECT payment_method,
             COALESCE(SUM(amount), 0.0) as total,
             COUNT(id) as count
      FROM expenses
      WHERE date >= ? AND date <= ? AND deleted_at IS NULL
      GROUP BY payment_method
      ORDER BY total DESC
    ''', [startStr, endStr]);

    double totalSum = 0.0;
    for (final r in rows) {
      totalSum += (r['total'] as num).toDouble();
    }

    return rows.map((r) {
      final amt = (r['total'] as num).toDouble();
      final cnt = (r['count'] as num).toInt();
      final pct = totalSum > 0 ? (amt / totalSum) * 100 : 0.0;
      return PaymentMethodSlice(
        method: r['payment_method'] as String,
        amount: amt,
        count: cnt,
        percentage: pct,
      );
    }).toList();
  }

  Future<MonthlySpendingSummary> getMonthlySpendingSummary(DateTime targetMonth) async {
    final db = await _dbHelper.database;
    final selectedMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    final selStartStr = DateFormat('yyyy-MM-01').format(selectedMonth);
    final selEndStr = DateFormat('yyyy-MM-dd').format(lastDay);

    final prevMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
    final prevLastDay = DateTime(prevMonth.year, prevMonth.month + 1, 0);
    final prevStartStr = DateFormat('yyyy-MM-01').format(prevMonth);
    final prevEndStr = DateFormat('yyyy-MM-dd').format(prevLastDay);

    // 1. Selected month total and count
    final selRes = await db.rawQuery('''
      SELECT COUNT(id) as count, COALESCE(SUM(amount), 0.0) as total
      FROM expenses
      WHERE date >= ? AND date <= ? AND deleted_at IS NULL
    ''', [selStartStr, selEndStr]);
    final selCount = (selRes.first['count'] as num?)?.toInt() ?? 0;
    final selTotal = (selRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // 2. Previous month total and count
    final prevRes = await db.rawQuery('''
      SELECT COUNT(id) as count, COALESCE(SUM(amount), 0.0) as total
      FROM expenses
      WHERE date >= ? AND date <= ? AND deleted_at IS NULL
    ''', [prevStartStr, prevEndStr]);
    final prevCount = (prevRes.first['count'] as num?)?.toInt() ?? 0;
    final prevTotal = (prevRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final diff = selTotal - prevTotal;
    final pctChange = prevTotal > 0.0 ? ((selTotal - prevTotal) / prevTotal) * 100 : 0.0;

    // 3. Category-wise breakdown for selected month
    final catRows = await db.rawQuery('''
      SELECT COALESCE(t.name, 'Uncategorized') as category,
             COALESCE(SUM(e.amount), 0.0) as total
      FROM expenses e
      LEFT JOIN tags t ON e.tag_id = t.id
      WHERE e.date >= ? AND e.date <= ? AND e.deleted_at IS NULL
      GROUP BY category
      ORDER BY total DESC
    ''', [selStartStr, selEndStr]);

    final categories = catRows.map((r) {
      final amt = (r['total'] as num).toDouble();
      final pct = selTotal > 0 ? (amt / selTotal) * 100 : 0.0;
      return CategorySlice(
        category: r['category'] as String,
        amount: amt,
        percentage: pct,
      );
    }).toList();

    // 4. Top merchants for selected month
    final storeRows = await db.rawQuery('''
      SELECT COALESCE(s.name, 'Unspecified Merchant') as store_name,
             COALESCE(SUM(e.amount), 0.0) as total,
             COUNT(e.id) as count
      FROM expenses e
      LEFT JOIN stores s ON e.store_id = s.id
      WHERE e.date >= ? AND e.date <= ? AND e.deleted_at IS NULL
      GROUP BY store_name
      ORDER BY total DESC
      LIMIT 6
    ''', [selStartStr, selEndStr]);

    final stores = storeRows.map((r) {
      final amt = (r['total'] as num).toDouble();
      final cnt = (r['count'] as num).toInt();
      final pct = selTotal > 0 ? (amt / selTotal) * 100 : 0.0;
      return StoreSlice(
        store: r['store_name'] as String,
        amount: amt,
        count: cnt,
        percentage: pct,
      );
    }).toList();

    return MonthlySpendingSummary(
      selectedMonth: selectedMonth,
      selectedMonthTotal: selTotal,
      selectedMonthCount: selCount,
      previousMonthTotal: prevTotal,
      previousMonthCount: prevCount,
      difference: diff,
      percentageChange: pctChange,
      categoryBreakdown: categories,
      topStores: stores,
    );
  }
}
