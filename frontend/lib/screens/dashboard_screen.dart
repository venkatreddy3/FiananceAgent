import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/reallocation_proposal_card.dart';
import '../widgets/notification_simulator_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const DashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AnalyticsModel? _analytics;
  List<TransactionModel> _transactions = [];
  List<SavingsGoalModel> _goals = [];
  Map<String, dynamic>? _reallocationPlan;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService().getAnalytics(),
      ApiService().getTransactions(),
      ApiService().getGoals(),
      ApiService().getWeeklyReallocationPlan(),
    ]);

    if (mounted) {
      setState(() {
        _analytics = results[0] as AnalyticsModel;
        _transactions = results[1] as List<TransactionModel>;
        _goals = results[2] as List<SavingsGoalModel>;
        _reallocationPlan = results[3] as Map<String, dynamic>;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _analytics == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.emeraldPrimary)),
      );
    }

    final summary = _analytics!;
    final rule50 = summary.rule503020;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.emeraldPrimary, AppTheme.indigoAccent]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text("FinTrack AI", style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: AppTheme.cyanTech),
            tooltip: "Test Native Capture (PhonePe/GPay/SMS)",
            onPressed: () {
              NotificationSimulatorDialog.show(
                context,
                onTransactionProcessed: (tx, wasAuto) => _loadDashboardData(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppTheme.emeraldPrimary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Net Cash Flow Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF16233B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "NET SAVINGS (SEP 2026)",
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldPrimary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${summary.savingsRatePct.toStringAsFixed(1)}% Saved",
                          style: const TextStyle(
                            color: AppTheme.emeraldPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "₹${summary.netSavings.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.emeraldPrimary.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_downward, color: AppTheme.emeraldPrimary, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Income", style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                Text(
                                  "₹${summary.totalIncome.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppTheme.surfaceBorder),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.roseDanger.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_upward, color: AppTheme.roseDanger, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Expenses", style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                Text(
                                  "₹${summary.totalExpense.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Autonomous Reallocation Proposal
            if (_reallocationPlan != null)
              ReallocationProposalCard(
                planData: _reallocationPlan!,
                onConfirmed: _loadDashboardData,
              ),

            const SizedBox(height: 16),

            // 50/30/20 Budgeting Rule Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "50/30/20 Financial Health",
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () => widget.onNavigateTab(1),
                        child: const Text("View Budgets", style: TextStyle(color: AppTheme.indigoAccent, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Needs 50%
                  _buildRuleProgress(
                    label: "Needs (Target: 50%)",
                    spent: (rule50["needs"]?["spent"] as num?)?.toDouble() ?? 0.0,
                    actualPct: (rule50["needs"]?["actual_pct"] as num?)?.toDouble() ?? 0.0,
                    color: AppTheme.indigoAccent,
                  ),
                  const SizedBox(height: 12),

                  // Wants 30%
                  _buildRuleProgress(
                    label: "Wants (Target: 30%)",
                    spent: (rule50["wants"]?["spent"] as num?)?.toDouble() ?? 0.0,
                    actualPct: (rule50["wants"]?["actual_pct"] as num?)?.toDouble() ?? 0.0,
                    color: AppTheme.amberWarning,
                  ),
                  const SizedBox(height: 12),

                  // Savings 20%
                  _buildRuleProgress(
                    label: "Savings & Investments (Target: 20%)",
                    spent: (rule50["savings"]?["saved"] as num?)?.toDouble() ?? 0.0,
                    actualPct: (rule50["savings"]?["actual_pct"] as num?)?.toDouble() ?? 0.0,
                    color: AppTheme.emeraldPrimary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Active Savings Goals Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Active Savings Milestones",
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab(2),
                  child: const Text("All Goals", style: TextStyle(color: AppTheme.indigoAccent, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._goals.take(2).map((goal) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          goal.title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          "₹${goal.currentProgress.toStringAsFixed(0)} / ₹${goal.targetAmount.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: AppTheme.emeraldPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: goal.progressRatio,
                        backgroundColor: AppTheme.surfaceElevated,
                        color: AppTheme.emeraldPrimary,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // Recent Transactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Auto-Captured Transactions",
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab(3),
                  child: const Text("View All", style: TextStyle(color: AppTheme.indigoAccent, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ..._transactions.take(5).map((tx) {
              final isExpense = tx.type == "expense";
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isExpense ? AppTheme.surfaceElevated : AppTheme.emeraldPrimary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isExpense ? Icons.shopping_bag_outlined : Icons.account_balance_wallet_outlined,
                        color: isExpense ? AppTheme.indigoAccent : AppTheme.emeraldPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                tx.category,
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: tx.status == "auto"
                                      ? AppTheme.cyanTech.withOpacity(0.15)
                                      : AppTheme.emeraldPrimary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tx.status == "auto" ? "Auto" : "Confirmed",
                                  style: TextStyle(
                                    color: tx.status == "auto" ? AppTheme.cyanTech : AppTheme.emeraldPrimary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "${isExpense ? '-' : '+'}₹${tx.amount.toStringAsFixed(0)}",
                      style: TextStyle(
                        color: isExpense ? AppTheme.textPrimary : AppTheme.emeraldPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleProgress({
    required String label,
    required double spent,
    required double actualPct,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
            Text(
              "₹${spent.toStringAsFixed(0)} (${actualPct.toStringAsFixed(1)}%)",
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (actualPct / 100).clamp(0.0, 1.0),
            backgroundColor: AppTheme.surfaceElevated,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
