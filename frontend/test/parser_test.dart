import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/storage_service.dart';
import 'package:frontend/services/transaction_capture_service.dart';

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('fintrack_parser_test_');
    await StorageService().initialize(tempDir.path);
  });

  group('Transaction Parsing and Categorization Tests', () {
    test('Swiggy bank debit with trf to is categorized as Food & Dining and not P2P', () async {
      final text = "Rs.450.00 debited from A/c XX1234 on 10-07-26 trf to SWIGGY. Ref 1234567.";
      final tx = await TransactionCaptureService().processRawEvent(
        rawText: text,
        source: 'sms',
      );

      expect(tx, isNotNull);
      expect(tx!.amount, 450.00);
      expect(tx.merchant, "Swiggy");
      expect(tx.category, "Food & Dining");
      expect(tx.source, isNot("p2p"));
    });

    test('PhonePe payment to Zomato is recognized as Food & Dining and not P2P', () async {
      final text = "You paid Rs.250 to Zomato via PhonePe";
      final tx = await TransactionCaptureService().processRawEvent(
        rawText: text,
        source: 'notification',
      );

      expect(tx, isNotNull);
      expect(tx!.amount, 250.00);
      expect(tx.merchant, "Zomato");
      expect(tx.category, "Food & Dining");
      expect(tx.source, isNot("p2p"));
    });

    test('Subscription debit towards Netflix is categorized as Entertainment', () async {
      final text = "INR 999 debited towards Netflix. Avl Bal Rs 2000";
      final tx = await TransactionCaptureService().processRawEvent(
        rawText: text,
        source: 'sms',
      );

      expect(tx, isNotNull);
      expect(tx!.amount, 999.00);
      expect(tx.merchant, "Netflix");
      expect(tx.category, "Entertainment");
    });

    test('Debit with VPA credited to Rahul is parsed as P2P with merchant Rahul', () async {
      final text = "Rs 500 debited from a/c XX12 and credited to Rahul (VPA rahul@okaxis)";
      final tx = await TransactionCaptureService().processRawEvent(
        rawText: text,
        source: 'sms',
      );

      expect(tx, isNotNull);
      expect(tx!.amount, 500.00);
      expect(tx.merchant, "Rahul");
      expect(tx.source, "p2p");
    });

    test('DMART spend is title-cased to Dmart', () async {
      final text = "Rs 120 spent at DMART on 12-09";
      final tx = await TransactionCaptureService().processRawEvent(
        rawText: text,
        source: 'sms',
      );

      expect(tx, isNotNull);
      expect(tx!.amount, 120.00);
      expect(tx.merchant, "Dmart");
    });

    test('OTP message is skipped', () async {
      final text = "Your OTP is 123456 for Rs 500";
      final tx = await TransactionCaptureService().processRawEvent(
        rawText: text,
        source: 'sms',
      );

      expect(tx, isNull);
    });
  });
}
