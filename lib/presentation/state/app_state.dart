import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../data/daos/balance_dao.dart';
import '../../data/daos/budget_dao.dart';
import '../../data/daos/expense_dao.dart';
import '../../data/daos/quick_add_dao.dart';
import '../../data/daos/recurring_dao.dart';
import '../../data/daos/store_dao.dart';
import '../../data/daos/tag_dao.dart';
import '../../data/daos/pending_transaction_dao.dart';
import '../../data/daos/payee_mapping_dao.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/backup_restore_service.dart';
import '../../data/services/csv_export_service.dart';
import '../../domain/models/account_balance.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/pending_transaction.dart';
import '../../domain/models/quick_add_suggestion.dart';
import '../../domain/models/recurring_expense.dart';
import '../../domain/models/store.dart';
import '../../domain/models/tag.dart';
import '../../domain/services/sms_tracking_service.dart';

class AppState extends ChangeNotifier {
  final BalanceDao _balanceDao = BalanceDao();
  final ExpenseDao _expenseDao = ExpenseDao();
  final QuickAddDao _quickAddDao = QuickAddDao();
  final BudgetDao _budgetDao = BudgetDao();
  final RecurringDao _recurringDao = RecurringDao();
  final StoreDao _storeDao = StoreDao();
  final TagDao _tagDao = TagDao();
  final PendingTransactionDao _pendingTransactionDao = PendingTransactionDao();
  final PayeeMappingDao _payeeMappingDao = PayeeMappingDao();
  final AnalyticsService _analyticsService = AnalyticsService();
  final CsvExportService _csvExportService = CsvExportService();
  final BackupRestoreService _backupRestoreService = BackupRestoreService();
  final SmsTrackingService _smsTrackingService = SmsTrackingService();

  BackupRestoreService get backupRestoreService => _backupRestoreService;
  AnalyticsService get analyticsService => _analyticsService;
  SmsTrackingService get smsTrackingService => _smsTrackingService;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  int _expenseChangeCount = 0;
  int get expenseChangeCount => _expenseChangeCount;

  String _currency = defaultCurrency;
  String get currency => _currency;

  BalanceCalculation _balance = BalanceCalculation(
    isConfigured: false,
    baselineAmount: 0.0,
    currentBalance: 0.0,
    expensesSinceBaseline: 0.0,
  );
  BalanceCalculation get balance => _balance;

  AnalyticsSummary? _summary;
  AnalyticsSummary? get summary => _summary;

  List<Expense> _recentExpenses = [];
  List<Expense> get recentExpenses => _recentExpenses;

  List<QuickAddSuggestion> _quickAddItems = [];
  List<QuickAddSuggestion> get quickAddItems => _quickAddItems;

  List<RecurringExpense> _dueRecurring = [];
  List<RecurringExpense> get dueRecurring => _dueRecurring;

  List<RecurringExpense> _allRecurring = [];
  List<RecurringExpense> get allRecurring => _allRecurring;

  Map<String, dynamic> _budgetProgress = {'has_budgets': false};
  Map<String, dynamic> get budgetProgress => _budgetProgress;

  List<Store> _stores = [];
  List<Store> get stores => _stores;

  List<Tag> _tags = [];
  List<Tag> get tags => _tags;

  List<PendingTransaction> _pendingTransactions = [];
  List<PendingTransaction> get pendingTransactions => _pendingTransactions;

  bool _isSmsTrackingEnabled = false;
  bool get isSmsTrackingEnabled => _isSmsTrackingEnabled;

  bool _hasSmsPermission = false;
  bool get hasSmsPermission => _hasSmsPermission;

  bool _hasNotificationPermission = false;
  bool get hasNotificationPermission => _hasNotificationPermission;

  bool get areSmsPermissionsGranted => _hasSmsPermission && _hasNotificationPermission;

  AppState() {
    loadAllData();
    _initSmsTracking();
  }

  void _initSmsTracking() {
    _smsTrackingService.onNewPending.listen((_) {
      _refreshPendingTransactions();
      notifyListeners();
    });
  }

  void setCurrency(String newCurrency) {
    _currency = newCurrency;
    notifyListeners();
  }

