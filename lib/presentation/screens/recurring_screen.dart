import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../domain/models/recurring_expense.dart';
import '../state/app_state.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  void _showAddRecurringDialog(BuildContext context, AppState state) {
    final descController = TextEditingController();
    final amtController = TextEditingController(text: '100.00');
    String selectedFreq = 'Monthly';
    DateTime selectedDate = DateTime.now();
    String? selectedStoreId;
    String? selectedTagId;
    String selectedPayment = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              ),
              title: const Text('New Recurring Template', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Description *', hintText: 'e.g. Phone Recharge, Netflix, Rent'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amtController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(labelText: 'Amount (${state.currency}) *'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFreq,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      items: ['Daily', 'Weekly', 'Monthly'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedFreq = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDialogState(() => selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('First Due Date', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            Text(DateFormat('d MMM yyyy').format(selectedDate), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStoreId,
                      decoration: const InputDecoration(labelText: 'Merchant (optional)'),
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ...state.stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                      ],
                      onChanged: (val) => setDialogState(() => selectedStoreId = val),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTagId,
                      decoration: const InputDecoration(labelText: 'Category (optional)'),
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ...state.tags.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                      ],
                      onChanged: (val) => setDialogState(() => selectedTagId = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final desc = descController.text.trim();
                    final amt = double.tryParse(amtController.text.trim());
                    if (desc.isNotEmpty && amt != null && amt > 0) {
                      state.createRecurring(
                        description: desc,
                        amount: amt,
                        frequency: selectedFreq,
                        nextDueDate: selectedDate,
                        storeId: selectedStoreId,
                        tagId: selectedTagId,
                        paymentMethod: selectedPayment,
                      );
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.textPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Schedule', style: TextStyle(fontWeight: FontWeight.w700)),
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
    final dueItems = state.dueRecurring;
    final allItems = state.allRecurring;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Recurring Expenses', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 24, color: AppTheme.textPrimary),
            onPressed: () => _showAddRecurringDialog(context, state),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          // 1. Due for confirmation section
          if (dueItems.isNotEmpty) ...[
            const Text('DUE FOR CONFIRMATION', style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...dueItems.map((rec) => _buildDueCard(context, rec, state, currency)),
            const SizedBox(height: 22),
          ],

          // 2. Active schedules list
          const Text('CONFIGURED SCHEDULES', style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (allItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: AppTheme.whiteCardDecoration,
              child: const Center(
                child: Text(
                  'No active recurring schedules.\nTap the + button to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                ),
              ),
            )
          else
            ...allItems.map((rec) => _buildScheduleCard(context, rec, state, currency)),
        ],
      ),
    );
  }

  Widget _buildDueCard(BuildContext context, RecurringExpense rec, AppState state, String currency) {
    final store = rec.storeName ?? 'Unspecified';
    final tag = rec.tagName ?? 'General';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  rec.description,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ),
              Text(
                '$currency${NumberFormat('#,##0.00').format(rec.amount)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('$store • $tag • ${rec.frequency}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => state.skipRecurring(rec.id),
                child: const Text('Skip', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  await state.confirmRecurring(rec.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Recorded $currency${rec.amount.toStringAsFixed(2)} for ${rec.description}.'),
                        backgroundColor: AppTheme.textPrimary,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Confirm Today', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context, RecurringExpense rec, AppState state, String currency) {
    final store = rec.storeName ?? 'Unspecified';
    final tag = rec.tagName ?? 'General';
    final nextDate = DateFormat('d MMM yyyy').format(rec.nextDueDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppTheme.transactionCardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec.description, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text('$store • $tag • ${rec.frequency} • Due: $nextDate', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$currency${NumberFormat('#,##0.00').format(rec.amount)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => state.deleteRecurring(rec.id),
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
    );
  }
}

