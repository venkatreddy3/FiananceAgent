import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class ReallocationProposalCard extends StatefulWidget {
  final Map<String, dynamic> planData;
  final VoidCallback onConfirmed;

  const ReallocationProposalCard({
    super.key,
    required this.planData,
    required this.onConfirmed,
  });

  @override
  State<ReallocationProposalCard> createState() => _ReallocationProposalCardState();
}

class _ReallocationProposalCardState extends State<ReallocationProposalCard> {
  bool _isConfirming = false;

  void _applyReallocation() async {
    final reallocs = widget.planData["proposed_reallocations"] as List? ?? [];
    if (reallocs.isEmpty) return;

    final primary = reallocs[0];
    final int goalId = primary["goal_id"] ?? 1;
    final double addition = (primary["proposed_addition"] as num?)?.toDouble() ?? 0.0;
    final Map<String, dynamic> adjustments = Map<String, dynamic>.from(primary["category_adjustments"] ?? {});

    setState(() => _isConfirming = true);
    await ApiService().confirmReallocation(goalId, addition, adjustments);
    setState(() => _isConfirming = false);

    widget.onConfirmed();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.emeraldPrimary,
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF022C22), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Virtual reallocation applied! ₹${addition.toStringAsFixed(0)} added to ${primary['goal_title']}.",
                  style: const TextStyle(color: Color(0xFF022C22), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reallocs = widget.planData["proposed_reallocations"] as List? ?? [];
    if (reallocs.isEmpty) return const SizedBox.shrink();

    final primary = reallocs[0];
    final double addition = (primary["proposed_addition"] as num?)?.toDouble() ?? 0.0;
    final String goalTitle = primary["goal_title"] ?? "Active Goal";
    final String agentMsg = widget.planData["agent_message"] ?? "";
    final Map<String, dynamic> adjustments = Map<String, dynamic>.from(primary["category_adjustments"] ?? {});

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.indigoAccent.withOpacity(0.15),
            AppTheme.purpleAgent.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.indigoAccent.withOpacity(0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.indigoAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                "Autonomous Weekly Re-Planner",
                style: TextStyle(
                  color: AppTheme.indigoAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "Slack Detected",
                  style: TextStyle(color: AppTheme.emeraldPrimary, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            agentMsg,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Adjustments chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...adjustments.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Text(
                    "${e.key}: ₹${e.value.toStringAsFixed(0)}",
                    style: const TextStyle(color: AppTheme.roseDanger, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                );
              }),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.emeraldPrimary.withOpacity(0.4)),
                ),
                child: Text(
                  "$goalTitle: +₹${addition.toStringAsFixed(0)}",
                  style: const TextStyle(color: AppTheme.emeraldPrimary, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action & Guardrail
          Row(
            children: [
              const Expanded(
                child: Text(
                  "🔒 Virtual in-app budget adjustment only. No real money moved.",
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 10.5),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isConfirming ? null : _applyReallocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: _isConfirming
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text(
                        "1-Tap Apply",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF022C22)),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
