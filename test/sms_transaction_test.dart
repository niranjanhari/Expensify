import 'package:flutter_test/flutter_test.dart';
import 'package:expensify_mobile/domain/models/pending_transaction.dart';
import 'package:expensify_mobile/domain/services/sms_transaction_detector.dart';
import 'package:expensify_mobile/domain/services/sms_transaction_parser.dart';

void main() {
  group('SmsTransactionDetector & SmsTransactionParser Tests', () {
    test('1. Valid debit: ₹500 debited from A/c XX1234', () {
      const sms = '₹500 debited from A/c XX1234 on 01-Oct-26. Avl Bal: INR 12,400.00';
      final detection = SmsTransactionDetector.detect(sms, sender: 'HDFCBK');

      expect(detection.isTransaction, isTrue);
      expect(detection.isDebit, isTrue);
      expect(detection.confidence, greaterThanOrEqualTo(0.8));

      final parsed = SmsTransactionParser.parse(sms, sender: 'HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 500.0);
      expect(parsed.accountIdentifier, contains('1234'));
      expect(parsed.bankName, 'HDFC Bank');
    });

    test('2. UPI debit: Representative UPI payment SMS', () {
      const sms = 'Dear UPI User, INR 1,250.50 debited from your A/c **4321 on 02-Oct-26 transfer to swiggy@okaxis. Ref 429104859123.';
      final detection = SmsTransactionDetector.detect(sms, sender: 'AXISBK');

      expect(detection.isTransaction, isTrue);
      expect(detection.isDebit, isTrue);

      final parsed = SmsTransactionParser.parse(sms, sender: 'AXISBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 1250.50);
      expect(parsed.suggestedPaymentMethod, 'UPI');
      expect(parsed.payeeIdentifier, 'swiggy@okaxis');
      expect(parsed.parsedPayee?.toLowerCase(), contains('swiggy'));
      expect(parsed.referenceId, '429104859123');
      expect(parsed.bankName, 'Axis Bank');
    });

    test('3. OTP: Ignore one time passwords and verification codes', () {
      const sms1 = 'Your OTP for transaction of INR 500.00 at Amazon is 482910. Do not share this code with anyone.';
      final detection1 = SmsTransactionDetector.detect(sms1, sender: 'SBIINB');
      expect(detection1.isTransaction, isFalse);
      expect(detection1.reason, contains('OTP'));

      const sms2 = '654321 is your secret code to log into netbanking. Code is valid for 5 mins.';
      final detection2 = SmsTransactionDetector.detect(sms2);
      expect(detection2.isTransaction, isFalse);
    });

    test('4. Promotional SMS: Ignore pre-approved loans and marketing', () {
      const sms1 = 'Congratulations! You are pre-approved for an instant personal loan of Rs 5,00,000 at zero interest. Apply now!';
      final detection1 = SmsTransactionDetector.detect(sms1, sender: 'KOTAKB');
      expect(detection1.isTransaction, isFalse);
      expect(detection1.reason, contains('Promotional'));

      const sms2 = 'Get flat 20% discount up to Rs 150 on your next grocery order with code SAVE20. Offer valid till Sunday!';
      final detection2 = SmsTransactionDetector.detect(sms2);
      expect(detection2.isTransaction, isFalse);
    });

    test('5. Credit: Representative money-received SMS', () {
      const sms = 'Dear Customer, your A/c XX9876 has been credited by INR 25,000.00 on 01-Oct-26 by salary transfer. Clear Bal: INR 35,000.00';
      final detection = SmsTransactionDetector.detect(sms, sender: 'ICICIB');

      expect(detection.isTransaction, isTrue);
      expect(detection.isDebit, isFalse);
      expect(detection.reason, contains('Credit'));
    });

    test('6. Duplicate detection: Fingerprint computation for identical transactions', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      final fp1 = PendingTransaction.computeFingerprint(
        referenceId: 'REF12345678',
        accountIdentifier: 'XX1234',
        payeeIdentifier: 'rahul@upi',
        amount: 800.0,
        smsTimestamp: now,
      );

      final fp2 = PendingTransaction.computeFingerprint(
        referenceId: 'REF12345678',
        accountIdentifier: 'XX1234',
        payeeIdentifier: 'rahul@upi',
        amount: 800.0,
        smsTimestamp: now + 5000, // even with slightly different arrival time, refId dominates
      );

      expect(fp1, equals(fp2));
    });

    test('7. Missing fields: Valid debit SMS with no identifiable payee does not crash', () {
      const sms = 'Rs. 250.00 debited from your card ending 5678 on 02-Oct-2026. Avl limit: Rs 45,000.';
      final detection = SmsTransactionDetector.detect(sms, sender: 'SBIN');

      expect(detection.isTransaction, isTrue);
      expect(detection.isDebit, isTrue);

      final parsed = SmsTransactionParser.parse(sms, sender: 'SBIN');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 250.0);
      expect(parsed.accountIdentifier, contains('5678'));
      expect(parsed.parsedPayee, isNull);
      expect(parsed.payeeIdentifier, isNull);

      final pendingTx = parsed.toPendingTransaction(rawSender: 'SBIN', rawSms: sms);
      expect(pendingTx.amount, 250.0);
      expect(pendingTx.parsedPayee, isNull);
      expect(pendingTx.fingerprint.isNotEmpty, isTrue);
      expect(pendingTx.status, PendingTransactionStatus.pending);
    });

    test('8. Edge case: Balance-only SMS without transaction keywords is ignored', () {
      const sms = 'Your available balance in A/c XX1234 is INR 8,450.00 as of 02-Oct-26.';
      final detection = SmsTransactionDetector.detect(sms);
      expect(detection.isTransaction, isFalse);
    });

    test('9. Repeatable simulation test cases: ₹500, ₹750, ₹1200 produce distinct pending transactions', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final sms1 = 'Dear Customer, INR 500.00 debited from A/c **1234 on 02-Oct-26 by UPI to Swiggy. Ref REF${now}1. Bal: INR 24,500.00';
      final sms2 = 'Dear Customer, INR 750.00 debited from A/c **1234 on 02-Oct-26 by UPI to Uber. Ref REF${now}2. Bal: INR 23,750.00';
      final sms3 = 'Dear Customer, INR 1200.00 debited from A/c **1234 on 02-Oct-26 by UPI to Amazon India. Ref REF${now}3. Bal: INR 22,550.00';

      final p1 = SmsTransactionParser.parse(sms1, sender: 'HDFCBK')!;
      final p2 = SmsTransactionParser.parse(sms2, sender: 'HDFCBK')!;
      final p3 = SmsTransactionParser.parse(sms3, sender: 'HDFCBK')!;

      expect(p1.amount, 500.0);
      expect(p2.amount, 750.0);
      expect(p3.amount, 1200.0);

      final tx1 = p1.toPendingTransaction(rawSender: 'HDFCBK', rawSms: sms1);
      final tx2 = p2.toPendingTransaction(rawSender: 'HDFCBK', rawSms: sms2);
      final tx3 = p3.toPendingTransaction(rawSender: 'HDFCBK', rawSms: sms3);

      expect(tx1.referenceId, isNot(equals(tx2.referenceId)));
      expect(tx2.referenceId, isNot(equals(tx3.referenceId)));
      expect(tx1.fingerprint, isNot(equals(tx2.fingerprint)));
      expect(tx2.fingerprint, isNot(equals(tx3.fingerprint)));
    });

    test('10. Reference ID is kept in reference_id and NOT copied to normal user description', () {
      const sms = 'Dear UPI User, INR 500.00 debited from A/c **1234 to Swiggy. Ref 987654321012.';
      final parsed = SmsTransactionParser.parse(sms, sender: 'HDFCBK')!;
      final pending = parsed.toPendingTransaction(rawSender: 'HDFCBK', rawSms: sms);

      expect(pending.referenceId, '987654321012');
      // The pending transaction does not have description field - user enters description manually
      // Verify parsedPayee contains merchant, not reference number
      expect(pending.parsedPayee, contains('Swiggy'));
      expect(pending.parsedPayee, isNot(contains('987654321012')));
    });
  });
}
