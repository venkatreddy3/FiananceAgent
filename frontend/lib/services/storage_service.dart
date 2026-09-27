import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String boxSettings = 'fintrack_settings';
  static const String boxTransactions = 'fintrack_transactions';
  static const String boxBudgets = 'fintrack_budgets';
  static const String boxGoals = 'fintrack_goals';
  static const String boxLearnedMerchants = 'fintrack_learned_merchants';

  late Box _settingsBox;
  late Box _txBox;
  late Box _budgetsBox;
  late Box _goalsBox;
  late Box _merchantsBox;

  Future<void> initialize([String? path]) async {
    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter();
    }
    _settingsBox = await Hive.openBox(boxSettings);
    _txBox = await Hive.openBox(boxTransactions);
    _budgetsBox = await Hive.openBox(boxBudgets);
    _goalsBox = await Hive.openBox(boxGoals);
    _merchantsBox = await Hive.openBox(boxLearnedMerchants);

    _seedInitialBudgetsIfEmpty();
  }

  void _seedInitialBudgetsIfEmpty() {
    if (_budgetsBox.isEmpty) {
      final defaultBudgets = [
        BudgetModel(category: "Food & Dining", allocatedAmount: 12000.0, spentAmount: 0.0),
        BudgetModel(category: "Housing", allocatedAmount: 18000.0, spentAmount: 0.0),
        BudgetModel(category: "Transportation", allocatedAmount: 4500.0, spentAmount: 0.0),
        BudgetModel(category: "Shopping", allocatedAmount: 5000.0, spentAmount: 0.0),
        BudgetModel(category: "Bills & Utilities", allocatedAmount: 3500.0, spentAmount: 0.0),
        BudgetModel(category: "Entertainment", allocatedAmount: 2000.0, spentAmount: 0.0),
        BudgetModel(category: "Healthcare", allocatedAmount: 2000.0, spentAmount: 0.0),
        BudgetModel(category: "Personal", allocatedAmount: 2000.0, spentAmount: 0.0),
      ];
      for (var b in defaultBudgets) {
        _budgetsBox.put(b.category, json.encode(b.toJson()));
      }
    }
  }

  // --- Settings & Flags ---
  bool get isOnboarded => _settingsBox.get('is_onboarded', defaultValue: false);
  set isOnboarded(bool value) => _settingsBox.put('is_onboarded', value);

  bool get isPermissionsGranted => _settingsBox.get('is_permissions_granted', defaultValue: false);
  set isPermissionsGranted(bool value) => _settingsBox.put('is_permissions_granted', value);

  String get baseUrl {
    final defaultUrl = (defaultTargetPlatform == TargetPlatform.android && !kIsWeb)
        ? 'http://10.0.2.2:8000'
        : 'http://localhost:8000';
    return _settingsBox.get('base_url', defaultValue: defaultUrl);
  }
  set baseUrl(String value) => _settingsBox.put('base_url', value);

  String get apiKey => _settingsBox.get('api_key', defaultValue: 'fintrack_secret_key');
  set apiKey(String value) => _settingsBox.put('api_key', value);

  // --- Transactions ---
  List<TransactionModel> getTransactions() {
    final list = <TransactionModel>[];
    for (var key in _txBox.keys) {
      final jsonStr = _txBox.get(key);
      if (jsonStr != null) {
        try {
          final data = json.decode(jsonStr);
          list.add(TransactionModel.fromJson(data));
        } catch (_) {}
      }
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<TransactionModel> saveTransaction(TransactionModel tx) async {
    final int id = tx.id ?? (DateTime.now().millisecondsSinceEpoch % 1000000000);
    final txWithId = TransactionModel(
      id: id,
      title: tx.title,
      amount: tx.amount,
      merchant: tx.merchant,
      rawText: tx.rawText,
      category: tx.category,
      source: tx.source,
      type: tx.type,
      date: tx.date,
      confidence: tx.confidence,
      status: tx.status,
      notes: tx.notes,
      isRecurring: tx.isRecurring,
      aiFlagged: tx.aiFlagged,
      aiFlagReason: tx.aiFlagReason,
    );
    await _txBox.put(id.toString(), json.encode(txWithId.toJson()));
    return txWithId;
  }

  Future<void> deleteTransaction(int id) async {
    await _txBox.delete(id.toString());
  }

  Future<void> clearTransactions() async {
    await _txBox.clear();
  }

  // --- Budgets ---
  List<BudgetModel> getBudgets() {
    final list = <BudgetModel>[];
    for (var key in _budgetsBox.keys) {
      final jsonStr = _budgetsBox.get(key);
      if (jsonStr != null) {
        try {
          final data = json.decode(jsonStr);
          list.add(BudgetModel.fromJson(data));
        } catch (_) {}
      }
    }
    return list;
  }

  Future<void> saveBudget(BudgetModel b) async {
    await _budgetsBox.put(b.category, json.encode(b.toJson()));
  }

  // --- Goals ---
  List<SavingsGoalModel> getGoals() {
    final list = <SavingsGoalModel>[];
    for (var key in _goalsBox.keys) {
      final jsonStr = _goalsBox.get(key);
      if (jsonStr != null) {
        try {
          final data = json.decode(jsonStr);
          list.add(SavingsGoalModel.fromJson(data));
        } catch (_) {}
      }
    }
    return list;
  }

  Future<void> saveGoal(SavingsGoalModel goal) async {
    final key = goal.id?.toString() ?? goal.title;
    await _goalsBox.put(key, json.encode(goal.toJson()));
  }

  // --- Learned Merchant Rules ---
  Map<String, String> getLearnedMerchants() {
    final map = <String, String>{};
    for (var key in _merchantsBox.keys) {
      final val = _merchantsBox.get(key);
      if (val is String) {
        map[key.toString()] = val;
      }
    }
    return map;
  }

  Future<void> saveLearnedMerchant(String merchantKey, String category) async {
    await _merchantsBox.put(merchantKey.trim().toLowerCase(), category);
  }
}
