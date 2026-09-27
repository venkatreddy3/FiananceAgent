import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get baseUrl => StorageService().baseUrl;
  set baseUrl(String val) => StorageService().baseUrl = val;

  Map<String, String> get _headers {
    final key = StorageService().apiKey;
    final headers = {
      'Content-Type': 'application/json',
    };
    if (key.isNotEmpty) {
      headers['X-API-Key'] = key;
    }
    return headers;
  }

  bool isBackendOnline = false;

  // --- Health Check ---
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/health'),
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        isBackendOnline = true;
        return json.decode(res.body);
      }
    } catch (_) {}
    isBackendOnline = false;
    return {"status": "offline", "ollama_connected": false, "available_models": []};
  }

  // --- Transactions ---
  Future<List<TransactionModel>> getTransactions() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/transactions'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        isBackendOnline = true;
        final List list = json.decode(res.body);
        final txs = list.map((item) => TransactionModel.fromJson(item)).toList();
        // Merge by uuid in local storage
        for (var t in txs) {
          await StorageService().saveTransaction(t);
        }
        return StorageService().getTransactions();
      }
    } catch (_) {
      isBackendOnline = false;
    }
    // Return real offline local storage data (never fake data)
    return StorageService().getTransactions();
  }

  Future<TransactionModel> addTransaction(TransactionModel tx) async {
    // 1. Save to local storage first (offline-first with UUID)
    final savedTx = await StorageService().saveTransaction(tx);

    // 2. Try to sync to backend (upsert by uuid)
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/transactions'),
        headers: _headers,
        body: json.encode(savedTx.toJson()),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        isBackendOnline = true;
        final backendTx = TransactionModel.fromJson(json.decode(res.body));
        await StorageService().saveTransaction(backendTx);
        return backendTx;
      }
    } catch (_) {
      isBackendOnline = false;
    }

    return savedTx;
  }

  Future<TransactionModel> updateTransaction(TransactionModel tx, {String? previousCategory}) async {
    final saved = await StorageService().saveTransaction(tx);
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/transactions/by-uuid/${tx.uuid}'),
        headers: _headers,
        body: json.encode(tx.toJson()),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final backendTx = TransactionModel.fromJson(json.decode(res.body));
        await StorageService().saveTransaction(backendTx);
        return backendTx;
      }
    } catch (_) {}
    return saved;
  }

  Future<bool> deleteTransaction(dynamic idOrUuid) async {
    if (idOrUuid is String) {
      await StorageService().deleteTransaction(idOrUuid);
    } else if (idOrUuid is int) {
      await StorageService().deleteTransactionById(idOrUuid);
    }
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/transactions/$idOrUuid'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {}
    return true;
  }

  // --- Budgets ---
  Future<List<BudgetModel>> getBudgets([String? period]) async {
    final curPeriod = period ?? DateTime.now().toIso8601String().substring(0, 7);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/budgets?period=$curPeriod'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        isBackendOnline = true;
        final List list = json.decode(res.body);
        final budgets = list.map((item) => BudgetModel.fromJson(item)).toList();
        for (var b in budgets) {
          await StorageService().saveBudget(b);
        }
        return StorageService().getBudgets(curPeriod);
      }
    } catch (_) {
      isBackendOnline = false;
    }
    return StorageService().getBudgets(curPeriod);
  }

  Future<BudgetModel> createOrUpdateBudget(BudgetModel b) async {
    await StorageService().saveBudget(b);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/budgets'),
        headers: _headers,
        body: json.encode(b.toJson()),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        return BudgetModel.fromJson(json.decode(res.body));
      }
    } catch (_) {}
    return b;
  }

  // --- Goals ---
  Future<List<SavingsGoalModel>> getGoals() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/goals'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        isBackendOnline = true;
        final List list = json.decode(res.body);
        final goals = list.map((item) => SavingsGoalModel.fromJson(item)).toList();
        for (var g in goals) {
          await StorageService().saveGoal(g);
        }
        return goals;
      }
    } catch (_) {
      isBackendOnline = false;
    }
    return StorageService().getGoals();
  }

  Future<SavingsGoalModel> createGoal(SavingsGoalModel goal) async {
    await StorageService().saveGoal(goal);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/goals'),
        headers: _headers,
        body: json.encode(goal.toJson()),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return SavingsGoalModel.fromJson(json.decode(res.body));
      }
    } catch (_) {}
    return goal;
  }

  // --- Analytics Dashboard (Calculated from Real Data) ---
  Future<AnalyticsModel> getAnalytics() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/analytics'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        isBackendOnline = true;
        return AnalyticsModel.fromJson(json.decode(res.body));
      }
    } catch (_) {
      isBackendOnline = false;
    }

    // Compute from real local storage data
    final transactions = StorageService().getTransactions();
    final budgets = StorageService().getBudgets();

    double income = transactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
    double expense = transactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
    double savings = income - expense;
    double savingsRate = income > 0 ? (savings / income * 100) : 0.0;

    final Map<String, double> catMap = {};
    for (var t in transactions.where((t) => t.type == 'expense')) {
      catMap[t.category] = (catMap[t.category] ?? 0.0) + t.amount;
    }

    final needsCats = {"Housing", "Bills & Utilities", "Food & Dining", "Transportation", "Healthcare", "Groceries"};
    double needsSpent = 0.0;
    double wantsSpent = 0.0;

    catMap.forEach((cat, amt) {
      if (needsCats.contains(cat)) {
        needsSpent += amt;
      } else {
        wantsSpent += amt;
      }
    });

    final totalBudgetLimit = budgets.fold(0.0, (s, b) => s + b.allocatedAmount);
    final totalBudgetSpent = budgets.fold(0.0, (s, b) => s + b.spentAmount);

    return AnalyticsModel(
      currency: "INR",
      totalIncome: income,
      totalExpense: expense,
      netSavings: savings,
      savingsRatePct: savingsRate,
      totalBudgetLimit: totalBudgetLimit,
      totalBudgetSpent: totalBudgetSpent,
      budgetHealthPct: totalBudgetLimit > 0 ? (totalBudgetSpent / totalBudgetLimit * 100) : 0.0,
      rule503020: {
        "needs": {"spent": needsSpent, "actual_pct": income > 0 ? (needsSpent / income * 100) : 0.0},
        "wants": {"spent": wantsSpent, "actual_pct": income > 0 ? (wantsSpent / income * 100) : 0.0},
        "savings": {"saved": savings, "actual_pct": savingsRate},
      },
      categoryBreakdown: catMap.entries.map((e) => {"category": e.key, "amount": e.value}).toList(),
    );
  }

  // --- Smart Capture: Parse Notification / SMS ---
  Future<Map<String, dynamic>> parseNotification(String rawText, {String? sourceApp}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/capture/parse-notification'),
        headers: _headers,
        body: json.encode({
          'raw_text': rawText,
          'source_app': sourceApp ?? 'notification',
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
    } catch (_) {}

    return {
      "extracted": {"amount": 0.0, "merchant": "Unknown", "is_p2p": false},
      "categorization": {"category": "Uncategorized", "confidence": 0.0, "needs_user_confirmation": true},
      "auto_logged": false,
    };
  }

  // --- Learn Merchant Mapping ---
  Future<bool> learnMerchantMapping(String merchantKey, String category) async {
    await StorageService().saveLearnedMerchant(merchantKey, category);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/dictionary/learn'),
        headers: _headers,
        body: json.encode({'merchant_key': merchantKey, 'category': category}),
      ).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {}
    return true;
  }

  // --- Weekly Re-planning & Slack Detection ---
  Future<Map<String, dynamic>?> getWeeklyReallocationPlan() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/goals/reallocation-plan'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> confirmReallocation(int goalId, double additionAmount, Map<String, dynamic> adjustments) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/goals/reallocation-plan/confirm'),
        headers: _headers,
        body: json.encode({
          'goal_id': goalId,
          'addition_amount': additionAmount,
          'category_adjustments': adjustments,
        }),
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  // --- AI Agent Chat ---
  Future<Map<String, dynamic>> chatWithAgent(String agent, String message) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/agent/chat'),
        headers: _headers,
        body: json.encode({'agent': agent, 'message': message}),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
    } catch (_) {}

    return {
      "agent": agent,
      "role_title": "FinTrack Assistant",
      "response": "⚠️ Local/Offline Mode: Ollama backend is currently unreachable. Connect to your server to chat with live multi-agent models.",
      "model_used": "offline",
      "source": "offline"
    };
  }
}