  Future<void> loadAllData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _refreshBalance(),
        _refreshSummary(),
        _refreshRecentExpenses(),
        _refreshQuickAdd(),
        _refreshRecurring(),
        _refreshBudgets(),
        _refreshStoresAndTags(),
        _refreshPendingTransactions(),
        refreshSmsPermissions(),
      ]);
    } catch (e) {
      debugPrint('Error loading app data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSmsPermissions() async {
    final status = await _smsTrackingService.getPermissionStatus();
    _hasSmsPermission = status.hasSmsPermission;
    _hasNotificationPermission = status.hasNotificationPermission;
    _isSmsTrackingEnabled = status.isTrackingEnabled;
    notifyListeners();
  }

  Future<void> _refreshPendingTransactions() async {
    _pendingTransactions = await _pendingTransactionDao.getPendingTransactions();
  }

  Future<void> _refreshBalance() async {
    _balance = await _balanceDao.getBalanceDetails();
  }

  Future<void> _refreshSummary() async {
    _summary = await _analyticsService.getDashboardSummary();
  }

  Future<void> _refreshRecentExpenses() async {
    _recentExpenses = await _expenseDao.getRecentExpenses(limit: 6);
  }

  Future<void> _refreshQuickAdd() async {
    _quickAddItems = await _quickAddDao.getQuickAddSuggestions(limit: 8);
  }

  Future<void> _refreshRecurring() async {
    _dueRecurring = await _recurringDao.getDueRecurringExpenses();
    _allRecurring = await _recurringDao.getAllRecurringExpenses(activeOnly: true);
  }

  Future<void> _refreshBudgets() async {
    _budgetProgress = await _budgetDao.getBudgetProgress();
  }

  Future<void> _refreshStoresAndTags() async {
    _stores = await _storeDao.getAllStores();
    _tags = await _tagDao.getAllTags();
  }

  // --- Actions ---

  Future<void> updateBalance(double newBaseline, {String? notes}) async {
    _balance = await _balanceDao.setAccountBalance(newBalance: newBaseline, notes: notes);
    notifyListeners();
  }

  Future<void> addExpense({
    required double amount,
    required DateTime date,
    String? time,
    String? description,
    String? storeId,
    String? tagId,
    String paymentMethod = 'Cash',
  }) async {
    await _expenseDao.createExpense(
      amount: amount,
      date: date,
      time: time,
      description: description,
      storeId: storeId,
      tagId: tagId,
      paymentMethod: paymentMethod,
    );

    await Future.wait([
      _refreshBalance(),
      _refreshSummary(),
      _refreshRecentExpenses(),
      _refreshQuickAdd(),
      _refreshBudgets(),
      _refreshStoresAndTags(),
    ]);
    _expenseChangeCount++;
    notifyListeners();
  }

  Future<void> updateExpense({
    required String id,
    required double amount,
    required DateTime date,
    String? time,
    String? description,
    String? storeId,
    String? tagId,
    required String paymentMethod,
  }) async {
    await _expenseDao.updateExpense(
      id: id,
      amount: amount,
      date: date,
      time: time,
      description: description,
      storeId: storeId,
      tagId: tagId,
      paymentMethod: paymentMethod,
    );

    await Future.wait([
      _refreshBalance(),
      _refreshSummary(),
      _refreshRecentExpenses(),
      _refreshQuickAdd(),
      _refreshBudgets(),
    ]);
    _expenseChangeCount++;
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    await _expenseDao.deleteExpense(id);

    await Future.wait([
      _refreshBalance(),
      _refreshSummary(),
      _refreshRecentExpenses(),
      _refreshQuickAdd(),
      _refreshBudgets(),
    ]);
    _expenseChangeCount++;
    notifyListeners();
  }

  Future<void> executeQuickAdd(QuickAddSuggestion item) async {
    await _quickAddDao.executeQuickAdd(item);

    await Future.wait([
      _refreshBalance(),
      _refreshSummary(),
      _refreshRecentExpenses(),
      _refreshQuickAdd(),
      _refreshBudgets(),
      _refreshStoresAndTags(),
    ]);
    _expenseChangeCount++;
    notifyListeners();
  }

  Future<void> pinQuickAdd({
    required double amount,
    String? storeId,
    String? tagId,
    String? description,
    String paymentMethod = 'Cash',
  }) async {
    await _quickAddDao.pinQuickAddItem(
      amount: amount,
      storeId: storeId,
      tagId: tagId,
      description: description,
      paymentMethod: paymentMethod,
    );
    await _refreshQuickAdd();
    notifyListeners();
  }

  Future<void> hideQuickAdd(QuickAddSuggestion item) async {
    await _quickAddDao.hideQuickAddItem(
      amount: item.amount,
      storeId: item.storeId,
      tagId: item.tagId,
      description: item.description,
    );
    await _refreshQuickAdd();
    notifyListeners();
  }

  Future<void> confirmRecurring(String recurringId) async {
    await _recurringDao.confirmAndLogRecurring(recurringId);
    await Future.wait([
      _refreshBalance(),
      _refreshSummary(),
      _refreshRecentExpenses(),
      _refreshRecurring(),
      _refreshBudgets(),
    ]);
    _expenseChangeCount++;
    notifyListeners();
  }

  Future<void> skipRecurring(String recurringId) async {
    await _recurringDao.skipRecurring(recurringId);
    await _refreshRecurring();
    notifyListeners();
  }

  Future<void> createRecurring({
    required String description,
    required double amount,
    String? storeId,
    String? tagId,
    String frequency = 'Monthly',
    DateTime? nextDueDate,
    String paymentMethod = 'Cash',
  }) async {
    await _recurringDao.createRecurringExpense(
      description: description,
      amount: amount,
      storeId: storeId,
      tagId: tagId,
      frequency: frequency,
      nextDueDate: nextDueDate,
      paymentMethod: paymentMethod,
    );
    await _refreshRecurring();
    notifyListeners();
  }

  Future<void> deleteRecurring(String id) async {
    await _recurringDao.deleteRecurringExpense(id);
    await _refreshRecurring();
    notifyListeners();
  }

  Future<void> saveBudget({
    required double amount,
    String? tagId,
    String period = 'monthly',
  }) async {
    await _budgetDao.setBudget(amount: amount, tagId: tagId, period: period);
    await _refreshBudgets();
    notifyListeners();
  }

  Future<void> deleteBudget(String id) async {
    await _budgetDao.deleteBudget(id);
    await _refreshBudgets();
    notifyListeners();
  }

  Future<Store> getOrCreateStore(String name) async {
    final s = await _storeDao.getOrCreateStore(name);
    await _refreshStoresAndTags();
    return s;
  }

  Future<Tag> getOrCreateTag(String name) async {
    final t = await _tagDao.getOrCreateTag(name);
    await _refreshStoresAndTags();
    return t;
  }

  Future<int> exportExpensesCsv() async {
    return await _csvExportService.exportExpenses();
  }

  Future<Map<String, dynamic>> createAndShareBackup() async {
    return await _backupRestoreService.createAndShareBackup();
  }

  Future<Map<String, int>> restoreBackup(Map<String, dynamic> parsedData) async {
    final result = await _backupRestoreService.restoreBackupData(parsedData);
    await loadAllData();
    _expenseChangeCount++;
    notifyListeners();
    return result;
  }

  Future<MonthlySpendingSummary> getMonthlySpendingSummary(DateTime month) async {
    return await _analyticsService.getMonthlySpendingSummary(month);
  }

  Future<List<Map<String, dynamic>>> getStoresWithExpenseCount() async {
    return await _storeDao.getAllStoresWithExpenseCount();
  }

  Future<void> renameStore(String storeId, String newName) async {
    await _storeDao.renameStore(storeId, newName);
    await _refreshStoresAndTags();
    await _refreshRecentExpenses();
    _expenseChangeCount++;
    notifyListeners();
  }

  Future<void> deleteStore(String storeId) async {
    await _storeDao.deleteStore(storeId);
    await _refreshStoresAndTags();
    await _refreshRecentExpenses();
    _expenseChangeCount++;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getTagsWithExpenseCount() async {
    return await _tagDao.getAllTagsWithExpenseCount();
  }

  Future<void> renameTag(String tagId, String newName) async {
    await _tagDao.renameTag(tagId, newName);
    await _refreshStoresAndTags();
    await _refreshRecentExpenses();
    _expenseChangeCount++;
    notifyListeners();
  }

  Future<Tag> addCategory(String name, {String? description}) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }
    final existing = _tags.any((t) => t.name.trim().toLowerCase() == clean.toLowerCase());
    if (existing) {
      throw ArgumentError('Category "$clean" already exists.');
    }
    final newTag = await _tagDao.createTag(clean, description: description);
    await _refreshStoresAndTags();
    notifyListeners();
    return newTag;
  }

  Future<void> deleteTag(String tagId) async {
    await _tagDao.deleteTag(tagId);
    await _refreshStoresAndTags();
    await _refreshRecentExpenses();
    await _refreshBudgets();
    _expenseChangeCount++;
    notifyListeners();
  }

  // --- SMS Tracking & Pending Transactions ---

  Future<bool> toggleSmsTracking(bool enable) async {
    if (enable) {
      final status = await _smsTrackingService.getPermissionStatus();
      _hasSmsPermission = status.hasSmsPermission;
      _hasNotificationPermission = status.hasNotificationPermission;

      if (!status.areAllGranted) {
        // Only request permissions if not already granted
        await _smsTrackingService.requestPermissions();
        final updated = await _smsTrackingService.getPermissionStatus();
        _hasSmsPermission = updated.hasSmsPermission;
        _hasNotificationPermission = updated.hasNotificationPermission;

        if (!updated.areAllGranted) {
          _isSmsTrackingEnabled = false;
          await _smsTrackingService.setTrackingEnabled(false);
          notifyListeners();
          return false;
        }
      }

      await _smsTrackingService.setTrackingEnabled(true);
      _isSmsTrackingEnabled = true;
      notifyListeners();
      return true;
    } else {
      await _smsTrackingService.setTrackingEnabled(false);
      _isSmsTrackingEnabled = false;
      notifyListeners();
      return true;
    }
  }

  Future<PendingTransaction?> getPendingTransactionById(String id) async {
    return await _pendingTransactionDao.getById(id);
  }

  Future<void> confirmPendingTransaction({
    required String pendingId,
    required double amount,
    required DateTime date,
    String? time,
    String? description,
    String? storeId,
    String? tagId,
    String paymentMethod = 'UPI',
    bool saveAsRegularPayee = false,
    String? payeeName,
    String? identifierType,
    String? identifier,
  }) async {
    // 1. Create the standard expense
    await _expenseDao.createExpense(
      amount: amount,
      date: date,
      time: time,
      description: description,
      storeId: storeId,
      tagId: tagId,
      paymentMethod: paymentMethod,
    );

    // 2. If user requested saving as regular payee, learn mapping
    if (saveAsRegularPayee &&
        payeeName != null &&
        payeeName.trim().isNotEmpty &&
        identifierType != null &&
        identifier != null) {
      await _payeeMappingDao.saveOrUpdate(
        identifierType: identifierType,
        identifier: identifier,
        payeeName: payeeName,
        defaultTagId: tagId,
      );
    }

    // 3. Mark pending transaction as confirmed in SQLite
    await _pendingTransactionDao.markConfirmed(pendingId);

    // 4. Refresh app state and notify listeners
    await Future.wait([
      _refreshBalance(),
      _refreshSummary(),
      _refreshRecentExpenses(),
      _refreshQuickAdd(),
      _refreshBudgets(),
      _refreshStoresAndTags(),
      _refreshPendingTransactions(),
    ]);

    _expenseChangeCount++;
    notifyListeners();
  }

  Future<void> ignorePendingTransaction(String pendingId) async {
    await _pendingTransactionDao.markIgnored(pendingId);
    await _refreshPendingTransactions();
    notifyListeners();
  }

  Future<String> simulateIncomingSms({
    required String sender,
    required String message,
  }) async {
    final result = await _smsTrackingService.simulateIncomingSms(
      sender: sender,
      message: message,
    );
    await _refreshPendingTransactions();
    notifyListeners();
    return result;
  }
}

