import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../domain/models/payee_mapping.dart';
import '../../domain/models/pending_transaction.dart';
import '../state/app_state.dart';

class PendingTransactionScreen extends StatefulWidget {
  final PendingTransaction transaction;
  final VoidCallback? onConfirmed;

  const PendingTransactionScreen({
    super.key,
    required this.transaction,
    this.onConfirmed,
  });

  @override
  State<PendingTransactionScreen> createState() => _PendingTransactionScreenState();
}

class _PendingTransactionScreenState extends State<PendingTransactionScreen> {
  late TextEditingController _payeeController;
  late TextEditingController _descriptionController;
  String? _selectedTagId;
  String _selectedPaymentMethod = 'UPI';
  bool _rememberPayee = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _payeeController = TextEditingController(text: widget.transaction.parsedPayee ?? '');
    // Purchase description starts completely blank - do NOT place reference or UTR numbers here
    _descriptionController = TextEditingController(text: '');

    // Default payment method
    final method = widget.transaction.suggestedPaymentMethod ?? 'UPI';
    if (paymentMethods.contains(method)) {
      _selectedPaymentMethod = method;
    } else {
      _selectedPaymentMethod = 'UPI';
    }

    // Default remember payee to true if payee exists and we have an identifier to bind to
    if ((widget.transaction.parsedPayee?.isNotEmpty == true) &&
        (widget.transaction.payeeIdentifier != null || widget.transaction.accountIdentifier != null)) {
      _rememberPayee = true;
    }
  }

  @override
  void dispose() {
    _payeeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _confirmExpense(AppState state) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final payeeText = _payeeController.text.trim();
      final descriptionText = _descriptionController.text.trim();

      // Resolve store/payee if specified
      String? storeId;
      if (payeeText.isNotEmpty) {
        final store = await state.getOrCreateStore(payeeText);
        storeId = store.id;
      }

      // Date & time from SMS timestamp
      final smsDate = DateTime.fromMillisecondsSinceEpoch(widget.transaction.smsTimestamp);
      final timeStr = DateFormat('HH:mm').format(smsDate);

      // Determine identifier type for learning
      String? identifierType;
      String? identifier;
      if (widget.transaction.payeeIdentifier != null && widget.transaction.payeeIdentifier!.isNotEmpty) {
        identifierType = PayeeIdentifierType.upiId;
        identifier = widget.transaction.payeeIdentifier;
      } else if (widget.transaction.accountIdentifier != null && widget.transaction.accountIdentifier!.isNotEmpty) {
        identifierType = PayeeIdentifierType.bankAccount;
        identifier = widget.transaction.accountIdentifier;
      }

      await state.confirmPendingTransaction(
        pendingId: widget.transaction.id,
        amount: widget.transaction.amount,
        date: smsDate,
        time: timeStr,
        description: descriptionText.isEmpty ? null : descriptionText,
        storeId: storeId,
        tagId: _selectedTagId,
        paymentMethod: _selectedPaymentMethod,
        saveAsRegularPayee: _rememberPayee && payeeText.isNotEmpty && identifier != null,
        payeeName: payeeText,
        identifierType: identifierType,
        identifier: identifier,
      );

      // Dismiss notification from Android system bar
      await state.smsTrackingService.dismissNotification(widget.transaction.id.hashCode);

      if (mounted) {
        widget.onConfirmed?.call();
        // Immediately close the pending transaction UI and navigate back to Home/Dashboard
        Navigator.of(context).popUntil((route) => route.isFirst);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense of ${state.currency}${widget.transaction.amount.toStringAsFixed(0)} confirmed!'),
            backgroundColor: AppTheme.textPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding expense: $e'),
            backgroundColor: AppTheme.expenseRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _ignoreTransaction(AppState state) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await state.ignorePendingTransaction(widget.transaction.id);
      await state.smsTrackingService.dismissNotification(widget.transaction.id.hashCode);

      if (mounted) {
        widget.onConfirmed?.call();
        // Immediately close the pending transaction UI and navigate back to Home/Dashboard
        Navigator.of(context).popUntil((route) => route.isFirst);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction ignored.'),
            backgroundColor: AppTheme.textPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ignoring transaction: $e'),
            backgroundColor: AppTheme.expenseRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final txDate = DateTime.fromMillisecondsSinceEpoch(widget.transaction.smsTimestamp);
    final dateStr = DateFormat('MMM d, y • h:mm a').format(txDate);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Payment Detected', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: false,
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Prominent Amount Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.expenseRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_upward_rounded, size: 14, color: AppTheme.expenseRed),
                            SizedBox(width: 4),
                            Text(
                              'DEBIT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.expenseRed,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.transaction.bankName != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.transaction.bankName!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${state.currency}${widget.transaction.amount.toStringAsFixed(widget.transaction.amount.truncateToDouble() == widget.transaction.amount ? 0 : 2)}',
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.muted,
                    ),
                  ),
                  if (widget.transaction.accountIdentifier != null || widget.transaction.payeeIdentifier != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        if (widget.transaction.accountIdentifier != null)
                          Chip(
                            avatar: const Icon(Icons.credit_card_rounded, size: 14, color: AppTheme.muted),
                            label: Text(
                              'A/c: ${widget.transaction.accountIdentifier}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                            ),
                            backgroundColor: AppTheme.bg,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        if (widget.transaction.payeeIdentifier != null)
                          Chip(
                            avatar: const Icon(Icons.alternate_email_rounded, size: 14, color: AppTheme.muted),
                            label: Text(
                              widget.transaction.payeeIdentifier!,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                            ),
                            backgroundColor: AppTheme.bg,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Form Section
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Payee / Merchant
                  const Text(
                    'Who was this paid to?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _payeeController.text),
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return state.stores.map((s) => s.name);
                      }
                      return state.stores
                          .where((s) => s.name.toLowerCase().contains(textEditingValue.text.toLowerCase()))
                          .map((s) => s.name);
                    },
                    onSelected: (String selection) {
                      _payeeController.text = selection;
                      setState(() {});
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      controller.addListener(() {
                        _payeeController.text = controller.text;
                      });
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'e.g. Swiggy, Rahul, Metro Cash & Carry (Optional)',
                          prefixIcon: const Icon(Icons.storefront_rounded, size: 20, color: AppTheme.muted),
                          filled: true,
                          fillColor: AppTheme.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // 2. Category
                  const Text(
                    'What was this for?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTagId,
                    decoration: InputDecoration(
                      hintText: 'Select category',
                      prefixIcon: const Icon(Icons.label_outline_rounded, size: 20, color: AppTheme.muted),
                      filled: true,
                      fillColor: AppTheme.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Uncategorized', style: TextStyle(color: AppTheme.muted)),
                      ),
                      ...state.tags.map(
                        (tag) => DropdownMenuItem<String>(
                          value: tag.id,
                          child: Text(tag.name),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedTagId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 18),

                  // 3. Payment Method
                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPaymentMethod,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppTheme.muted),
                      filled: true,
                      fillColor: AppTheme.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: paymentMethods.map((pm) {
                      return DropdownMenuItem<String>(
                        value: pm,
                        child: Text(pm),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPaymentMethod = val);
                    },
                  ),
                  const SizedBox(height: 18),

                  // 4. User purchase description: "What did you buy?"
                  const Text(
                    'What did you buy? (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Lunch, Groceries, College supplies',
                      prefixIcon: const Icon(Icons.shopping_bag_outlined, size: 20, color: AppTheme.muted),
                      filled: true,
                      fillColor: AppTheme.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Save as regular payee checkbox
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: CheckboxListTile(
                      value: _rememberPayee,
                      onChanged: (val) => setState(() => _rememberPayee = val ?? false),
                      title: const Text(
                        'Remember this payee for future payments',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                      subtitle: Text(
                        widget.transaction.payeeIdentifier != null
                            ? 'Autofill for ${widget.transaction.payeeIdentifier}'
                            : (widget.transaction.accountIdentifier != null
                                ? 'Autofill for A/c ${widget.transaction.accountIdentifier}'
                                : 'Save as regular recipient'),
                        style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                      activeColor: AppTheme.accent,
                      checkColor: AppTheme.textPrimary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Raw SMS & Technical details expander (Separate from user description)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text(
                  'View original SMS & technical reference',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.muted),
                ),
                leading: const Icon(Icons.sms_outlined, size: 16, color: AppTheme.muted),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sender: ${widget.transaction.sender ?? 'Bank'}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.muted),
                        ),
                        if (widget.transaction.referenceId != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Reference ID: ${widget.transaction.referenceId}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          widget.transaction.rawSms,
                          style: const TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons: Add Expense & Ignore
            ElevatedButton(
              onPressed: _isSubmitting ? null : () => _confirmExpense(state),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Add Expense',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(height: 10),

            OutlinedButton(
              onPressed: _isSubmitting ? null : () => _ignoreTransaction(state),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.muted,
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Ignore',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

