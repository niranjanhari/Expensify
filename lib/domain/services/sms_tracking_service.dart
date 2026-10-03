import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/pending_transaction.dart';
import '../../data/daos/pending_transaction_dao.dart';
import '../../data/daos/payee_mapping_dao.dart';
import 'sms_transaction_detector.dart';
import 'sms_transaction_parser.dart';

class SmsPermissionStatus {
  final bool hasSmsPermission;
  final bool hasNotificationPermission;
  final bool isTrackingEnabled;

  bool get areAllGranted => hasSmsPermission && hasNotificationPermission;

  const SmsPermissionStatus({
    required this.hasSmsPermission,
    required this.hasNotificationPermission,
    required this.isTrackingEnabled,
  });

  factory SmsPermissionStatus.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const SmsPermissionStatus(
        hasSmsPermission: false,
        hasNotificationPermission: false,
        isTrackingEnabled: false,
      );
    }
    return SmsPermissionStatus(
      hasSmsPermission: (map['hasSmsPermission'] as bool?) ??
          (map['hasReceiveSmsPermission'] as bool?) ??
          (map['hasReceiveSms'] as bool?) ??
          false,
      hasNotificationPermission: (map['hasNotificationPermission'] as bool?) ?? false,
      isTrackingEnabled: (map['isTrackingEnabled'] as bool?) ??
          (map['enabled'] as bool?) ??
          false,
    );
  }
}

class SmsTrackingService {
  static const MethodChannel _channel = MethodChannel('com.expensify.mobile/sms');

  final PendingTransactionDao _pendingDao = PendingTransactionDao();
  final PayeeMappingDao _payeeDao = PayeeMappingDao();

  final StreamController<String> _pendingTappedController = StreamController<String>.broadcast();
  final StreamController<PendingTransaction> _newPendingController = StreamController<PendingTransaction>.broadcast();

  Stream<String> get onPendingTapped => _pendingTappedController.stream;
  Stream<PendingTransaction> get onNewPending => _newPendingController.stream;

  SmsTrackingService() {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPendingTransactionTapped':
      case 'onNotificationTapped':
        final pendingId = call.arguments as String?;
        if (pendingId != null && pendingId.isNotEmpty) {
          _pendingTappedController.add(pendingId);
        }
        break;
      case 'onPendingTransactionReceived':
      case 'onPendingTransactionDetected':
        final pendingId = call.arguments as String?;
        if (pendingId != null && pendingId.isNotEmpty) {
          final tx = await _pendingDao.getById(pendingId);
          if (tx != null) {
            _newPendingController.add(tx);
          }
        }
        break;
      default:
        break;
    }
  }

  /// Queries Android OS directly for live permissions and tracking status.
  Future<SmsPermissionStatus> getPermissionStatus() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkPermissions');
      if (res != null) {
        return SmsPermissionStatus.fromMap(res);
      }
    } catch (_) {
      try {
        final fallback = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSmsTrackingStatus');
        if (fallback != null) {
          return SmsPermissionStatus.fromMap(fallback);
        }
      } catch (_) {}
    }
    return const SmsPermissionStatus(
      hasSmsPermission: false,
      hasNotificationPermission: false,
      isTrackingEnabled: false,
    );
  }

  /// Checks if both SMS and notification permissions are currently granted in Android.
  Future<bool> checkPermissions() async {
    final status = await getPermissionStatus();
    return status.areAllGranted;
  }

  /// Prompts the Android runtime permission dialog for missing permissions.
  /// If permissions are already granted, immediately returns true.
  Future<bool> requestPermissions() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermissions');
      return granted ?? false;
    } catch (_) {
      try {
        final fallback = await _channel.invokeMethod<bool>('requestSmsPermissions');
        return fallback ?? false;
      } catch (_) {
        return false;
      }
    }
  }

  /// Opens the Android App Info Settings page for Expensify so the user can easily toggle permissions.
  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (e) {
      debugPrint('SmsTrackingService: openAppSettings error $e');
    }
  }

  /// Checks whether SMS tracking is enabled in SharedPreferences.
  Future<bool> isTrackingEnabled() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('isSmsTrackingEnabled');
      if (enabled != null) return enabled;
    } catch (_) {}

    final status = await getPermissionStatus();
    return status.isTrackingEnabled;
  }

  /// Enables or disables SMS tracking.
  Future<bool> setTrackingEnabled(bool enabled) async {
    try {
      final success = await _channel.invokeMethod<bool>(
        'setSmsTrackingEnabled',
        {'enabled': enabled},
      );
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if the app was launched by tapping a transaction notification.
  Future<String?> getInitialPendingId() async {
    try {
      final id = await _channel.invokeMethod<String>('getInitialPendingId');
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {}

    try {
      return await _channel.invokeMethod<String>('getInitialPendingTransactionId');
    } catch (_) {
      return null;
    }
  }

  /// Dismisses a notification with given ID.
  Future<void> dismissNotification(int id) async {
    try {
      await _channel.invokeMethod('dismissNotification', {'id': id});
    } catch (_) {}
  }

  /// Simulates an incoming SMS message. Useful for testing in debug mode or QA.
  /// Returns status: 'SUCCESS', 'DUPLICATE', 'IGNORED_NOT_DEBIT', etc.
  Future<String> simulateIncomingSms({
    required String sender,
    required String message,
  }) async {
    try {
      final res = await _channel.invokeMethod<dynamic>(
        'simulateIncomingSms',
        {'sender': sender, 'message': message, 'body': message},
      );
      if (res is String) return res;
      if (res == true) return 'SUCCESS';
      return 'FAILED';
    } catch (e) {
      // In non-Android or fallback, process directly in Dart
      final tx = await processIncomingSms(sender, message);
      if (tx != null) return 'SUCCESS';
      return 'FAILED';
    }
  }

  /// Core Dart-side processing for incoming SMS.
  /// Detects debit, parses fields, checks learned payee, checks duplicates, and inserts pending transaction.
  Future<PendingTransaction?> processIncomingSms(
    String sender,
    String body, {
    int? timestampMs,
  }) async {
    // 1. Detect if valid debit transaction
    final detection = SmsTransactionDetector.detect(body, sender: sender);
    if (!detection.isTransaction || !detection.isDebit) {
      return null;
    }

    // 2. Parse transaction details
    final parsed = SmsTransactionParser.parse(
      body,
      sender: sender,
      timestampMs: timestampMs,
    );
    if (parsed == null) {
      return null;
    }

    // 3. Check learned payee mappings
    String? payee = parsed.parsedPayee;
    final learned = await _payeeDao.findBestMatch(
      upiId: parsed.payeeIdentifier,
      accountIdentifier: parsed.accountIdentifier,
      merchantIdentifier: parsed.parsedPayee,
    );
    if (learned != null && learned.payeeName.isNotEmpty) {
      payee = learned.payeeName;
    }

    // 4. Create pending transaction model
    var pendingTx = parsed.toPendingTransaction(
      rawSender: sender,
      rawSms: body,
    );
    if (payee != null && payee != pendingTx.parsedPayee) {
      pendingTx = pendingTx.copyWith(parsedPayee: payee);
    }

    // 5. Duplicate check and SQLite insert
    final inserted = await _pendingDao.insertIfNotDuplicate(pendingTx);
    if (inserted != null) {
      _newPendingController.add(inserted);
    }
    return inserted;
  }

  void dispose() {
    _pendingTappedController.close();
    _newPendingController.close();
  }
}
