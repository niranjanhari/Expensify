import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../state/app_state.dart';
import 'dashboard_screen.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    final state = context.read<AppState>();
    final data = await state.getTagsWithExpenseCount();
    if (mounted) {
      setState(() {
        _tags = data;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredTags {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _tags;
    return _tags.where((t) {
      final name = (t['name'] as String? ?? '').toLowerCase();
      final desc = (t['description'] as String? ?? '').toLowerCase();
      return name.contains(query) || desc.contains(query);
    }).toList();
  }

  Future<void> _showRenameDialog(Map<String, dynamic> tag) async {
    final tagId = tag['id'] as String;
    final currentName = tag['name'] as String;
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: const InputDecoration(labelText: 'Category Name'),
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
      await state.renameTag(tagId, newName);
      if (mounted) {
        _loadTags();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renamed to "$newName".'),
            backgroundColor: AppTheme.textPrimary,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteDialog(Map<String, dynamic> tag) async {
    final tagId = tag['id'] as String;
    final name = tag['name'] as String;
    final count = tag['expense_count'] as int? ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed, size: 24),
            SizedBox(width: 8),
            Text('Delete Category?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary)),
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
                  ? 'Note: $count associated expense${count == 1 ? '' : 's'} will NOT be deleted. Their category will become unassigned.'
                  : 'This category will be removed from your saved list.',
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
      await state.deleteTag(tagId);
      if (mounted) {
        _loadTags();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "$name". Expenses remain intact.'),
            backgroundColor: AppTheme.textPrimary,
          ),
        );
      }
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g. Healthcare, Fitness, Travel',
                    errorText: errorMessage,
                  ),
                  onChanged: (_) {
                    if (errorMessage != null) {
                      setDialogState(() => errorMessage = null);
                    }
                  },
                ),
              ],
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
                onPressed: () async {
                  final raw = controller.text.trim();
                  if (raw.isEmpty) {
                    setDialogState(() {
                      errorMessage = 'Category name cannot be empty.';
                    });
                    return;
                  }

                  final duplicate = _tags.any(
                    (t) => (t['name'] as String? ?? '').trim().toLowerCase() == raw.toLowerCase(),
                  );
                  if (duplicate) {
                    setDialogState(() {
                      errorMessage = 'Category "$raw" already exists.';
                    });
                    return;
                  }

                  try {
                    final state = context.read<AppState>();
                    await state.addCategory(raw);
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    if (mounted) {
                      _loadTags();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Category "$raw" added successfully.'),
                          backgroundColor: AppTheme.textPrimary,
                        ),
                      );
                    }
                  } catch (e) {
                    setDialogState(() {
                      errorMessage = e.toString().replaceFirst('ArgumentError: ', '').replaceFirst('Exception: ', '');
                    });
                  }
                },
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTags;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Manage Categories', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 24),
            tooltip: 'Add Category',
            onPressed: _showAddCategoryDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 2,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                hintText: 'Search categories...',
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

          // Categories List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.textPrimary))
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'No categories found.'
                              : 'No categories match "${_searchController.text}".',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final tag = filtered[idx];
                          final name = tag['name'] as String;
                          final count = tag['expense_count'] as int? ?? 0;
                          final desc = tag['description'] as String?;
                          final icon = DashboardScreen.getCategoryIcon(name);

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
                                  child: Icon(icon, color: AppTheme.textPrimary, size: 20),
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
                                        '$count expense${count == 1 ? '' : 's'}${desc != null && desc.isNotEmpty ? ' • $desc' : ''}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                                  tooltip: 'Rename',
                                  onPressed: () => _showRenameDialog(tag),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.expenseRed),
                                  tooltip: 'Delete',
                                  onPressed: () => _showDeleteDialog(tag),
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

