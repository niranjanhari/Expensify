import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'analytics_screen.dart';
import 'budgets_screen.dart';
import 'export_data_screen.dart';
import 'recurring_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('More Features', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.textPrimary)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          _buildMenuTile(
            context,
            icon: Icons.pie_chart_outline_rounded,
            title: 'Analytics & Insights',
            subtitle: 'Spending trends, category breakdown, top merchants',
            destination: const AnalyticsScreen(),
          ),
          const SizedBox(height: 12),
          _buildMenuTile(
            context,
            icon: Icons.savings_outlined,
            title: 'Budgets & Limits',
            subtitle: 'Monthly targets, category limits, headroom monitoring',
            destination: const BudgetsScreen(),
          ),
          const SizedBox(height: 12),
          _buildMenuTile(
            context,
            icon: Icons.repeat_rounded,
            title: 'Recurring Schedules',
            subtitle: 'Fixed bills, recharge routines, confirmation alerts',
            destination: const RecurringScreen(),
          ),
          const SizedBox(height: 12),
          _buildMenuTile(
            context,
            icon: Icons.import_export_rounded,
            title: 'Export & Data',
            subtitle: 'Export expenses to CSV, create & restore JSON backups',
            destination: const ExportDataScreen(),
          ),
          const SizedBox(height: 12),
          _buildMenuTile(
            context,
            icon: Icons.tune_rounded,
            title: 'Settings & Bank Balance',
            subtitle: 'Manage merchants, categories, baseline, currency',
            destination: const SettingsScreen(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusTransaction),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.transactionCardDecoration,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.textPrimary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}


