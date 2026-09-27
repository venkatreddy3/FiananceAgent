import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/models.dart';
import 'categorization_service.dart';
import 'api_service.dart';

class TransactionCaptureService {
  static final TransactionCaptureService _instance = TransactionCaptureService._internal();
  factory TransactionCaptureService() => _instance;
  TransactionCaptureService._internal();

  static const EventChannel _eventChannel = EventChannel('com.fintrack/capture_events');
  static const MethodChannel _methodChannel = MethodChannel('com.fintrack/capture_bridge');

  StreamSubscription? _subscription;
  final List<Map<String, dynamic>> _recentEventsForDeduplication = [];
  final StreamController<TransactionModel> _capturedStreamController = StreamController.broadcast();

  Stream<TransactionModel> get onTransactionCaptured => _capturedStreamController.stream;

  void initialize() {
    _subscribeToNativeEvents();
    drainPendingEventsOnLaunch();
  }

  void _subscribeToNativeEvents() {
    _subscription?.cancel();
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is String) {
          try {
            final data = json.decode(event);
            processRawEvent(
              rawText: data['rawText'] ?? '',
              source: data['source'] ?? 'Notification',
              timestamp: (data['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
            );
          } catch (_) {}
        }
      },
      onError: (err) {
        // Native channel error / simulator mode
      },
    );
  }

  Future<void> drainPendingEventsOnLaunch() async {
    try {
      final List? pending = await _methodChannel.invokeMethod('getPendingEvents');
      if (pending != null && pending.isNotEmpty) {
        for (var item in pending) {
          if (item is String) {
            try {
              final data = json.decode(item);
              processRawEvent(
                rawText: data['rawText'] ?? '',
                source: data['source'] ?? 'Notification',
                timestamp: (data['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
              );
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<TransactionModel?> processRawEvent({
    required String rawText,
    required String source,
    int? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now().millisecondsSinceEpoch;

    // 1. Skip non-financial, OTPs, or failed transactions
    if (_shouldSkipEvent(rawText)) {
      return null;
    }

    // 2. Extract Amount & Merchant via Regex
    final parsed = _extractAmountAndMerchant(rawText);
    if (parsed == null || parsed['amount'] <= 0) {
      return null;
    }

    final double amount = parsed['amount'];
    final String merchant = parsed['merchant'];
    final bool isP2P = parsed['isP2P'];

    // 3. Deduplication by (amount + merchant + source-agnostic 3-min window)
    if (_isDuplicate(amount, merchant, now)) {
      return null;
    }
    _recentEventsForDeduplication.add({
      'amount': amount,
      'merchant': merchant.toLowerCase().trim(),
      'time': now,
    });
    _cleanOldDeduplicationBuffer(now);

    // 4. Categorize using 4-Method Cascade
    final catResult = await CategorizationService().categorize(
      merchantName: merchant,
      amount: amount,
      rawText: rawText,
      isP2P: isP2P,
    );

    final String category = catResult['category'];
    final double confidence = catResult['confidence'];
    final bool isUncategorized = category == "Uncategorized" || confidence < 0.85;

    // Use original event capture timestamp for date
    final dateStr = DateTime.fromMillisecondsSinceEpoch(now).toIso8601String().substring(0, 10);

    final tx = TransactionModel(
      title: merchant,
      amount: amount,
      merchant: merchant,
      rawText: rawText,
      category: category,
      source: isP2P ? "p2p" : source.toLowerCase(),
      type: "expense",
      date: dateStr,
      confidence: confidence,
      status: isUncategorized ? "skipped" : "auto",
      notes: isP2P ? "P2P Payment" : null,
    );

    // Save locally in Hive & sync
    await ApiService().addTransaction(tx);
    _capturedStreamController.add(tx);

    return tx;
  }

  bool _shouldSkipEvent(String text) {
    final lower = text.toLowerCase();
    
    // OTPs & Verification
    if (lower.contains("otp") || lower.contains("verification code") || lower.contains("one time password") || lower.contains("is your code")) {
      return true;
    }
    
    // Failed or declined transactions
    if (lower.contains("failed") || lower.contains("declined") || lower.contains("unsuccessful") || lower.contains("cancelled") || lower.contains("reversed")) {
      return true;
    }

    // Fix: Do NOT skip if message contains "debited". Only treat as income if it has credit verb AND no debit verb.
    final hasDebit = lower.contains("debited") || lower.contains("paid") || lower.contains("spent") || lower.contains("sent") || lower.contains("txn of");
    final hasCredit = lower.contains("credited") || lower.contains("received rs") || lower.contains("refund of");

    if (hasCredit && !hasDebit) {
      return true;
    }

    return false;
  }

  Map<String, dynamic>? _extractAmountAndMerchant(String text) {
    // Amount Regex: matches ₹450, Rs. 1,200.50, INR 350, Rs 500
    final amtRegex = RegExp(r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
    final amtMatch = amtRegex.firstMatch(text);
    if (amtMatch == null) return null;

    final amountStr = amtMatch.group(1)?.replaceAll(',', '') ?? '0';
    final amount = double.tryParse(amountStr) ?? 0.0;
    if (amount <= 0) return null;

    bool isP2P = false;
    String merchant = "Unknown Merchant";

    final p2pRegex = RegExp(r"""(?:paid to|sent to|transfer to|trf to|credited to|to)\s+([A-Za-z0-9\s@\._\-]+?)(?:\s+(?:on|ref|upi|using|from|via|\.)|$)""", caseSensitive: false);
    final merchantRegex = RegExp(r"""(?:at|spent on|towards|info\s*:\s*)\s+([A-Za-z0-9\s&\.\'\-]+?)(?:\s+(?:on|ref|avl|bal|using|from|via|\.)|$)""", caseSensitive: false);
    final vpaRegex = RegExp(r"""([a-zA-Z0-9\.\-_]+@(okaxis|okhdfcbank|okicici|oksbi|paytm|ybl|axl|ibl|upi))""", caseSensitive: false);
    final phoneRegex = RegExp(r"""\b(?:[6-9]\d{9})\b""");

    final mMatch = merchantRegex.firstMatch(text);
    final pMatch = p2pRegex.firstMatch(text);
    final vMatch = vpaRegex.firstMatch(text);
    final phMatch = phoneRegex.firstMatch(text);

    if (mMatch != null) {
      merchant = mMatch.group(1)!.trim();
    } else if (pMatch != null) {
      merchant = pMatch.group(1)!.trim();
      isP2P = true;
    } else if (vMatch != null) {
      merchant = vMatch.group(1)!.trim();
      isP2P = true;
    } else if (phMatch != null) {
      merchant = "Contact (${phMatch.group(0)})";
      isP2P = true;
    }

    return {
      "amount": amount,
      "merchant": merchant,
      "isP2P": isP2P,
    };
  }

  bool _isDuplicate(double amount, String merchant, int timestamp) {
    const int threeMinutesMs = 3 * 60 * 1000;
    final cleanMerchant = merchant.toLowerCase().trim();
    for (var event in _recentEventsForDeduplication) {
      final isSameAmount = event['amount'] == amount;
      final isSameMerchant = event['merchant'] == cleanMerchant;
      final isWithinWindow = (timestamp - (event['time'] as int)).abs() <= threeMinutesMs;
      if (isSameAmount && isSameMerchant && isWithinWindow) {
        return true;
      }
    }
    return false;
  }

  void _cleanOldDeduplicationBuffer(int now) {
    const int fiveMinutesMs = 5 * 60 * 1000;
    _recentEventsForDeduplication.removeWhere((e) => (now - (e['time'] as int)) > fiveMinutesMs);
  }

  void dispose() {
    _subscription?.cancel();
    _capturedStreamController.close();
  }
}
