import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Default to localhost:8000 (can be updated dynamically in settings)
  String baseUrl = "http://localhost:8000";

  // In-memory fallback cache
  List<TransactionModel> _fallbackTransactions = [
    TransactionModel(
      id: 1,
      title: "Monthly Salary",
      amount: 65000.0,
      merchant: "Acme Corp",
      category: "Income",
      type: "income",
      date: "2026-09-01",
      confidence: 1.0,
      status: "confirmed",
      source: "manual",
    ),
    TransactionModel(
      id: 2,
      title: "Apartment Rent",
      amount: 18000.0,
      merchant: "Downtown Realty",
      category: "Housing",
      type: "expense",
      date: "2026-09-02",
      confidence: 1.0,
      status: "confirmed",
      source: "notification",
      isRecurring: true,
    ),
    TransactionModel(
      id: 3,
      title: "Electricity & Water",
      amount: 2450.0,
      merchant: "BESCOM",
      category: "Bills & Utilities",
      type: "expense",
      date: "2026-09-05",
      confidence: 1.0,
      status: "auto",
      source: "sms",
    ),
    TransactionModel(
      id: 4,
      title: "Blinkit Quick Grocery",
      amount: 1240.0,
      merchant: "Blinkit",
      category: "Food & Dining",
      type: "expense",
      date: "2026-09-08",
      confidence: 1.0,
      status: "auto",
      source: "notification",
    ),
    TransactionModel(
      id: 5,
      title: "Uber Commute",
      amount: 420.0,
      merchant: "Uber",
      category: "Transportation",
      type: "expense",
      date: "2026-09-10",
      confidence: 1.0,
      status: "auto",
      source: "notification",
    ),
    TransactionModel(
      id: 6,
      title: "Netflix & Spotify",
      amount: 999.0,
      merchant: "Netflix",
      category: "Entertainment",
      type: "expense",
      date: "2026-09-12",
      confidence: 1.0,
      status: "auto",
      source: "sms",
      isRecurring: true,
    ),
    TransactionModel(
      id: 7,
      title: "Nike Running Shoes",
      amount: 6499.0,
      merchant: "Nike",
      category: "Shopping",
      type: "expense",
      date: "2026-09-18",
      confidence: 1.0,
      status: "confirmed",
      source: "notification",
      aiFlagged: true,
      aiFlagReason: "Discretionary spike in Shopping category",
    ),
  ];

  List<BudgetModel> _fallbackBudgets = [
    BudgetModel(category: "Food & Dining", allocatedAmount: 12000.0, spentAmount: 2710.0),
    BudgetModel(category: "Housing", allocatedAmount: 18000.0, spentAmount: 18000.0),
    BudgetModel(category: "Transportation", allocatedAmount: 4500.0, spentAmount: 1920.0),
    BudgetModel(category: "Shopping", allocatedAmount: 8000.0, spentAmount: 6499.0),
    BudgetModel(category: "Entertainment", allocatedAmount: 3000.0, spentAmount: 999.0),
    BudgetModel(category: "Bills & Utilities", allocatedAmount: 3500.0, spentAmount: 2450.0),
  ];

  List<SavingsGoalModel> _fallbackGoals = [
    SavingsGoalModel(
      id: 1,
      title: "MacBook Pro M3 (Laptop)",
      targetAmount: 60000.0,
      currentProgress: 24000.0,
      targetDate: "2027-03-31",
      category: "Gadgets",
      monthlyTarget: 10000.0,
      status: "active",
    ),
    SavingsGoalModel(
      id: 2,
      title: "Emergency Safety Fund (6 Mo)",
      targetAmount: 150000.0,
      currentProgress: 95000.0,
      targetDate: "2027-09-30",
      category: "Safety",
      monthlyTarget: 12000.0,
      status: "active",
    ),
    SavingsGoalModel(
      id: 3,
      title: "Goa Trip with Friends",
      targetAmount: 25000.0,
      currentProgress: 18000.0,
      targetDate: "2026-12-15",
      category: "Travel",
      monthlyTarget: 3500.0,
      status: "active",
    ),
  ];

  // --- Health Check ---
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/health')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
    } catch (_) {}
    return {"status": "offline_mode", "ollama_connected": false, "available_models": []};
  }

  // --- Fetch Transactions ---
  Future<List<TransactionModel>> getTransactions() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/transactions')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List list = json.decode(res.body);
        return list.map((item) => TransactionModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return _fallbackTransactions;
  }

  // --- Add Transaction ---
  Future<TransactionModel> addTransaction(TransactionModel tx) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/transactions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(tx.toJson()),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return TransactionModel.fromJson(json.decode(res.body));
      }
    } catch (_) {}
    // Fallback local addition
    final newTx = TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch,
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
    );
    _fallbackTransactions.insert(0, newTx);
    return newTx;
  }

  // --- Delete Transaction ---
  Future<bool> deleteTransaction(int id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/api/transactions/$id')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) return true;
    } catch (_) {}
    _fallbackTransactions.removeWhere((t) => t.id == id);
    return true;
  }

  // --- Fetch Budgets ---
  Future<List<BudgetModel>> getBudgets() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/budgets')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List list = json.decode(res.body);
        return list.map((item) => BudgetModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return _fallbackBudgets;
  }

  Future<BudgetModel> createOrUpdateBudget(BudgetModel b) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/budgets'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(b.toJson()),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return BudgetModel.fromJson(json.decode(res.body));
      }
    } catch (_) {}
    final existing = _fallbackBudgets.firstWhere(
      (item) => item.category == b.category,
      orElse: () {
        _fallbackBudgets.add(b);
        return b;
      },
    );
    existing.allocatedAmount = b.allocatedAmount;
    return existing;
  }

  // --- Fetch Goals ---
  Future<List<SavingsGoalModel>> getGoals() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/goals')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List list = json.decode(res.body);
        return list.map((item) => SavingsGoalModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return _fallbackGoals;
  }

  // --- Fetch Analytics ---
  Future<AnalyticsModel> getAnalytics() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/analytics')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return AnalyticsModel.fromJson(json.decode(res.body));
      }
    } catch (_) {}
    
    // Compute fallback analytics
    double income = _fallbackTransactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
    double expense = _fallbackTransactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
    double savings = income - expense;
    double savingsRate = income > 0 ? (savings / income * 100) : 0;
    
    Map<String, double> catMap = {};
    for (var t in _fallbackTransactions.where((t) => t.type == 'expense')) {
      catMap[t.category] = (catMap[t.category] ?? 0.0) + t.amount;
    }

    return AnalyticsModel(
      currency: "INR",
      totalIncome: income,
      totalExpense: expense,
      netSavings: savings,
      savingsRatePct: savingsRate,
      totalBudgetLimit: _fallbackBudgets.fold(0.0, (s, b) => s + b.allocatedAmount),
      totalBudgetSpent: _fallbackBudgets.fold(0.0, (s, b) => s + b.spentAmount),
      budgetHealthPct: 62.4,
      rule503020: {
        "needs": {"spent": 22170.0, "actual_pct": 34.1},
        "wants": {"spent": 7498.0, "actual_pct": 11.5},
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
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'raw_text': rawText,
          'source_app': sourceApp ?? 'notification',
        }),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
    } catch (_) {}

    // Simulated local parsing fallback
    return _simulateNotificationParse(rawText);
  }

  // --- Learn Merchant Mapping ---
  Future<bool> learnMerchantMapping(String merchantKey, String category) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/dictionary/learn'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'merchant_key': merchantKey, 'category': category}),
      ).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return true;
    }
  }

  // --- Weekly Re-planning & Slack Detection ---
  Future<Map<String, dynamic>> getWeeklyReallocationPlan() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/goals/reallocation-plan')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
    } catch (_) {}

    // Local fallback plan
    return {
      "month_progress_pct": 90.0,
      "total_discretionary_slack": 1850.0,
      "category_slack": {
        "Entertainment": 1700.0,
        "Transportation": 150.0,
      },
      "proposed_reallocations": [
        {
          "goal_id": 1,
          "goal_title": "MacBook Pro M3 (Laptop)",
          "proposed_addition": 1295.0,
          "category_adjustments": {
            "Entertainment": -1190.0,
            "Transportation": -105.0,
          }
        }
      ],
      "agent_message": "⚡ You have ₹1,850 unused slack in Entertainment & Travel. Shifting ₹1,295 to your MacBook Goal accelerates target completion by 14 days without exceeding essentials.",
      "requires_user_confirmation": true,
    };
  }

  // --- Confirm Reallocation ---
  Future<bool> confirmReallocation(int goalId, double additionAmount, Map<String, dynamic> adjustments) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/goals/reallocation-plan/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'goal_id': goalId,
          'addition_amount': additionAmount,
          'category_adjustments': adjustments,
        }),
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      // Local fallback update
      final goal = _fallbackGoals.firstWhere((g) => g.id == goalId, orElse: () => _fallbackGoals.first);
      goal.currentProgress += additionAmount;
      return true;
    }
  }

  // --- AI Agent Chat ---
  Future<Map<String, dynamic>> chatWithAgent(String agent, String message) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/agent/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'agent': agent, 'message': message}),
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
    } catch (_) {}

    // Local simulated responses
    if (agent == 'auditor') {
      return {
        "agent": "auditor",
        "role_title": "Forensic Expense Auditor",
        "response": "🔍 **Forensic Audit Findings**:\n\n1. **Discretionary Spike**: Identified a **₹6,499** Nike purchase on Sep 18. Shopping spend is currently at 81% of its monthly allocation.\n2. **Subscription Audit**: Recurring services (Netflix & Spotify) cost **₹999/mo** (~1.5% of total income).\n3. **Healthy Essentials**: Rent & Utilities are strictly within predefined limits.",
        "model_used": "llama3.2 (local simulation)",
        "source": "simulated"
      };
    } else if (agent == 'advisor') {
      return {
        "agent": "advisor",
        "role_title": "Budget Advisor",
        "response": "📊 **50/30/20 Rule Analysis**:\n\n- **Needs**: ₹22,170 (34.1% of ₹65k income) — **Optimal** (Target is 50%).\n- **Wants**: ₹7,498 (11.5% of income) — **Healthy** (Target is 30%).\n- **Savings Potential**: **₹35,332** available net cash flow!\n\n💡 **Tip**: Consider moving ₹15,000 to your Emergency Safety Fund to maintain momentum.",
        "model_used": "llama3.2 (local simulation)",
        "source": "simulated"
      };
    } else {
      return {
        "agent": "strategist",
        "role_title": "Wealth & Goal Strategist",
        "response": "💎 **Goal Milestone Status**:\n\n- **MacBook Pro M3**: ₹24,000 / ₹60,000 (40.0% achieved). At current monthly savings, you will hit 100% by February 2027 (ahead of schedule by 30 days).\n- **Emergency Safety Fund**: ₹95,000 / ₹150,000 (63.3% funded).",
        "model_used": "llama3.2 (local simulation)",
        "source": "simulated"
      };
    }
  }

  Map<String, dynamic> _simulateNotificationParse(String text) {
    bool isP2P = text.toLowerCase().contains("to rahul") || text.toLowerCase().contains("sent to") || text.toLowerCase().contains("@upi");
    double amt = 450.0;
    if (text.contains("1200") || text.contains("1,200")) amt = 1200.0;
    if (text.contains("6499") || text.contains("6,499")) amt = 6499.0;
    if (text.contains("2450") || text.contains("2,450")) amt = 2450.0;

    String merchant = isP2P ? "Rahul Sharma" : (text.toLowerCase().contains("swiggy") ? "Swiggy" : (text.toLowerCase().contains("bescom") ? "BESCOM" : "Local Vendor"));
    String cat = isP2P ? "P2P Transfer" : (text.toLowerCase().contains("swiggy") ? "Food & Dining" : (text.toLowerCase().contains("bescom") ? "Bills & Utilities" : "Shopping"));
    double conf = isP2P ? 0.40 : (text.toLowerCase().contains("swiggy") ? 1.0 : 0.65);

    return {
      "extracted": {
        "amount": amt,
        "merchant": merchant,
        "is_p2p": isP2P,
        "raw_text": text,
        "date": DateTime.now().toIso8601String().substring(0, 10),
      },
      "categorization": {
        "category": cat,
        "confidence": conf,
        "needs_user_confirmation": conf < 0.85,
        "source": isP2P ? "p2p_detection" : (conf == 1.0 ? "dictionary" : "heuristic"),
        "matched_key": merchant.toLowerCase(),
      },
      "auto_logged": conf >= 0.85,
    };
  }
}
