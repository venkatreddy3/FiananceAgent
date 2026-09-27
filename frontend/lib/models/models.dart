class TransactionModel {
  final int? id;
  final String title;
  final double amount;
  final String merchant;
  final String? rawText;
  final String category;
  final String source; // "merchant", "p2p", "sms", "notification", "manual"
  final String type; // "expense" or "income"
  final String date;
  final double confidence;
  final String status; // "auto", "confirmed", "skipped"
  final String? notes;
  final bool isRecurring;
  final bool aiFlagged;
  final String? aiFlagReason;

  TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.merchant,
    this.rawText,
    required this.category,
    this.source = "merchant",
    this.type = "expense",
    required this.date,
    this.confidence = 1.0,
    this.status = "auto",
    this.notes,
    this.isRecurring = false,
    this.aiFlagged = false,
    this.aiFlagReason,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      title: json['title'] ?? json['merchant'] ?? 'Transaction',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      merchant: json['merchant'] ?? '',
      rawText: json['raw_text'],
      category: json['category'] ?? 'Other',
      source: json['source'] ?? 'manual',
      type: json['type'] ?? 'expense',
      date: json['date'] ?? DateTime.now().toIso8601String().substring(0, 10),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      status: json['status'] ?? 'auto',
      notes: json['notes'],
      isRecurring: json['is_recurring'] ?? false,
      aiFlagged: json['ai_flagged'] ?? false,
      aiFlagReason: json['ai_flag_reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'merchant': merchant,
      'raw_text': rawText,
      'category': category,
      'source': source,
      'type': type,
      'date': date,
      'confidence': confidence,
      'status': status,
      'notes': notes,
      'is_recurring': isRecurring,
      'ai_flagged': aiFlagged,
      'ai_flag_reason': aiFlagReason,
    };
  }
}

class BudgetModel {
  final int? id;
  final String category;
  double allocatedAmount;
  double spentAmount;
  final String period;

  BudgetModel({
    this.id,
    required this.category,
    required this.allocatedAmount,
    this.spentAmount = 0.0,
    this.period = "2026-09",
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'],
      category: json['category'] ?? 'Other',
      allocatedAmount: (json['allocated_amount'] as num?)?.toDouble() ?? 0.0,
      spentAmount: (json['spent_amount'] as num?)?.toDouble() ?? 0.0,
      period: json['period'] ?? '2026-09',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'allocated_amount': allocatedAmount,
      'spent_amount': spentAmount,
      'period': period,
    };
  }

  double get utilizationRatio => allocatedAmount > 0 ? (spentAmount / allocatedAmount) : 0.0;
  double get remainingAmount => allocatedAmount - spentAmount;
}

class SavingsGoalModel {
  final int? id;
  final String title;
  final double targetAmount;
  double currentProgress;
  final String targetDate;
  final String category;
  final String status;
  final double monthlyTarget;

  SavingsGoalModel({
    this.id,
    required this.title,
    required this.targetAmount,
    this.currentProgress = 0.0,
    required this.targetDate,
    this.category = "Gadgets",
    this.status = "active",
    this.monthlyTarget = 0.0,
  });

  factory SavingsGoalModel.fromJson(Map<String, dynamic> json) {
    return SavingsGoalModel(
      id: json['id'],
      title: json['title'] ?? '',
      targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0.0,
      currentProgress: (json['current_progress'] as num?)?.toDouble() ?? 0.0,
      targetDate: json['target_date'] ?? '',
      category: json['category'] ?? 'General',
      status: json['status'] ?? 'active',
      monthlyTarget: (json['monthly_target'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'target_amount': targetAmount,
      'current_progress': currentProgress,
      'target_date': targetDate,
      'category': category,
      'status': status,
      'monthly_target': monthlyTarget,
    };
  }

  double get progressRatio => targetAmount > 0 ? (currentProgress / targetAmount).clamp(0.0, 1.0) : 0.0;
}

class AnalyticsModel {
  final String currency;
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final double savingsRatePct;
  final double totalBudgetLimit;
  final double totalBudgetSpent;
  final double budgetHealthPct;
  final Map<String, dynamic> rule503020;
  final List<Map<String, dynamic>> categoryBreakdown;

  AnalyticsModel({
    this.currency = "INR",
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRatePct,
    required this.totalBudgetLimit,
    required this.totalBudgetSpent,
    required this.budgetHealthPct,
    required this.rule503020,
    required this.categoryBreakdown,
  });

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] ?? {};
    return AnalyticsModel(
      currency: json['currency'] ?? 'INR',
      totalIncome: (summary['total_income'] as num?)?.toDouble() ?? 0.0,
      totalExpense: (summary['total_expense'] as num?)?.toDouble() ?? 0.0,
      netSavings: (summary['net_savings'] as num?)?.toDouble() ?? 0.0,
      savingsRatePct: (summary['savings_rate_pct'] as num?)?.toDouble() ?? 0.0,
      totalBudgetLimit: (summary['total_budget_limit'] as num?)?.toDouble() ?? 0.0,
      totalBudgetSpent: (summary['total_budget_spent'] as num?)?.toDouble() ?? 0.0,
      budgetHealthPct: (summary['budget_health_pct'] as num?)?.toDouble() ?? 0.0,
      rule503020: Map<String, dynamic>.from(json['rule_50_30_20'] ?? {}),
      categoryBreakdown: List<Map<String, dynamic>>.from(json['category_breakdown'] ?? []),
    );
  }
}
