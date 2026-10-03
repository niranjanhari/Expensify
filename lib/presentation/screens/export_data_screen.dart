import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../state/app_state.dart';

class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  bool _isExporting = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  Future<void> _exportCsv(BuildContext context, AppState state) async {
    setState(() => _isExporting = true);
    try {
      final count = await state.exportExpensesCsv();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 0
                  ? 'CSV generated with headers (0 expenses recorded).'
                  : 'Successfully exported $count expense${count == 1 ? '' : 's'} as CSV.',
            ),
            backgroundColor: AppTheme.textPrimary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e'),
            backgroundColor: AppTheme.expenseRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _backupData(BuildContext context, AppState state) async {
    setState(() => _isBackingUp = true);
    try {
      final summary = await state.createAndShareBackup();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup created successfully (${summary['expensesCount']} expenses, ${summary['storesCount']} stores, ${summary['tagsCount']} tags).',
            ),
            backgroundColor: AppTheme.textPrimary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create backup: $e'),
            backgroundColor: AppTheme.expenseRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  Future<void> _restoreData(BuildContext context, AppState state) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      String jsonContent;
      if (file.bytes != null) {
        jsonContent = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonContent = await File(file.path!).readAsString(encoding: utf8);
      } else {
        throw Exception('Could not access the selected file.');
      }

      final summary = state.backupRestoreService.validateBackupJson(jsonContent);

      if (!context.mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed, size: 26),
              SizedBox(width: 8),
              Text('Restore Backup?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This backup contains:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Text('• ${summary['expensesCount']} expenses', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              Text('• ${summary['storesCount']} stores/merchants', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              Text('• ${summary['tagsCount']} categories/tags', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              Text('• ${summary['budgetsCount']} budgets', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              Text('• ${summary['recurringCount']} recurring rules', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              Text('• ${summary['quickAddCount']} quick-add pins', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.expenseRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Warning: Restoring will overwrite and replace all current local data with the contents of this backup. This cannot be undone.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.expenseRed, height: 1.3),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.expenseRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Restore Backup', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _isRestoring = true);
      final restoredCounts = await state.restoreBackup(summary['parsedData']);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restored successfully: ${restoredCounts['expenses']} expenses, ${restoredCounts['stores']} stores, ${restoredCounts['tags']} tags.',
            ),
            backgroundColor: AppTheme.textPrimary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore backup: $e'),
            backgroundColor: AppTheme.expenseRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Export & Data', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.textPrimary)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          // 1. Export Expenses Card
          const Text('SPREADSHEET EXPORT', style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.whiteCardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Export Expenses (CSV)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          SizedBox(height: 4),
                          Text('Export all active expenses to a CSV spreadsheet file. Compatible with Excel, Google Sheets, and Numbers.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: (_isExporting || _isBackingUp || _isRestoring) ? null : () => _exportCsv(context, state),
                    icon: _isExporting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary))
                        : const Icon(Icons.file_download_outlined, size: 18, color: AppTheme.textPrimary),
                    label: Text(
                      _isExporting ? 'Exporting...' : 'Export as CSV',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Full Backup Card
          const Text('FULL DATA BACKUP', style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.whiteCardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Backup Data (JSON)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          SizedBox(height: 4),
                          Text('Export all expenses, merchants, categories, budgets, and recurring rules into a portable, versioned JSON backup file.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: (_isExporting || _isBackingUp || _isRestoring) ? null : () => _backupData(context, state),
                    icon: _isBackingUp
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary))
                        : const Icon(Icons.backup_outlined, size: 18, color: AppTheme.textPrimary),
                    label: Text(
                      _isBackingUp ? 'Creating Backup...' : 'Backup Data',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surface,
                      foregroundColor: AppTheme.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppTheme.border)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Restore Backup Card
          const Text('RESTORE DATA', style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.whiteCardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Restore Backup (JSON)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          SizedBox(height: 4),
                          Text('Restore your Expensify database from a previous JSON backup file with atomic integrity protection.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: (_isExporting || _isBackingUp || _isRestoring) ? null : () => _restoreData(context, state),
                    icon: _isRestoring
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.expenseRed))
                        : const Icon(Icons.settings_backup_restore_outlined, size: 18, color: AppTheme.expenseRed),
                    label: Text(
                      _isRestoring ? 'Restoring Data...' : 'Restore Backup',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.expenseRed),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.expenseRed.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

