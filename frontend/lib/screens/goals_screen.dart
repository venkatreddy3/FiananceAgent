import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/reallocation_proposal_card.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<SavingsGoalModel> _goals = [];
  Map<String, dynamic>? _reallocationPlan;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService().getGoals(),
      ApiService().getWeeklyReallocationPlan(),
    ]);

    if (mounted) {
      setState(() {
        _goals = results[0] as List<SavingsGoalModel>;
        _reallocationPlan = results[1] as Map<String, dynamic>;
        _isLoading = false;
      });
    }
  }

  void _showAddGoalDialog() {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final monthsController = TextEditingController(text: "6");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF0F5F8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: const Text("Create Savings Goal", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Goal Title (e.g. MacBook M3)"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Target Amount (₹)", prefixText: "₹ "),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: monthsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Target Horizon (Months)", suffixText: "mo"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final target = double.tryParse(targetController.text.trim()) ?? 0.0;
              final months = int.tryParse(monthsController.text.trim()) ?? 6;

              if (title.isNotEmpty && target > 0) {
                final monthlyTarget = target / (months > 0 ? months : 1);
                final newGoal = SavingsGoalModel(
                  title: title,
                  targetAmount: target,
                  currentProgress: 0.0,
                  targetDate: DateTime.now().add(Duration(days: months * 30)).toIso8601String().substring(0, 10),
                  monthlyTarget: monthlyTarget,
                );
                _goals.add(newGoal);
                Navigator.pop(ctx);
                setState(() {});
              }
            },
            child: const Text("Create Goal"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: AppTheme.tealPrimary)),
      );
    }

    final double totalTarget = _goals.fold(0.0, (s, g) => s + g.targetAmount);
    final double totalSaved = _goals.fold(0.0, (s, g) => s + g.currentProgress);

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Savings & Milestones"),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: AppTheme.tealPrimary),
              tooltip: "Add Savings Goal",
              onPressed: _showAddGoalDialog,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadGoals,
          color: AppTheme.tealPrimary,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              // Reallocation Proposal Card
              if (_reallocationPlan != null)
                ReallocationProposalCard(
                  planData: _reallocationPlan!,
                  onConfirmed: _loadGoals,
                ),

              const SizedBox(height: 8),

              // Summary Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TOTAL MILESTONE ACCUMULATION",
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "₹${totalSaved.toStringAsFixed(0)} / ₹${totalTarget.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${totalTarget > 0 ? (totalSaved / totalTarget * 100).toStringAsFixed(1) : 0}%",
                            style: const TextStyle(
                              color: AppTheme.tealPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: const Color(0x80FFFFFF), // 50% white track
                        color: AppTheme.tealPrimary,
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                "Active Goals & Projections",
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              ..._goals.map((g) {
                final ratio = g.progressRatio;
                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.lavenderAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.flag_outlined, color: AppTheme.lavenderDeep, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.title,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  "Target: ${g.targetDate} • ₹${g.monthlyTarget.toStringAsFixed(0)}/mo",
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "₹${g.currentProgress.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: AppTheme.tealPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: const Color(0x80FFFFFF),
                          color: ratio >= 0.9 ? AppTheme.roseDanger : AppTheme.tealPrimary,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Remaining: ₹${(g.targetAmount - g.currentProgress).clamp(0.0, double.infinity).toStringAsFixed(0)}",
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                          ),
                          Text(
                            "${(ratio * 100).toStringAsFixed(1)}% Completed",
                            style: const TextStyle(
                              color: AppTheme.tealPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
