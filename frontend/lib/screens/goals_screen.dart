import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
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
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.surfaceBorder),
        ),
        title: const Text("Create Savings Goal", style: TextStyle(fontWeight: FontWeight.w700)),
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
        body: Center(child: CircularProgressIndicator(color: AppTheme.emeraldPrimary)),
      );
    }

    final double totalTarget = _goals.fold(0.0, (s, g) => s + g.targetAmount);
    final double totalSaved = _goals.fold(0.0, (s, g) => s + g.currentProgress);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Savings & Milestones"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.emeraldPrimary),
            tooltip: "Add Savings Goal",
            onPressed: _showAddGoalDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGoals,
        color: AppTheme.emeraldPrimary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Reallocation Proposal
            if (_reallocationPlan != null)
              ReallocationProposalCard(
                planData: _reallocationPlan!,
                onConfirmed: _loadGoals,
              ),

            const SizedBox(height: 12),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
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
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        "${totalTarget > 0 ? (totalSaved / totalTarget * 100).toStringAsFixed(1) : 0}%",
                        style: const TextStyle(
                          color: AppTheme.emeraldPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0,
                      backgroundColor: AppTheme.surfaceElevated,
                      color: AppTheme.emeraldPrimary,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              "Active Goals & Projections",
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            ..._goals.map((g) {
              final ratio = g.progressRatio;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.purpleAgent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.flag_outlined, color: AppTheme.purpleAgent, size: 20),
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
                                "Target Date: ${g.targetDate} • ₹${g.monthlyTarget.toStringAsFixed(0)}/mo",
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "₹${g.currentProgress.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: AppTheme.emeraldPrimary,
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
                        backgroundColor: AppTheme.surfaceElevated,
                        color: AppTheme.emeraldPrimary,
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
                            color: AppTheme.emeraldPrimary,
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
    );
  }
}
