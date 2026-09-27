import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/transaction_capture_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/spend_chart_card.dart';
import '../widgets/uncategorized_transaction_card.dart';
import '../widgets/reallocation_proposal_card.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const DashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AnalyticsModel? _analytics;
  List<TransactionModel> _transactions = [];
  List<BudgetModel> _budgets = [];
  Map<String, dynamic>? _reallocationPlan;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    // Live update when new transactions are captured
    TransactionCaptureService().onTransactionCaptured.listen((_) {
      if (mounted) _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    await ApiService().checkHealth();
    final results = await Future.wait([
      ApiService().getAnalytics(),
      ApiService().getTransactions(),
      ApiService().getBudgets(),
      ApiService().getWeeklyReallocationPlan(),
    ]);

    if (mounted) {
      setState(() {
        _analytics = results[0] as AnalyticsModel;
        _transactions = results[1] as List<TransactionModel>;
        _budgets = results[2] as List<BudgetModel>;
        _reallocationPlan = results[3] as Map<String, dynamic>?;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _analytics == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: AppTheme.tealPrimary)),
      );
    }

    final summary = _analytics!;
    final uncategorized = _transactions.where((t) => t.category == "Uncategorized" || t.status == "skipped").toList();
    final isOnline = ApiService().isBackendOnline;

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.tealPrimary, AppTheme.lavenderAccent]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "FinTrack",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOnline ? AppTheme.tealPrimary : AppTheme.amberWarning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOnline ? "AI Sync Active" : "Offline - AI paused",
                        style: TextStyle(
                          color: isOnline ? AppTheme.tealPrimary : AppTheme.amberWarning,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppTheme.textPrimary),
              tooltip: "Settings & Gateway",
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
                ).then((_) => _loadDashboardData());
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
          color: AppTheme.tealPrimary,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              // 1. Monthly Overview Hero Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "SEPTEMBER OVERVIEW",
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "₹${(summary.totalBudgetLimit - summary.totalExpense).clamp(0.0, double.infinity).toStringAsFixed(0)} Left of Cap",
                            style: const TextStyle(
                              color: AppTheme.tealPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "₹${summary.totalExpense.toStringAsFixed(0)}",
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: summary.totalBudgetLimit > 0
                            ? (summary.totalExpense / summary.totalBudgetLimit).clamp(0.0, 1.0)
                            : 0.0,
                        backgroundColor: const Color(0x80FFFFFF),
                        color: (summary.totalBudgetLimit > 0 && summary.totalExpense / summary.totalBudgetLimit >= 0.9)
                            ? AppTheme.roseDanger
                            : AppTheme.tealPrimary,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total Monthly Cap: ₹${summary.totalBudgetLimit.toStringAsFixed(0)}",
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                        Text(
                          "Income: ₹${summary.totalIncome.toStringAsFixed(0)}",
                          style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 2. Spend Velocity Chart
              SpendChartCard(totalSpend: summary.totalExpense),

              // 3. Autonomous AI Reallocation Proposal Card
              if (_reallocationPlan != null)
                ReallocationProposalCard(
                  planData: _reallocationPlan!,
                  onConfirmed: _loadDashboardData,
                ),

              const SizedBox(height: 8),

              // 4. Uncategorized Transactions Section
              if (uncategorized.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Needs Categorization",
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.amberWarning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "${uncategorized.length}",
                            style: const TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      "Tap to resolve",
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...uncategorized.map((tx) {
                  return UncategorizedTransactionCard(
                    transaction: tx,
                    onResolved: (resolved) => _loadDashboardData(),
                  );
                }),
                const SizedBox(height: 8),
              ],

              // 5. Per-Category Progress Bars
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Category Envelopes",
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(1),
                    child: const Text(
                      "Adjust Sliders →",
                      style: TextStyle(color: AppTheme.lavenderDeep, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              ..._budgets.take(4).map((b) {
                final ratio = b.utilizationRatio;
                final isOver = ratio > 1.0;
                final Color barColor = isOver || ratio >= 0.9
                    ? AppTheme.roseDanger
                    : (ratio > 0.75 ? AppTheme.amberWarning : AppTheme.tealPrimary);

                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            b.category,
                            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                          Text(
                            "₹${b.spentAmount.toStringAsFixed(0)} / ₹${b.allocatedAmount.toStringAsFixed(0)}",
                            style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          backgroundColor: const Color(0x80FFFFFF),
                          color: barColor,
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
