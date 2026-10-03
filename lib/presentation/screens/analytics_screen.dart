import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/services/analytics_service.dart';
import '../state/app_state.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isLoading = true;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  MonthlySpendingSummary? _monthlySummary;
  List<DailyTrendPoint> _trend = [];
  List<PaymentMethodSlice> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final monthlyFuture = _analyticsService.getMonthlySpendingSummary(_selectedMonth);
      final trendFuture = _analyticsService.getDailySpendingTrend(days: 14);
      final pmFuture = _analyticsService.getPaymentMethodBreakdown(days: 30);

      final results = await Future.wait([monthlyFuture, trendFuture, pmFuture]);

      if (mounted) {
        setState(() {
          _monthlySummary = results[0] as MonthlySpendingSummary;
          _trend = results[1] as List<DailyTrendPoint>;
          _paymentMethods = results[2] as List<PaymentMethodSlice>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _changeMonth(int delta) {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    if (next.isAfter(currentMonthStart)) return;

    setState(() {
      _selectedMonth = next;
    });
    _loadAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currency = state.currency;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22, color: AppTheme.textPrimary),
            onPressed: _loadAnalytics,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.textPrimary))
          : RefreshIndicator(
              color: AppTheme.textPrimary,
              backgroundColor: AppTheme.surface,
              onRefresh: _loadAnalytics,
              child: ListView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                children: [
                  // Month Selector Bar
                  _buildMonthSelector(),
                  const SizedBox(height: 14),

                  // Monthly Spending Overview Card
                  if (_monthlySummary != null)
                    _buildMonthlyOverviewCard(_monthlySummary!, currency),

                  const SizedBox(height: 24),

                  // Category Breakdown (For Selected Month)
                  _buildSectionHeader('Category Breakdown (${DateFormat('MMMM yyyy').format(_selectedMonth)})'),
                  const SizedBox(height: 10),
                  _buildCategoryList(_monthlySummary?.categoryBreakdown ?? [], currency),

                  const SizedBox(height: 24),

                  // Top Merchants (For Selected Month)
                  _buildSectionHeader('Top Merchants (${DateFormat('MMMM yyyy').format(_selectedMonth)})'),
                  const SizedBox(height: 10),
                  _buildStoreList(_monthlySummary?.topStores ?? [], currency),

                  const SizedBox(height: 24),

                  // Spending Trend Chart (Last 14 Days)
                  _buildSectionHeader('Spending Trend (Last 14 Days)'),
                  const SizedBox(height: 10),
                  _buildTrendBars(currency),

                  const SizedBox(height: 24),

                  // Payment Method Distribution
                  _buildSectionHeader('Payment Methods (Last 30 Days)'),
                  const SizedBox(height: 10),
                  _buildPaymentMethodList(currency),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthSelector() {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
            color: AppTheme.textPrimary,
            onPressed: () => _changeMonth(-1),
            tooltip: 'Previous Month',
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_outlined, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                monthLabel,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              if (_isCurrentMonth) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Current',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 24),
            color: _isCurrentMonth ? AppTheme.inactiveGray : AppTheme.textPrimary,
            onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
            tooltip: _isCurrentMonth ? 'Current Month' : 'Next Month',
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyOverviewCard(MonthlySpendingSummary summary, String currency) {
    final diff = summary.difference;
    final pct = summary.percentageChange.abs();
    final isIncrease = diff > 0;
    final isZero = diff == 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MONTHLY SPENDING',
                style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: AppTheme.textSecondary, fontWeight: FontWeight.w700),
              ),
              if (!isZero)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isIncrease ? const Color(0x14FF5A5F) : const Color(0x147ED321),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isIncrease ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 13,
                        color: isIncrease ? AppTheme.expenseRed : AppTheme.positiveGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${pct.toStringAsFixed(1)}% vs prev month',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isIncrease ? AppTheme.expenseRed : AppTheme.positiveGreen,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x14767676),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Same as prev month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$currency${NumberFormat('#,##0.00').format(summary.selectedMonthTotal)}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: AppTheme.border),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PREVIOUS MONTH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                  const SizedBox(height: 3),
                  Text(
                    '$currency${NumberFormat('#,##0.00').format(summary.previousMonthTotal)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              Container(height: 24, width: 1, color: AppTheme.border),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('TRANSACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                  const SizedBox(height: 3),
                  Text(
                    '${summary.selectedMonthCount} tx',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              Container(height: 24, width: 1, color: AppTheme.border),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('DIFFERENCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                  const SizedBox(height: 3),
                  Text(
                    '${diff >= 0 ? '+' : '-'}$currency${NumberFormat('#,##0.00').format(diff.abs())}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isZero ? AppTheme.textPrimary : (isIncrease ? AppTheme.expenseRed : AppTheme.positiveGreen),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
    );
  }

  Widget _buildTrendBars(String currency) {
    if (_trend.isEmpty || _trend.every((p) => p.amount == 0)) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.whiteCardDecoration,
        child: const Center(
          child: Text('No expense data recorded in the last 14 days.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      );
    }

    final maxVal = _trend.map((p) => p.amount).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal > 0 ? maxVal : 1.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _trend.map((point) {
                final heightFactor = (point.amount / effectiveMax).clamp(0.06, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (point.amount > 0)
                          Text(
                            point.amount >= 1000 ? '${(point.amount / 1000).toStringAsFixed(1)}k' : point.amount.toInt().toString(),
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                          ),
                        const SizedBox(height: 3),
                        Container(
                          height: 85 * heightFactor,
                          decoration: BoxDecoration(
                            color: point.amount > 0 ? AppTheme.accent : const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(6),
                            border: point.amount > 0 ? Border.all(color: const Color(0xFFC4E800), width: 0.5) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_trend.first.displayDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              Text(_trend.last.displayDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(List<CategorySlice> categories, String currency) {
    if (categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.whiteCardDecoration,
        child: const Center(
          child: Text('No categorized expenses recorded for this month.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      );
    }

    return Column(
      children: categories.map((c) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.transactionCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(c.category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  Text(
                    '$currency${NumberFormat('#,##0.00').format(c.amount)} (${c.percentage.toStringAsFixed(1)}%)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: c.percentage / 100,
                  backgroundColor: const Color(0xFFEEEEEE),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  minHeight: 7,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStoreList(List<StoreSlice> stores, String currency) {
    if (stores.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.whiteCardDecoration,
        child: const Center(
          child: Text('No merchant expenses recorded for this month.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      );
    }

    return Column(
      children: stores.map((s) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: AppTheme.transactionCardDecoration,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.store, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('${s.count} transaction${s.count == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Text(
                '$currency${NumberFormat('#,##0.00').format(s.amount)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentMethodList(String currency) {
    if (_paymentMethods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.whiteCardDecoration,
        child: const Center(
          child: Text('No payment method history logged yet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      );
    }

    return Column(
      children: _paymentMethods.map((pm) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: AppTheme.transactionCardDecoration,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(pm.method, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              Text(
                '$currency${NumberFormat('#,##0.00').format(pm.amount)} (${pm.count})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

