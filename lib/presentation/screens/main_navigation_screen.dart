import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../state/app_state.dart';
import 'add_expense_screen.dart';
import 'dashboard_screen.dart';
import 'more_screen.dart';
import 'pending_transaction_screen.dart';
import 'quick_add_screen.dart';
import 'transactions_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  StreamSubscription<String>? _pendingTapSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialPendingTransaction();
      _listenToPendingTaps();
    });
  }

  @override
  void dispose() {
    _pendingTapSub?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialPendingTransaction() async {
    final state = context.read<AppState>();
    final initialId = await state.smsTrackingService.getInitialPendingId();
    if (initialId != null && initialId.isNotEmpty && mounted) {
      _openPendingTransaction(initialId);
    }
  }

  void _listenToPendingTaps() {
    final state = context.read<AppState>();
    _pendingTapSub = state.smsTrackingService.onPendingTapped.listen((pendingId) {
      if (mounted) {
        _openPendingTransaction(pendingId);
      }
    });
  }

  String? _currentlyOpenedPendingId;

  Future<void> _openPendingTransaction(String pendingId) async {
    if (_currentlyOpenedPendingId == pendingId) return;
    _currentlyOpenedPendingId = pendingId;
    try {
      final state = context.read<AppState>();
      final tx = await state.getPendingTransactionById(pendingId);
      if (tx != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PendingTransactionScreen(
              transaction: tx,
              onConfirmed: () {
                if (mounted) {
                  setState(() {
                    _currentIndex = 0;
                  });
                }
              },
            ),
          ),
        );
      }
    } finally {
      _currentlyOpenedPendingId = null;
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigateTab: _onTabTapped),
      const QuickAddScreen(),
      AddExpenseScreen(onExpenseAdded: () => _onTabTapped(0)),
      const TransactionsScreen(),
      const MoreScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
          border: const Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: SafeArea(
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: AppTheme.accent,
              indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary);
                }
                return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.muted);
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: AppTheme.textPrimary, size: 22);
                }
                return const IconThemeData(color: AppTheme.muted, size: 22);
              }),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabTapped,
              backgroundColor: AppTheme.surface,
              elevation: 0,
              height: 64,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bolt_outlined),
                  selectedIcon: Icon(Icons.bolt_rounded),
                  label: 'Quick Add',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_circle_outline_rounded),
                  selectedIcon: Icon(Icons.add_circle_rounded),
                  label: 'Add',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Ledger',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz_rounded),
                  selectedIcon: Icon(Icons.more_horiz_rounded),
                  label: 'More',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

