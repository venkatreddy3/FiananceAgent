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
    final currentPeriod = DateTime.now().toIso8601String().substring(0, 7);
    if (_budgetsBox.isEmpty) {
      final defaultBudgets = [
        BudgetModel(category: "Food & Dining", allocatedAmount: 12000.0, period: currentPeriod),
        BudgetModel(category: "Housing", allocatedAmount: 18000.0, period: currentPeriod),
        BudgetModel(category: "Transportation", allocatedAmount: 4500.0, period: currentPeriod),
        BudgetModel(category: "Shopping", allocatedAmount: 5000.0, period: currentPeriod),
        BudgetModel(category: "Bills & Utilities", allocatedAmount: 3500.0, period: currentPeriod),
        BudgetModel(category: "Entertainment", allocatedAmount: 2000.0, period: currentPeriod),
        BudgetModel(category: "Healthcare", allocatedAmount: 2000.0, period: currentPeriod),
        BudgetModel(category: "Personal", allocatedAmount: 2000.0, period: currentPeriod),
      ];
      for (var b in defaultBudgets) {
        _budgetsBox.put("${b.category}|$currentPeriod", json.encode(b.toJson()));
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
        : 'http://127.0.0.1:8000';
    return _settingsBox.get('base_url', defaultValue: defaultUrl);
  }
  set baseUrl(String value) => _settingsBox.put('base_url', value);

  // Security: No hardcoded default API key
  String get apiKey => _settingsBox.get('api_key', defaultValue: '');
  set apiKey(String value) => _settingsBox.put('api_key', value);

  // --- Transactions (Keyed by UUID) ---
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
    await _txBox.put(tx.uuid, json.encode(tx.toJson()));
    return tx;
  }

  Future<void> deleteTransaction(String uuid) async {
    await _txBox.delete(uuid);
  }

  Future<void> deleteTransactionById(int id) async {
    for (var key in _txBox.keys) {
      final jsonStr = _txBox.get(key);
      if (jsonStr != null) {
        try {
          final data = json.decode(jsonStr);
          if (data['id'] == id) {
            await _txBox.delete(key);
            return;
          }
        } catch (_) {}
      }
    }
  }

  Future<void> clearTransactions() async {
    await _txBox.clear();
  }

  // --- Budgets (Keyed by category|YYYY-MM, spent computed dynamically) ---
  List<BudgetModel> getBudgets([String? period]) {
    final currentPeriod = period ?? DateTime.now().toIso8601String().substring(0, 7);
    final allTxs = getTransactions().where((t) => t.type == 'expense' && t.date.startsWith(currentPeriod)).toList();

    final list = <BudgetModel>[];
    for (var key in _budgetsBox.keys) {
      final strKey = key.toString();
      if (strKey.endsWith("|$currentPeriod")) {
        final jsonStr = _budgetsBox.get(key);
        if (jsonStr != null) {
          try {
            final data = json.decode(jsonStr);
            final b = BudgetModel.fromJson(data);
            // Dynamically compute spent amount
            b.spentAmount = allTxs.where((t) => t.category == b.category).fold(0.0, (s, t) => s + t.amount);
            list.add(b);
          } catch (_) {}
        }
      }
    }

    // Rollover: If no budgets exist for currentPeriod, copy allocations from latest available period
    if (list.isEmpty && _budgetsBox.isNotEmpty) {
      final seenCats = <String, BudgetModel>{};
      for (var key in _budgetsBox.keys) {
        final jsonStr = _budgetsBox.get(key);
        if (jsonStr != null) {
          try {
            final data = json.decode(jsonStr);
            final b = BudgetModel.fromJson(data);
            seenCats[b.category] = b;
          } catch (_) {}
        }
      }

      for (var entry in seenCats.entries) {
        final newBudget = BudgetModel(
          category: entry.key,
          allocatedAmount: entry.value.allocatedAmount,
          period: currentPeriod,
          spentAmount: allTxs.where((t) => t.category == entry.key).fold(0.0, (s, t) => s + t.amount),
        );
        _budgetsBox.put("${entry.key}|$currentPeriod", json.encode(newBudget.toJson()));
        list.add(newBudget);
      }
    }

    return list;
  }

  Future<void> saveBudget(BudgetModel b) async {
    final key = "${b.category}|${b.period}";
    await _budgetsBox.put(key, json.encode(b.toJson()));
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
