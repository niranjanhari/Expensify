import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../domain/models/expense.dart';
import '../state/app_state.dart';
import 'pending_transaction_screen.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int) onNavigateTab;

  const DashboardScreen({super.key, required this.onNavigateTab});

  static IconData getCategoryIcon(String? categoryName) {
    if (categoryName == null) return Icons.receipt_outlined;
    final lower = categoryName.toLowerCase();
    if (lower.contains('food') || lower.contains('dining') || lower.contains('restaurant') || lower.contains('meal') || lower.contains('lunch') || lower.contains('dinner')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('transport') || lower.contains('travel') || lower.contains('cab') || lower.contains('uber') || lower.contains('auto') || lower.contains('metro')) {
      return Icons.directions_car_rounded;
    }
    if (lower.contains('shopping') || lower.contains('cloth') || lower.contains('amazon')) {
      return Icons.shopping_bag_outlined;
    }
    if (lower.contains('rent') || lower.contains('home') || lower.contains('house')) {
      return Icons.home_outlined;
    }
    if (lower.contains('bill') || lower.contains('recharge') || lower.contains('utility') || lower.contains('electricity')) {
      return Icons.bolt_rounded;
    }
    if (lower.contains('grocery') || lower.contains('supermarket')) {
      return Icons.local_grocery_store_outlined;
    }
    if (lower.contains('health') || lower.contains('med') || lower.contains('doctor')) {
      return Icons.medical_services_outlined;
    }
    if (lower.contains('entertain') || lower.contains('movie') || lower.contains('fun')) {
      return Icons.movie_outlined;
    }
    return Icons.receipt_outlined;
  }

  void _showSetBalanceDialog(BuildContext context, AppState state) {
    final curBal = state.balance.isConfigured ? state.balance.currentBalance : 10000.0;
    final amtController = TextEditingController(text: curBal.toStringAsFixed(2));
    final noteController = TextEditingController(text: state.balance.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          title: Text(
            state.balance.isConfigured ? 'Update Bank Balance' : 'Set Initial Balance',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your actual bank account balance. New expenses will automatically deduct from this baseline.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: amtController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Current Balance (${state.currency})',
                  prefixText: '${state.currency} ',
                  prefixStyle: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Primary Bank Account',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amtController.text.trim());
                if (amt != null && amt >= 0) {
                  state.updateBalance(amt, notes: noteController.text.trim());
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Balance'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currency = state.currency;
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expensify',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5),
            ),
            Text(
              monthName,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22, color: AppTheme.textPrimary),
            tooltip: 'Refresh Local Data',
            onPressed: () => state.loadAllData(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.textPrimary))
          : RefreshIndicator(
              color: AppTheme.textPrimary,
              backgroundColor: AppTheme.surface,
              onRefresh: () => state.loadAllData(),
              child: ListView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                children: [
                  // 1. PROMINENT ROUNDED LIME (#D0F500) HERO CARD
                  _buildBalanceHeroCard(context, state, currency),

                  const SizedBox(height: 16),

                  // 2. SPENDING SUMMARY WHITE CARD
                  _buildSpendingSummaryCard(state, currency),

                  // 3. PENDING SMS TRANSACTIONS NOTICE IF ANY
                  if (state.pendingTransactions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildPendingTransactionsNotice(context, state),
                  ],

                  // 4. RECURRING DUE NOTICE IF ANY
                  if (state.dueRecurring.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildRecurringNotice(context, state),
                  ],

                  const SizedBox(height: 24),

                  // 4. QUICK ACTIONS
                  _buildSectionTitle('Quick Actions'),
                  const SizedBox(height: 12),
                  _buildQuickActionsGrid(context),

                  const SizedBox(height: 26),

                  // 5. RECENT TRANSACTIONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Recent Transactions'),
                      InkWell(
                        onTap: () => onNavigateTab(3), // Navigate to Ledger
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            'View all →',
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildRecentTransactionsList(state, currency),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceHeroCard(BuildContext context, AppState state, String currency) {
    final bal = state.balance;
    final isConfigured = bal.isConfigured;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.heroLimeCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CURRENT BALANCE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppTheme.textPrimary,
                ),
              ),
              InkWell(
                onTap: () => _showSetBalanceDialog(context, state),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConfigured ? Icons.edit_outlined : Icons.add_rounded,
                        size: 13,
                        color: AppTheme.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConfigured ? 'Adjust' : 'Set Balance',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isConfigured
                ? '$currency${NumberFormat('#,##0.00').format(bal.currentBalance)}'
                : 'Not Set',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isConfigured
                ? 'Baseline: $currency${NumberFormat('#,##0.00').format(bal.baselineAmount)} • $currency${NumberFormat('#,##0.00').format(bal.expensesSinceBaseline)} spent since baseline'
                : 'Tap "Set Balance" to track your real bank balance accurately.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary.withValues(alpha: 0.75),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingSummaryCard(AppState state, String currency) {
    final summary = state.summary;
    final todayTot = summary?.todayTotal ?? 0.0;
    final todayCount = summary?.todayCount ?? 0;
    final monthTot = summary?.thisMonthTotal ?? 0.0;
    final dailyAvg = summary?.dailyAvg ?? 0.0;

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
                'SPENDING SUMMARY',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Monthly',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('This Month', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      '$currency${NumberFormat('#,##0.00').format(monthTot)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$currency${NumberFormat('#,##0.00').format(dailyAvg)}/day avg',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                height: 44,
                width: 1,
                color: AppTheme.border,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Today', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      '$currency${NumberFormat('#,##0.00').format(todayTot)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$todayCount transaction${todayCount == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTransactionsNotice(BuildContext context, AppState state) {
    final count = state.pendingTransactions.length;
    final latest = state.pendingTransactions.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusTransaction),
        border: Border.all(color: AppTheme.accent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sms_outlined, size: 16, color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count payment${count == 1 ? '' : 's'} detected from SMS',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Latest: ${state.currency}${latest.amount.toStringAsFixed(0)} ${latest.parsedPayee != null ? "to ${latest.parsedPayee}" : ""}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PendingTransactionScreen(
                    transaction: latest,
                    onConfirmed: () => onNavigateTab(0),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Review →',
                style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringNotice(BuildContext context, AppState state) {
    final count = state.dueRecurring.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusTransaction),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined, size: 18, color: AppTheme.textPrimary),
              const SizedBox(width: 8),
              Text(
                '$count recurring payment${count == 1 ? '' : 's'} due.',
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          InkWell(
            onTap: () => onNavigateTab(4), // Navigate to Recurring / More
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                'Review →',
                style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => onNavigateTab(2), // Add Expense
            icon: const Icon(Icons.add_rounded, size: 22, color: AppTheme.textPrimary),
            label: const Text(
              'Add Expense',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                icon: Icons.bolt_rounded,
                label: 'Quick Add',
                onTap: () => onNavigateTab(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                icon: Icons.receipt_long_rounded,
                label: 'Ledger',
                onTap: () => onNavigateTab(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                icon: Icons.pie_chart_outline_rounded,
                label: 'Analytics',
                onTap: () => onNavigateTab(4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusTransaction),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: AppTheme.transactionCardDecoration,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppTheme.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsList(AppState state, String currency) {
    final recent = state.recentExpenses;

    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: AppTheme.whiteCardDecoration,
        child: const Center(
          child: Text(
            'No transactions recorded yet.\nUse Add Expense above to log your first purchase.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
        ),
      );
    }

    return Column(
      children: recent.map((exp) {
        return _buildTransactionCard(exp, currency);
      }).toList(),
    );
  }

  Widget _buildTransactionCard(Expense exp, String currency) {
    final store = exp.storeName ?? 'Unspecified';
    final tag = exp.tagName ?? 'General';
    final dateStr = DateFormat('d MMM').format(exp.date);
    final icon = getCategoryIcon(exp.tagName);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppTheme.transactionCardDecoration,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppTheme.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$tag • ${exp.description != null && exp.description!.isNotEmpty ? exp.description : exp.paymentMethod}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-$currency${NumberFormat('#,##0.00').format(exp.amount)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.expenseRed,
                ),
              ),
              const SizedBox(height: 3),
              Text(dateStr, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

