import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../domain/models/quick_add_suggestion.dart';
import '../state/app_state.dart';

class QuickAddScreen extends StatelessWidget {
  const QuickAddScreen({super.key});

  void _showPinDialog(BuildContext context, AppState state) {
    final amtController = TextEditingController(text: '50.00');
    final descController = TextEditingController();
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
              title: const Text(
                'Pin New Shortcut',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amtController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        labelText: 'Amount (${state.currency}) *',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStoreId,
                      decoration: const InputDecoration(labelText: 'Store / Merchant'),
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
                      decoration: const InputDecoration(labelText: 'Category'),
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ...state.tags.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                      ],
                      onChanged: (val) => setDialogState(() => selectedTagId = val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'e.g. Daily Coffee, Metro',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPayment,
                      decoration: const InputDecoration(labelText: 'Payment Method'),
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      items: paymentMethods.map((pm) => DropdownMenuItem(value: pm, child: Text(pm))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedPayment = val);
                      },
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
                    final amt = double.tryParse(amtController.text.trim());
                    if (amt != null && amt > 0) {
                      state.pinQuickAdd(
                        amount: amt,
                        storeId: selectedStoreId,
                        tagId: selectedTagId,
                        description: descController.text.trim(),
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
                  child: const Text('Pin Shortcut', style: TextStyle(fontWeight: FontWeight.w700)),
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
    final items = state.quickAddItems;
    final currency = state.currency;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Quick Add', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.push_pin_outlined, size: 22, color: AppTheme.textPrimary),
            tooltip: 'Pin Shortcut',
            onPressed: () => _showPinDialog(context, state),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: items.isEmpty
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
                      child: const Icon(Icons.bolt_rounded, size: 40, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No shortcuts detected yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Log repeat expenses or tap the pin icon above to create your own 1-tap shortcut.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: () => _showPinDialog(context, state),
                      icon: const Icon(Icons.add_rounded, size: 20, color: AppTheme.textPrimary),
                      label: const Text('Pin Custom Shortcut', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        elevation: 0,
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
                const Text(
                  'Ranked by frequency and recency. Log frequent purchases with a single tap.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ...items.map((item) => _buildQuickAddTile(context, item, state, currency)),
              ],
            ),
    );
  }

  Widget _buildQuickAddTile(BuildContext context, QuickAddSuggestion item, AppState state, String currency) {
    final title = item.description.isNotEmpty
        ? item.description
        : (item.storeName != 'Unspecified' ? item.storeName : item.tagName);
    final subInfo = item.storeName != 'Unspecified' ? '${item.storeName} • ${item.tagName}' : item.tagName;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusTransaction),
        boxShadow: AppTheme.subtleShadow,
        border: Border.all(
          color: item.isPinned ? AppTheme.accent : AppTheme.border,
          width: item.isPinned ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(item.icon, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isPinned) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.push_pin_rounded, size: 14, color: AppTheme.textPrimary),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(subInfo, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currency${NumberFormat('#,##0.00').format(item.amount)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => state.hideQuickAdd(item),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text('Hide', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () async {
                      await state.executeQuickAdd(item);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Recorded $currency${item.amount.toStringAsFixed(2)} for $title.'),
                            backgroundColor: AppTheme.textPrimary,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Log Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

