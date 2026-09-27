import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'categorize_bottom_sheet.dart';

class NotificationSimulatorDialog extends StatefulWidget {
  final Function(TransactionModel, bool wasAuto) onTransactionProcessed;

  const NotificationSimulatorDialog({
    super.key,
    required this.onTransactionProcessed,
  });

  static void show(
    BuildContext context, {
    required Function(TransactionModel, bool wasAuto) onTransactionProcessed,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => NotificationSimulatorDialog(onTransactionProcessed: onTransactionProcessed),
    );
  }

  @override
  State<NotificationSimulatorDialog> createState() => _NotificationSimulatorDialogState();
}

class _NotificationSimulatorDialogState extends State<NotificationSimulatorDialog> {
  final TextEditingController _customTextController = TextEditingController();
  bool _isLoading = false;

  final List<Map<String, String>> _samplePresets = [
    {
      "app": "PhonePe",
      "text": "Paid Rs. 480.00 at SWIGGY via PhonePe UPI. Txn ID: T2609271104",
      "label": "Swiggy Food (Auto-Tag 100%)",
      "icon": "🍜"
    },
    {
      "app": "Google Pay",
      "text": "Sent Rs. 1,200.00 to Rahul Sharma (9876543210) via GPay UPI.",
      "label": "P2P Transfer to Rahul (Bottom Sheet)",
      "icon": "👤"
    },
    {
      "app": "SMS",
      "text": "HDFC Bank Alert: Rs 2,450.00 debited from A/C **1234 towards BESCOM on 27-SEP-26.",
      "label": "BESCOM Electricity (Auto-Tag 100%)",
      "icon": "⚡"
    },
    {
      "app": "Paytm",
      "text": "Paid Rs 85.00 to Ramesh Chai & Snacks at HSR Layout via Paytm.",
      "label": "Local Chai Vendor (Ollama / Popup)",
      "icon": "☕"
    },
  ];

  @override
  void dispose() {
    _customTextController.dispose();
    super.dispose();
  }

  void _simulateCapture(String rawText, String app) async {
    setState(() => _isLoading = true);

    final res = await ApiService().parseNotification(rawText, sourceApp: app);
    setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.of(context).pop();

    final catData = res["categorization"] ?? {};
    final bool needsConfirmation = catData["needs_user_confirmation"] == true;
    final extracted = res["extracted"] ?? {};

    if (needsConfirmation) {
      // Trigger native Bottom-Sheet flow
      CategorizeBottomSheet.show(
        context,
        extractedData: extracted,
        onCategorized: (tx) {
          widget.onTransactionProcessed(tx, false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.surfaceElevated,
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.emeraldPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text("Saved to ${tx.category} & learned in dictionary!"),
                ],
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } else {
      // Auto-tag silently with toast
      final tx = res["transaction"] != null
          ? TransactionModel.fromJson(res["transaction"])
          : TransactionModel(
              title: extracted["merchant"] ?? "Merchant",
              amount: (extracted["amount"] as num?)?.toDouble() ?? 0.0,
              merchant: extracted["merchant"] ?? "",
              rawText: rawText,
              category: catData["category"] ?? "Food & Dining",
              source: app,
              type: "expense",
              date: DateTime.now().toIso8601String().substring(0, 10),
              confidence: (catData["confidence"] as num?)?.toDouble() ?? 1.0,
              status: "auto",
            );

      widget.onTransactionProcessed(tx, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surfaceElevated,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              const Icon(Icons.bolt, color: AppTheme.cyanTech, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Auto-categorized ₹${tx.amount.toStringAsFixed(0)} as ${tx.category} (${((tx.confidence) * 100).toStringAsFixed(0)}% conf)",
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: "Edit",
            textColor: AppTheme.indigoAccent,
            onPressed: () {
              CategorizeBottomSheet.show(
                context,
                extractedData: extracted,
                onCategorized: (edited) => widget.onTransactionProcessed(edited, false),
              );
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.surfaceBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.cyanTech.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active, color: AppTheme.cyanTech, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Simulate Native Capture",
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      "Test PhonePe / GPay / SMS listeners",
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Select a realistic test payload:",
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: AppTheme.cyanTech),
                ),
              )
            else ...[
              ..._samplePresets.map((preset) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () => _simulateCapture(preset["text"]!, preset["app"]!),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          Text(preset["icon"]!, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.indigoAccent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        preset["app"]!,
                                        style: const TextStyle(
                                          color: AppTheme.indigoAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        preset["label"]!,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  preset["text"]!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 12),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              TextField(
                controller: _customTextController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Or paste custom SMS / notification text...",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: AppTheme.cyanTech, size: 20),
                    onPressed: () {
                      if (_customTextController.text.trim().isNotEmpty) {
                        _simulateCapture(_customTextController.text.trim(), "SMS");
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
