import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<BudgetModel> _budgets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    setState(() => _isLoading = true);
    final data = await ApiService().getBudgets();
    if (mounted) {
      setState(() {
        _budgets = data;
        _isLoading = false;
      });
    }
  }

  void _showAddBudgetDialog() {
    final catController = TextEditingController();
    final limitController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.surfaceBorder),
        ),
        title: const Text("Set Category Budget", style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: catController,
              decoration: const InputDecoration(labelText: "Category Name (e.g. Dining)"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: limitController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Monthly Limit (₹)", prefixText: "₹ "),
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
              final cat = catController.text.trim();
              final limit = double.tryParse(limitController.text.trim()) ?? 0.0;
              if (cat.isNotEmpty && limit > 0) {
                final newBudget = BudgetModel(category: cat, allocatedAmount: limit);
                _budgets.add(newBudget);
                Navigator.pop(ctx);
                setState(() {});
                ApiService().getBudgets();
              }
            },
            child: const Text("Save Limit"),
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

    final double totalAllocated = _budgets.fold(0.0, (s, b) => s + b.allocatedAmount);
    final double totalSpent = _budgets.fold(0.0, (s, b) => s + b.spentAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Monthly Category Budgets"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.emeraldPrimary),
            tooltip: "Add Category Budget",
            onPressed: _showAddBudgetDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBudgets,
        color: AppTheme.emeraldPrimary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Overall Utilization Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
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
                    "TOTAL MONTHLY BUDGET ALLOCATION",
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
                        "₹${totalSpent.toStringAsFixed(0)} / ₹${totalAllocated.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        "${totalAllocated > 0 ? (totalSpent / totalAllocated * 100).toStringAsFixed(1) : 0}%",
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
                      value: totalAllocated > 0 ? (totalSpent / totalAllocated).clamp(0.0, 1.0) : 0.0,
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
              "Category Envelopes & Utilization",
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            ..._budgets.map((b) {
              final double ratio = b.utilizationRatio;
              final bool isOver = ratio > 1.0;
              final bool isNear = ratio > 0.8 && !isOver;
              final Color statusColor = isOver
                  ? AppTheme.roseDanger
                  : (isNear ? AppTheme.amberWarning : AppTheme.emeraldPrimary);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOver ? AppTheme.roseDanger.withOpacity(0.5) : AppTheme.surfaceBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          b.category,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          "₹${b.spentAmount.toStringAsFixed(0)} / ₹${b.allocatedAmount.toStringAsFixed(0)}",
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio.clamp(0.0, 1.0),
                        backgroundColor: AppTheme.surfaceElevated,
                        color: statusColor,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isOver
                              ? "Exceeded by ₹${(b.spentAmount - b.allocatedAmount).toStringAsFixed(0)}"
                              : "Remaining: ₹${b.remainingAmount.toStringAsFixed(0)}",
                          style: TextStyle(
                            color: isOver ? AppTheme.roseDanger : AppTheme.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "${(ratio * 100).toStringAsFixed(0)}% used",
                          style: TextStyle(color: statusColor, fontSize: 11.5, fontWeight: FontWeight.w700),
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
