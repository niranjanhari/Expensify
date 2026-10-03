import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../state/app_state.dart';

class ManageMerchantsScreen extends StatefulWidget {
  const ManageMerchantsScreen({super.key});

  @override
  State<ManageMerchantsScreen> createState() => _ManageMerchantsScreenState();
}

class _ManageMerchantsScreenState extends State<ManageMerchantsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _stores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoading = true);
    final state = context.read<AppState>();
    final data = await state.getStoresWithExpenseCount();
    if (mounted) {
      setState(() {
        _stores = data;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredStores {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _stores;
    return _stores.where((s) {
      final name = (s['name'] as String? ?? '').toLowerCase();
      final norm = (s['normalized_name'] as String? ?? '').toLowerCase();
      return name.contains(query) || norm.contains(query);
    }).toList();
  }

  Future<void> _showRenameDialog(Map<String, dynamic> store) async {
    final storeId = store['id'] as String;
    final currentName = store['name'] as String;
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Merchant', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: const InputDecoration(labelText: 'Merchant Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(dialogCtx, text);
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName && mounted) {
      final state = context.read<AppState>();
      await state.renameStore(storeId, newName);
      if (mounted) {
        _loadStores();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renamed to "$newName".'),
            backgroundColor: AppTheme.textPrimary,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteDialog(Map<String, dynamic> store) async {
    final storeId = store['id'] as String;
    final name = store['name'] as String;
    final count = store['expense_count'] as int? ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed, size: 24),
            SizedBox(width: 8),
            Text('Delete Merchant?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "$name"?',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              count > 0
                  ? 'Note: $count associated expense${count == 1 ? '' : 's'} will NOT be deleted. Their merchant will become unassigned.'
                  : 'This merchant will be removed from your saved list.',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final state = context.read<AppState>();
      await state.deleteStore(storeId);
      if (mounted) {
        _loadStores();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "$name". Expenses remain intact.'),
            backgroundColor: AppTheme.textPrimary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStores;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Manage Merchants', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppTheme.textPrimary)),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search saved merchants...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Merchant List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.textPrimary))
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'No saved merchants recorded yet.'
                              : 'No merchants match "${_searchController.text}".',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final store = filtered[idx];
                          final name = store['name'] as String;
                          final count = store['expense_count'] as int? ?? 0;
                          final defaultTag = store['default_tag_name'] as String?;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: AppTheme.transactionCardDecoration,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.iconBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.storefront_outlined, color: AppTheme.textPrimary, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$count expense${count == 1 ? '' : 's'}${defaultTag != null ? ' • $defaultTag' : ''}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                                  tooltip: 'Rename',
                                  onPressed: () => _showRenameDialog(store),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.expenseRed),
                                  tooltip: 'Delete',
                                  onPressed: () => _showDeleteDialog(store),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

