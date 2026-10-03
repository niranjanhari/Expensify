import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../state/app_state.dart';
import 'manage_categories_screen.dart';
import 'manage_merchants_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshSmsPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      context.read<AppState>().refreshSmsPermissions();
    }
  }

  void _showSetBalanceDialog(BuildContext context, AppState state) {
    final curBal = state.balance.isConfigured ? state.balance.currentBalance : 10000.0;
    final amtController = TextEditingController(text: curBal.toStringAsFixed(2));
    final noteController = TextEditingController(text: state.balance.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          title: Text(
            state.balance.isConfigured ? 'Update Baseline Balance' : 'Set Initial Balance',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amtController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Current Bank Balance (${state.currency})',
                  prefixText: '${state.currency} ',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Account Note (optional)',
                  hintText: 'e.g. Primary Checking Account',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amtController.text.trim());
                if (amt != null && amt >= 0) {
                  state.updateBalance(amt, notes: noteController.text.trim());
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Baseline', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  static String? _lastSimulatedMessage;
  static String? _lastSimulatedSender;

  String _generateTestSms(double amount, String payee, String bankAcct) {
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MMM-yy').format(now);
    final ref = '${(now.millisecondsSinceEpoch % 900000000000 + 100000000000)}';
    return 'Dear Customer, INR ${amount.toStringAsFixed(2)} debited from A/c $bankAcct on $dateStr by UPI to $payee. Ref $ref. Bal: INR ${(25000 - amount).toStringAsFixed(2)}';
  }

  Widget _buildPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.bg,
            border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.border,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.textPrimary : AppTheme.muted,
            ),
          ),
        ),
      ),
    );
  }

  void _showTestSmsDialog(BuildContext context, AppState state) {
    double selectedAmount = 500.0;
    String selectedPayee = 'Swiggy';
    final senderController = TextEditingController(text: 'HDFCBK');
    final messageController = TextEditingController(
      text: _generateTestSms(selectedAmount, selectedPayee, '**1234'),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              ),
              title: const Text(
                'Simulate Test Payment SMS',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Simulate receiving a bank debit SMS to test detection, notification, and confirmation:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Presets (Generates unique Ref ID):',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildPresetChip(
                          label: '₹500',
                          isSelected: selectedAmount == 500,
                          onTap: () {
                            setDialogState(() {
                              selectedAmount = 500;
                              selectedPayee = 'Swiggy';
                              messageController.text = _generateTestSms(500, 'Swiggy', '**1234');
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildPresetChip(
                          label: '₹750',
                          isSelected: selectedAmount == 750,
                          onTap: () {
                            setDialogState(() {
                              selectedAmount = 750;
                              selectedPayee = 'Uber';
                              messageController.text = _generateTestSms(750, 'Uber', '**1234');
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildPresetChip(
                          label: '₹1200',
                          isSelected: selectedAmount == 1200,
                          onTap: () {
                            setDialogState(() {
                              selectedAmount = 1200;
                              selectedPayee = 'Amazon India';
                              messageController.text = _generateTestSms(1200, 'Amazon India', '**1234');
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: senderController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Bank Sender',
                        hintText: 'e.g. HDFCBK, SBIN, ICICIB',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'SMS Content',
                      ),
                    ),
                    if (_lastSimulatedMessage != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Load Last SMS (Test Duplicate)', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD97706),
                          side: const BorderSide(color: Color(0xFFD97706)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            senderController.text = _lastSimulatedSender ?? 'HDFCBK';
                            messageController.text = _lastSimulatedMessage!;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final sender = senderController.text.trim();
                    final body = messageController.text.trim();
                    Navigator.pop(ctx);

                    _lastSimulatedSender = sender.isEmpty ? 'HDFCBK' : sender;
                    _lastSimulatedMessage = body;

                    final status = await state.simulateIncomingSms(
                      sender: _lastSimulatedSender!,
                      message: body,
                    );

                    if (context.mounted) {
                      String snackMsg;
                      Color snackColor = AppTheme.textPrimary;
                      if (status == 'SUCCESS') {
                        snackMsg = 'Payment SMS simulated! Check notification or pending transaction banner.';
                      } else if (status == 'DUPLICATE') {
                        snackMsg = 'Duplicate detected! Transaction was blocked by duplicate protection.';
                        snackColor = const Color(0xFFD97706);
                      } else {
                        snackMsg = 'SMS not recognized as debit ($status).';
                        snackColor = AppTheme.expenseRed;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(snackMsg),
                          backgroundColor: snackColor,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.textPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Simulate', style: TextStyle(fontWeight: FontWeight.w700)),
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
    final bal = state.balance;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Settings & Data', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.textPrimary)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          // 1. Bank Account Section
          const Text('BANK ACCOUNT BALANCE', style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.whiteCardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live Current Balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showSetBalanceDialog(context, state),
                      child: Text(bal.isConfigured ? 'Adjust Baseline' : 'Set Baseline', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  bal.isConfigured ? '$currency${NumberFormat('#,##0.00').format(bal.currentBalance)}' : 'Not Set',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5),
                ),
                if (bal.isConfigured) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppTheme.border),
                  const SizedBox(height: 12),
                  Text(
                    'Saved Baseline: $currency${NumberFormat('#,##0.00').format(bal.baselineAmount)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expenses Deducted: $currency${NumberFormat('#,##0.00').format(bal.expensesSinceBaseline)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  if (bal.setAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Baseline Date: ${DateFormat('d MMM yyyy, h:mm a').format(bal.setAt!.toLocal())}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Preferences
          const Text('PREFERENCES', style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.whiteCardDecoration,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Display Currency', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: currency,
                    dropdownColor: AppTheme.surface,
                    underline: const SizedBox(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    items: ['₹', '\$', '€', '£', '¥'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) state.setCurrency(val);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. SMS Tracking
          const Text('SMS TRACKING', style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.whiteCardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detect bank payments from SMS',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Expensify can detect eligible payment SMS messages and ask you to add them as expenses.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch.adaptive(
                      value: state.isSmsTrackingEnabled,
                      activeTrackColor: AppTheme.accent,
                      onChanged: (bool enable) async {
                        final success = await state.toggleSmsTracking(enable);
                        if (!success && enable && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('SMS and notification permissions are required to detect transactions.'),
                              backgroundColor: AppTheme.textPrimary,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),

                // Permissions status banner: only displayed when permissions are NOT all granted
                if (!state.areSmsPermissionsGranted) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.textPrimary),
                            SizedBox(width: 8),
                            Text(
                              'Permissions required',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Grant SMS & notification permissions to detect payment messages.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              state.hasSmsPermission ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 14,
                              color: state.hasSmsPermission ? AppTheme.positiveGreen : AppTheme.muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SMS: ${state.hasSmsPermission ? "Granted" : "Not granted"}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: state.hasSmsPermission ? AppTheme.positiveGreen : AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              state.hasNotificationPermission ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 14,
                              color: state.hasNotificationPermission ? AppTheme.positiveGreen : AppTheme.muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Notification: ${state.hasNotificationPermission ? "Granted" : "Not granted"}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: state.hasNotificationPermission ? AppTheme.positiveGreen : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                await state.smsTrackingService.requestPermissions();
                                await state.refreshSmsPermissions();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Grant Permissions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => state.smsTrackingService.openAppSettings(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Phone Settings', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                if (state.areSmsPermissionsGranted || state.isSmsTrackingEnabled) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppTheme.border),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '100% offline & private. SMS messages never leave your phone.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.science_outlined, size: 14, color: AppTheme.textPrimary),
                        label: const Text('Test SMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        onPressed: () => _showTestSmsDialog(context, state),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 3. Saved Data Management
          const Text('SAVED DATA MANAGEMENT', style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            decoration: AppTheme.whiteCardDecoration,
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageMerchantsScreen()));
                  },
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(Icons.storefront_outlined, color: AppTheme.textPrimary, size: 22),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Manage Merchants', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                              SizedBox(height: 2),
                              Text('View, search, rename, or delete saved stores and vendors', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: AppTheme.border),
                InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()));
                  },
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusCard)),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(Icons.label_outline_rounded, color: AppTheme.textPrimary, size: 22),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Manage Categories', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                              SizedBox(height: 2),
                              Text('View, search, rename, or delete expense tags and categories', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
                      ],
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

