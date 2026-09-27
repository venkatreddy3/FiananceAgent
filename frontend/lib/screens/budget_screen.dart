import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  double _monthlyCap = 45000.0;
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
        _monthlyCap = _budgets.fold(0.0, (sum, b) => sum + b.allocatedAmount);
        if (_monthlyCap < 10000) _monthlyCap = 45000.0;
        _isLoading = false;
      });
    }
  }

  void _updateBudgetAmount(BudgetModel budget, double newAmount) {
    setState(() {
      budget.allocatedAmount = newAmount;
    });
  }

  void _saveBudgetChanges() async {
    for (var b in _budgets) {
      await ApiService().createOrUpdateBudget(b);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.tealPrimary,
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppTheme.tealDark, size: 20),
              const SizedBox(width: 8),
              const Text(
                "Category budgets saved successfully!",
                style: TextStyle(color: AppTheme.tealDark, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSetCapDialog() {
    final capController = TextEditingController(text: _monthlyCap.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF0F5F8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: const Text("Set Total Monthly Cap", style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        content: TextField(
          controller: capController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Monthly Cap (₹)", prefixText: "₹ "),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(capController.text.trim()) ?? _monthlyCap;
              setState(() => _monthlyCap = val);
              Navigator.pop(ctx);
            },
            child: const Text("Update Cap"),
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

    final double totalAllocated = _budgets.fold(0.0, (s, b) => s + b.allocatedAmount);
    final double diff = _monthlyCap - totalAllocated;
    final bool isBalanced = diff.abs() < 100;
    final bool isOverCap = totalAllocated > _monthlyCap;

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Monthly Budget Allocator"),
          actions: [
            IconButton(
              icon: const Icon(Icons.check, color: AppTheme.tealLight),
              tooltip: "Save Budget Envelopes",
              onPressed: _saveBudgetChanges,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadBudgets,
          color: AppTheme.tealPrimary,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              // 1. Total Allocated vs Cap Live Tracker
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "TOTAL ALLOCATED VS MONTHLY CAP",
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        InkWell(
                          onTap: _showSetCapDialog,
                          child: const Row(
                            children: [
                              Icon(Icons.edit, color: AppTheme.lavenderAccent, size: 14),
                              SizedBox(width: 4),
                              Text(
                                "Edit Cap",
                                style: TextStyle(color: AppTheme.lavenderAccent, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "₹${totalAllocated.toStringAsFixed(0)} / ₹${_monthlyCap.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOverCap
                                ? AppTheme.roseDanger.withValues(alpha: 0.2)
                                : (isBalanced ? AppTheme.tealPrimary.withValues(alpha: 0.2) : AppTheme.amberWarning.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOverCap
                                ? "Over Cap by ₹${(totalAllocated - _monthlyCap).toStringAsFixed(0)}"
                                : (isBalanced ? "Balanced" : "₹${diff.toStringAsFixed(0)} Unassigned"),
                            style: TextStyle(
                              color: isOverCap ? AppTheme.roseDanger : (isBalanced ? AppTheme.tealLight : AppTheme.amberWarning),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _monthlyCap > 0 ? (totalAllocated / _monthlyCap).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: const Color(0x80FFFFFF),
                        color: isOverCap ? AppTheme.roseDanger : AppTheme.tealPrimary,
                        minHeight: 7,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                "Category Allocation Sliders",
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),

              // 2. Category Sliders
              ..._budgets.map((b) {
                final double allocated = b.allocatedAmount;
                final double spent = b.spentAmount;
                final double pctOfCap = _monthlyCap > 0 ? (allocated / _monthlyCap * 100) : 0.0;

                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                "Spent: ₹${spent.toStringAsFixed(0)} (${(b.utilizationRatio * 100).toStringAsFixed(0)}% used)",
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "₹${allocated.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  color: AppTheme.tealLight,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                "${pctOfCap.toStringAsFixed(1)}% of Cap",
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Interactive Slider
                      Slider(
                        value: allocated.clamp(0.0, _monthlyCap * 1.5),
                        min: 0,
                        max: _monthlyCap > 0 ? _monthlyCap : 50000,
                        divisions: 100,
                        activeColor: AppTheme.tealPrimary,
                        inactiveColor: const Color(0x80FFFFFF),
                        onChanged: (val) => _updateBudgetAmount(b, val.roundToDouble()),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveBudgetChanges,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text("Save Category Envelopes"),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
