import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/services/nlp_parser_service.dart';
import '../state/app_state.dart';

class AddExpenseScreen extends StatefulWidget {
  final VoidCallback? onExpenseAdded;

  const AddExpenseScreen({super.key, this.onExpenseAdded});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Manual Form State
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedStoreId;
  String? _selectedStoreName;
  String? _selectedTagId;
  String? _selectedTagName;
  String _selectedPaymentMethod = 'Cash';
  DateTime _selectedDate = DateTime.now();
  final TimeOfDay _selectedTime = TimeOfDay.now();

  // Sentence Entry State
  final _sentenceController = TextEditingController();
  ParsedSentenceCandidate? _candidate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _descController.dispose();
    _sentenceController.dispose();
    super.dispose();
  }

  void _onStoreChanged(String? storeName, AppState state) {
    if (storeName == null) return;
    _selectedStoreName = storeName;
    final matched = state.stores.where((s) => s.name.toLowerCase() == storeName.toLowerCase()).toList();
    if (matched.isNotEmpty) {
      _selectedStoreId = matched.first.id;
      // Auto-suggest category if store has default tag
      if (matched.first.defaultTagId != null) {
        _selectedTagId = matched.first.defaultTagId;
        final t = state.tags.where((tag) => tag.id == _selectedTagId).toList();
        if (t.isNotEmpty) _selectedTagName = t.first.name;
      }
    } else {
      _selectedStoreId = null;
    }
    setState(() {});
  }

  Future<void> _submitManualExpense(AppState state) async {
    final amt = double.tryParse(_amountController.text.trim());
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount greater than zero.'),
          backgroundColor: AppTheme.textPrimary,
        ),
      );
      return;
    }

    // Resolve or create store
    String? finalStoreId = _selectedStoreId;
    if (finalStoreId == null && _selectedStoreName != null && _selectedStoreName!.trim().isNotEmpty) {
      final s = await state.getOrCreateStore(_selectedStoreName!.trim());
      finalStoreId = s.id;
    }

    // Resolve or create tag
    String? finalTagId = _selectedTagId;
    if (finalTagId == null && _selectedTagName != null && _selectedTagName!.trim().isNotEmpty) {
      final t = await state.getOrCreateTag(_selectedTagName!.trim());
      finalTagId = t.id;
    }

    final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    await state.addExpense(
      amount: amt,
      date: _selectedDate,
      time: timeStr,
      description: _descController.text.trim(),
      storeId: finalStoreId,
      tagId: finalTagId,
      paymentMethod: _selectedPaymentMethod,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recorded ${state.currency}${amt.toStringAsFixed(2)} at ${_selectedStoreName ?? "merchant"}.'),
          backgroundColor: AppTheme.textPrimary,
        ),
      );
      _amountController.clear();
      _descController.clear();
      widget.onExpenseAdded?.call();
    }
  }

  void _parseSentence(AppState state) {
    final text = _sentenceController.text.trim();
    if (text.isEmpty) return;

    final knownStoreNames = state.stores.map((s) => s.name).toList();
    final parsed = NlpParserService.parseSentence(text, knownStores: knownStoreNames);
    setState(() {
      _candidate = parsed;
    });
  }

  Future<void> _confirmSentenceExpense(AppState state) async {
    if (_candidate == null || _candidate!.amount <= 0) return;

    final s = await state.getOrCreateStore(_candidate!.store);
    final t = await state.getOrCreateTag(_candidate!.tag);
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    await state.addExpense(
      amount: _candidate!.amount,
      date: now,
      time: timeStr,
      description: _candidate!.description,
      storeId: s.id,
      tagId: t.id,
      paymentMethod: _candidate!.paymentMethod,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recorded ${state.currency}${_candidate!.amount.toStringAsFixed(2)} for ${_candidate!.description}.'),
          backgroundColor: AppTheme.textPrimary,
        ),
      );
      _sentenceController.clear();
      setState(() {
        _candidate = null;
      });
      widget.onExpenseAdded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text(
          'Add Expense',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              labelColor: AppTheme.textPrimary,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'Manual Entry'),
                Tab(text: 'Sentence Entry'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildManualForm(state),
          _buildSentenceTab(state),
        ],
      ),
    );
  }

  Widget _buildManualForm(AppState state) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Dominant Prominent Amount Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: AppTheme.whiteCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'ENTER AMOUNT',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    state.currency,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IntrinsicWidth(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(fontSize: 36, color: AppTheme.inactiveGray, fontWeight: FontWeight.w800),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Merchant / Store Selector with Autocomplete
        const Text(
          'Store / Merchant',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return state.stores.map((s) => s.name);
            }
            return state.stores
                .where((s) => s.name.toLowerCase().contains(textEditingValue.text.toLowerCase()))
                .map((s) => s.name);
          },
          onSelected: (selection) => _onStoreChanged(selection, state),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'e.g. College Canteen, Starbucks, Amazon',
                prefixIcon: Icon(Icons.storefront_outlined, size: 20, color: AppTheme.textSecondary),
              ),
              onChanged: (val) {
                _selectedStoreName = val;
              },
            );
          },
        ),

        const SizedBox(height: 16),

        // Category Tag Selection
        const Text(
          'Category',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: state.tags.map((t) {
            final isSelected = _selectedTagId == t.id;
            return InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedTagId = null;
                    _selectedTagName = null;
                  } else {
                    _selectedTagId = t.id;
                    _selectedTagName = t.name;
                  }
                });
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusChip),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accent : AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusChip),
                  border: Border.all(
                    color: isSelected ? AppTheme.accent : AppTheme.border,
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Description
        const Text(
          'Description (optional)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _descController,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'e.g. Lunch thali, Metro card reload, Coffee',
            prefixIcon: Icon(Icons.notes_rounded, size: 20, color: AppTheme.textSecondary),
          ),
        ),

        const SizedBox(height: 16),

        // Date and Payment Method Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('d MMM yyyy').format(_selectedDate),
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPaymentMethod,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                    items: paymentMethods.map((pm) => DropdownMenuItem(value: pm, child: Text(pm))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPaymentMethod = val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Full Width Lime Save Expense Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => _submitManualExpense(state),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              ),
            ),
            child: const Text('Save Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSentenceTab(AppState state) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.whiteCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter spending in plain words',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Example: "Spent 80 at College Canteen for lunch using gpay" or "Paid 450 for Uber"',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
              TextField(
                controller: _sentenceController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                minLines: 2,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Type expense sentence...',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _parseSentence(state),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: AppTheme.textPrimary),
                  label: const Text('Parse Sentence (Offline)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
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
            ],
          ),
        ),
        if (_candidate != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('PARSED CANDIDATE', style: TextStyle(fontSize: 10, letterSpacing: 0.6, color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
                    ),
                    Text('${(_candidate!.confidence * 100).toInt()}% Confidence', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${state.currency}${_candidate!.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                _buildParsedItem('Merchant', _candidate!.store),
                _buildParsedItem('Category', _candidate!.tag),
                _buildParsedItem('Description', _candidate!.description),
                _buildParsedItem('Payment Method', _candidate!.paymentMethod),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _confirmSentenceExpense(state),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.textPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                    ),
                    child: const Text('Confirm & Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildParsedItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

