import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../domain/models/budget.dart';
import '../state/app_state.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  void _showSetBudgetDialog(BuildContext context, AppState state, {String? tagId, double? currentAmt}) {
    final amtController = TextEditingController(text: currentAmt?.toStringAsFixed(2) ?? '5000.00');
    String? selectedTagId = tagId;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isOverall = selectedTagId == null;
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              ),
              title: Text(
                isOverall ? 'Set Monthly Target' : 'Set Category Limit',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: selectedTagId,
                    decoration: const InputDecoration(labelText: 'Scope'),
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Overall Monthly Target')),
                      ...state.tags.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                    ],
                    onChanged: (val) => setDialogState(() => selectedTagId = val),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amtController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Target Amount (${state.currency})',
                      prefixText: '${state.currency} ',
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
                    if (amt != null && amt > 0) {
                      state.saveBudget(amount: amt, tagId: selectedTagId);
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.textPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Limit', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currency = state.currency;
    final budgetData = state.budgetProgress;
    final hasBudgets = budgetData['has_budgets'] as bool? ?? false;
    final overall = budgetData['overall'] as BudgetProgress?;
    final categories = (budgetData['categories'] as List<BudgetProgress>?) ?? [];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Budgets & Limits', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 24, color: AppTheme.textPrimary),
            onPressed: () => _showSetBudgetDialog(context, state),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !hasBudgets
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        color: AppTheme.iconBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.savings_outlined, size: 40, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No budget targets configured',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Set an overall monthly spending limit or category targets to monitor your financial headroom.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: () => _showSetBudgetDialog(context, state),
                      icon: const Icon(Icons.add_rounded, size: 20, color: AppTheme.textPrimary),
                      label: const Text('Set Monthly Target', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              children: [
                if (overall != null) ...[
                  const Text('MONTHLY TARGET', style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _buildBudgetCard(context, overall, state, currency, isOverall: true),
                  const SizedBox(height: 22),
                ],
                if (categories.isNotEmpty) ...[
                  const Text('CATEGORY TARGETS', style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...categories.map((c) => _buildBudgetCard(context, c, state, currency, isOverall: false)),
                ],
              ],
            ),
    );
  }

  Widget _buildBudgetCard(BuildContext context, BudgetProgress b, AppState state, String currency, {required bool isOverall}) {
    final pct = b.percentageUsed;
    final isExceeded = pct > 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                b.categoryName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isExceeded ? AppTheme.expenseRed.withValues(alpha: 0.12) : AppTheme.iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isExceeded ? AppTheme.expenseRed : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => state.deleteBudget(b.id),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$currency${NumberFormat('#,##0.00').format(b.spentAmount)} / $currency${NumberFormat('#,##0.00').format(b.budgetAmount)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation<Color>(isExceeded ? AppTheme.expenseRed : AppTheme.accent),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isExceeded ? 'Exceeded budget' : 'Remaining headroom',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              Text(
                '$currency${NumberFormat('#,##0.00').format(b.remainingAmount)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isExceeded ? AppTheme.expenseRed : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

