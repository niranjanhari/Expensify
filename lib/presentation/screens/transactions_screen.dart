import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/daos/expense_dao.dart';
import '../../domain/models/expense.dart';
import '../state/app_state.dart';
import 'dashboard_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final ExpenseDao _expenseDao = ExpenseDao();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  int _currentPage = 1;
  static const int _pageSize = 15;
  final String _sortOrder = 'desc';

  // Tracks last seen expenseChangeCount from AppState to detect mutations
  int _lastExpenseVersion = -1;

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedTagId;
  String? _selectedStoreId;
  String? _selectedPaymentMethod;
  bool _showFilters = false;

  // Query Result
  bool _isLoading = true;
  List<Expense> _items = [];
  int _totalCount = 0;
  double _totalAmount = 0.0;
  int _totalPages = 1;

  int get _activeFilterCount {
    int count = 0;
    if (_startDate != null || _endDate != null) count++;
    if (_selectedTagId != null) count++;
    if (_selectedStoreId != null) count++;
    if (_selectedPaymentMethod != null) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  void _onSearchChanged(String _) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _currentPage = 1;
        });
        _fetchTransactions();
      }
    });
  }

  void _clearAllFilters() {
    _debounceTimer?.cancel();
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedTagId = null;
      _selectedStoreId = null;
      _selectedPaymentMethod = null;
      _searchController.clear();
      _currentPage = 1;
    });
    _fetchTransactions();
  }

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final version = context.watch<AppState>().expenseChangeCount;
    if (version != _lastExpenseVersion) {
      _lastExpenseVersion = version;
      // Reset to page 1 so newly added expenses are immediately visible
      _currentPage = 1;
      _fetchTransactions();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    final res = await _expenseDao.getFilteredExpenses(
      searchQuery: _searchController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      tagIds: _selectedTagId != null ? [_selectedTagId!] : null,
      storeIds: _selectedStoreId != null ? [_selectedStoreId!] : null,
      paymentMethods: _selectedPaymentMethod != null ? [_selectedPaymentMethod!] : null,
      sortOrder: _sortOrder,
      page: _currentPage,
      pageSize: _pageSize,
    );

    setState(() {
      _items = res['items'] as List<Expense>;
      _totalCount = res['total_count'] as int;
      _totalAmount = res['total_amount'] as double;
      _totalPages = res['total_pages'] as int;
      _isLoading = false;
    });
  }

  void _showEditModal(BuildContext context, Expense exp, AppState state) {
    final amtController = TextEditingController(text: exp.amount.toStringAsFixed(2));
    final descController = TextEditingController(text: exp.description ?? '');
    DateTime editDate = exp.date;
    String? editStoreId = exp.storeId;
    String? editTagId = exp.tagId;
    String editPm = exp.paymentMethod;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Transaction',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amtController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Amount (${state.currency})',
                        prefixText: '${state.currency} ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: editStoreId,
                      decoration: const InputDecoration(labelText: 'Store / Merchant'),
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Unspecified')),
                        ...state.stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                      ],
                      onChanged: (val) => setSheetState(() => editStoreId = val),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: editTagId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Uncategorized')),
                        ...state.tags.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                      ],
                      onChanged: (val) => setSheetState(() => editTagId = val),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(labelText: 'Description / Note'),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: editDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) setSheetState(() => editDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Text(
                                DateFormat('d MMM yyyy').format(editDate),
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: editPm,
                            decoration: const InputDecoration(labelText: 'Payment'),
                            dropdownColor: AppTheme.surface,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            items: paymentMethods.map((pm) => DropdownMenuItem(value: pm, child: Text(pm))).toList(),
                            onChanged: (val) {
                              if (val != null) setSheetState(() => editPm = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amt = double.tryParse(amtController.text.trim());
                          if (amt != null && amt > 0) {
                            await state.updateExpense(
                              id: exp.id,
                              amount: amt,
                              date: editDate,
                              time: exp.time,
                              storeId: editStoreId,
                              tagId: editTagId,
                              description: descController.text.trim(),
                              paymentMethod: editPm,
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              _fetchTransactions();
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: AppTheme.textPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                        ),
                        child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, Expense exp, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
          title: const Text('Delete Expense?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          content: Text(
            'Are you sure you want to remove this transaction of ${state.currency}${exp.amount.toStringAsFixed(2)}? This deduction will be returned to your bank balance.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await state.deleteExpense(exp.id);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  _fetchTransactions();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.expenseRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
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
    final avgTicket = _totalCount > 0 ? _totalAmount / _totalCount : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Ledger', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _activeFilterCount > 0,
              label: Text('$_activeFilterCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              child: Icon(_showFilters ? Icons.filter_alt_rounded : Icons.filter_alt_outlined, size: 22),
            ),
            color: (_showFilters || _activeFilterCount > 0) ? AppTheme.textPrimary : AppTheme.textSecondary,
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search merchant, tag, note, or payment...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textSecondary),
                        onPressed: () {
                          _debounceTimer?.cancel();
                          _searchController.clear();
                          _currentPage = 1;
                          _fetchTransactions();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) {
                _debounceTimer?.cancel();
                _currentPage = 1;
                _fetchTransactions();
              },
            ),
          ),

          // Collapsible Multi-Filter Panel
          if (_showFilters)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(color: AppTheme.border),
                boxShadow: AppTheme.subtleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Date Range & Quick Presets
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                _startDate = picked.start;
                                _endDate = picked.end;
                                _currentPage = 1;
                              });
                              _fetchTransactions();
                            }
                          },
                          icon: const Icon(Icons.date_range_rounded, size: 16),
                          label: Text(
                            _startDate == null
                                ? 'Date Range'
                                : '${DateFormat('d MMM').format(_startDate!)} - ${DateFormat('d MMM').format(_endDate!)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _startDate != null ? AppTheme.accent : AppTheme.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        tooltip: 'Quick Presets',
                        icon: const Icon(Icons.schedule_rounded, size: 20, color: AppTheme.textSecondary),
                        onSelected: (val) {
                          final now = DateTime.now();
                          setState(() {
                            if (val == 'this_month') {
                              _startDate = DateTime(now.year, now.month, 1);
                              _endDate = DateTime(now.year, now.month + 1, 0);
                            } else if (val == 'last_month') {
                              _startDate = DateTime(now.year, now.month - 1, 1);
                              _endDate = DateTime(now.year, now.month, 0);
                            } else if (val == 'all_time') {
                              _startDate = null;
                              _endDate = null;
                            }
                            _currentPage = 1;
                          });
                          _fetchTransactions();
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'this_month', child: Text('This Month')),
                          const PopupMenuItem(value: 'last_month', child: Text('Last Month')),
                          const PopupMenuItem(value: 'all_time', child: Text('All Time')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 2: Category & Payment Method Filters
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedTagId,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          dropdownColor: AppTheme.surface,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Categories')),
                            ...state.tags.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedTagId = val;
                              _currentPage = 1;
                            });
                            _fetchTransactions();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedPaymentMethod,
                          decoration: InputDecoration(
                            labelText: 'Payment',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          dropdownColor: AppTheme.surface,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Payments')),
                            ...paymentMethods.map((pm) => DropdownMenuItem(value: pm, child: Text(pm))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedPaymentMethod = val;
                              _currentPage = 1;
                            });
                            _fetchTransactions();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 3: Merchant Filter & Clear All
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedStoreId,
                          decoration: InputDecoration(
                            labelText: 'Merchant',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          dropdownColor: AppTheme.surface,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Merchants')),
                            ...state.stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedStoreId = val;
                              _currentPage = 1;
                            });
                            _fetchTransactions();
                          },
                        ),
                      ),
                      if (_activeFilterCount > 0) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _clearAllFilters,
                          icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppTheme.expenseRed),
                          label: const Text('Clear All', style: TextStyle(color: AppTheme.expenseRed, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

          // Active Filter Chips Row
          if (_activeFilterCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_searchController.text.trim().isNotEmpty)
                      _buildFilterChip('Search: "${_searchController.text.trim()}"', () {
                        _searchController.clear();
                        _currentPage = 1;
                        _fetchTransactions();
                      }),
                    if (_startDate != null)
                      _buildFilterChip(
                        '${DateFormat('d MMM').format(_startDate!)} - ${DateFormat('d MMM').format(_endDate!)}',
                        () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                            _currentPage = 1;
                          });
                          _fetchTransactions();
                        },
                      ),
                    if (_selectedTagId != null)
                      _buildFilterChip(
                        'Tag: ${state.tags.firstWhere((t) => t.id == _selectedTagId, orElse: () => state.tags.first).name}',
                        () {
                          setState(() {
                            _selectedTagId = null;
                            _currentPage = 1;
                          });
                          _fetchTransactions();
                        },
                      ),
                    if (_selectedPaymentMethod != null)
                      _buildFilterChip(
                        'Payment: $_selectedPaymentMethod',
                        () {
                          setState(() {
                            _selectedPaymentMethod = null;
                            _currentPage = 1;
                          });
                          _fetchTransactions();
                        },
                      ),
                    if (_selectedStoreId != null)
                      _buildFilterChip(
                        'Store: ${state.stores.firstWhere((s) => s.id == _selectedStoreId, orElse: () => state.stores.first).name}',
                        () {
                          setState(() {
                            _selectedStoreId = null;
                            _currentPage = 1;
                          });
                          _fetchTransactions();
                        },
                      ),
                    ActionChip(
                      label: const Text('Clear All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.expenseRed)),
                      backgroundColor: const Color(0x14FF5A5F),
                      side: BorderSide.none,
                      onPressed: _clearAllFilters,
                    ),
                  ],
                ),
              ),
            ),

          // Aggregated Metrics Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusTransaction),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.subtleShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatPill('TOTAL SPENT', '$currency${NumberFormat('#,##0.00').format(_totalAmount)}'),
                Container(height: 24, width: 1, color: AppTheme.border),
                _buildStatPill('COUNT', '$_totalCount tx'),
                Container(height: 24, width: 1, color: AppTheme.border),
                _buildStatPill('AVG TICKET', '$currency${NumberFormat('#,##0.00').format(avgTicket)}'),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.textPrimary))
                : RefreshIndicator(
                    color: AppTheme.textPrimary,
                    backgroundColor: AppTheme.surface,
                    onRefresh: () async {
                      await state.loadAllData();
                      await _fetchTransactions();
                    },
                    child: _items.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                child: const Center(
                                  child: Text(
                                    'No transactions match your search.',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final exp = _items[idx];
                              return _buildTransactionRow(context, exp, state, currency);
                            },
                          ),
                  ),
          ),

          // Pagination Controls
          if (_totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: _currentPage > 1 ? AppTheme.textPrimary : AppTheme.inactiveGray,
                    onPressed: _currentPage > 1
                        ? () {
                            setState(() => _currentPage--);
                            _fetchTransactions();
                          }
                        : null,
                  ),
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: _currentPage < _totalPages ? AppTheme.textPrimary : AppTheme.inactiveGray,
                    onPressed: _currentPage < _totalPages
                        ? () {
                            setState(() => _currentPage++);
                            _fetchTransactions();
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.surface,
        deleteIcon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textSecondary),
        onDeleted: onDeleted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildStatPill(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, letterSpacing: 0.6, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildTransactionRow(BuildContext context, Expense exp, AppState state, String currency) {
    final store = exp.storeName ?? 'Unspecified';
    final tag = exp.tagName ?? 'General';
    final dateStr = DateFormat('d MMM yyyy').format(exp.date);
    final icon = DashboardScreen.getCategoryIcon(exp.tagName);

    return Container(
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        store,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.iconBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(tag, style: const TextStyle(fontSize: 10, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${exp.description != null && exp.description!.isNotEmpty ? exp.description : exp.paymentMethod} • $dateStr',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.expenseRed),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _showEditModal(context, exp, state),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined, size: 15, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _showDeleteDialog(context, exp, state),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.textSecondary),
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
}

