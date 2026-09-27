import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/categorization_service.dart';

class CategorizeBottomSheet extends StatefulWidget {
  final TransactionModel? transaction;
  final Map<String, dynamic>? extractedData;
  final Function(TransactionModel) onCategorized;

  const CategorizeBottomSheet({
    super.key,
    this.transaction,
    this.extractedData,
    required this.onCategorized,
  });

  static Future<void> show(
    BuildContext context, {
    TransactionModel? transaction,
    Map<String, dynamic>? extractedData,
    required Function(TransactionModel) onCategorized,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategorizeBottomSheet(
        transaction: transaction,
        extractedData: extractedData,
        onCategorized: onCategorized,
      ),
    );
  }

  @override
  State<CategorizeBottomSheet> createState() => _CategorizeBottomSheetState();
}

class _CategorizeBottomSheetState extends State<CategorizeBottomSheet> {
  final TextEditingController _customLabelController = TextEditingController();
  bool _isCustomLabelActive = false;
  String? _selectedCategory;
  String? _selectedP2PReason;

  final List<String> _p2pChips = ["Personal", "Friend", "Rent", "Gift", "Split", "Other"];
  static const List<String> _categories = [
    "Food & Dining",
    "Shopping",
    "Transportation",
    "Bills & Utilities",
    "Entertainment",
    "Healthcare",
    "Housing",
    "Personal",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null && widget.transaction!.category != "Uncategorized") {
      _selectedCategory = widget.transaction!.category;
    }
  }

  @override
  void dispose() {
    _customLabelController.dispose();
    super.dispose();
  }

  void _confirmSelection(String category, {String? note}) async {
    final tx = widget.transaction;
    final extracted = widget.extractedData ?? {};

    final double amount = tx?.amount ?? (extracted['amount'] as num?)?.toDouble() ?? 0.0;
    final String merchant = tx?.merchant ?? extracted['merchant'] ?? 'Unknown Merchant';
    final String rawText = tx?.rawText ?? extracted['raw_text'] ?? '';
    final String source = tx?.source ?? (extracted['is_p2p'] == true ? 'p2p' : 'notification');
    final String date = tx?.date ?? DateTime.now().toIso8601String().substring(0, 10);

    final updatedTx = TransactionModel(
      id: tx?.id,
      uuid: tx?.uuid,
      title: tx?.title.isNotEmpty == true ? tx!.title : merchant,
      amount: amount,
      merchant: merchant,
      rawText: rawText,
      category: category,
      source: source,
      type: tx?.type ?? "expense",
      date: date,
      confidence: 1.0,
      status: "confirmed",
      notes: note ?? tx?.notes,
    );

    // 1. Learn merchant rule (saves locally + syncs to backend)
    await CategorizationService().learnMerchant(merchant, category);

    // 2. If existing transaction, UPDATE it; otherwise add it
    TransactionModel finalTx;
    if (tx != null) {
      finalTx = await ApiService().updateTransaction(updatedTx, previousCategory: tx.category);
    } else {
      finalTx = await ApiService().addTransaction(updatedTx);
    }

    if (mounted) {
      Navigator.of(context).pop();
      widget.onCategorized(finalTx);
    }
  }

  void _skip() async {
    final tx = widget.transaction;
    final extracted = widget.extractedData ?? {};

    final double amount = tx?.amount ?? (extracted['amount'] as num?)?.toDouble() ?? 0.0;
    final String merchant = tx?.merchant ?? extracted['merchant'] ?? 'Unknown Merchant';
    final String rawText = tx?.rawText ?? extracted['raw_text'] ?? '';
    final String source = tx?.source ?? 'notification';
    final String date = tx?.date ?? DateTime.now().toIso8601String().substring(0, 10);

    final skippedTx = TransactionModel(
      id: tx?.id,
      uuid: tx?.uuid,
      title: tx?.title.isNotEmpty == true ? tx!.title : merchant,
      amount: amount,
      merchant: merchant,
      rawText: rawText,
      category: "Uncategorized",
      source: source,
      type: tx?.type ?? "expense",
      date: date,
      confidence: 0.0,
      status: "skipped",
      notes: tx?.notes,
    );

    TransactionModel finalTx;
    if (tx != null) {
      finalTx = await ApiService().updateTransaction(skippedTx);
    } else {
      finalTx = await ApiService().addTransaction(skippedTx);
    }

    if (mounted) {
      Navigator.of(context).pop();
      widget.onCategorized(finalTx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final extracted = widget.extractedData ?? {};
    final double amount = tx?.amount ?? (extracted['amount'] as num?)?.toDouble() ?? 0.0;
    final String merchant = tx?.merchant ?? extracted['merchant'] ?? 'Unknown Merchant';
    final bool isP2P = tx?.source == 'p2p' || extracted['is_p2p'] == true;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF2F7FA), // Soft light solid bottom sheet
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Colors.white, width: 1.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header & Amount Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isP2P ? AppTheme.lavenderAccent.withValues(alpha: 0.25) : AppTheme.amberWarning.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isP2P ? "P2P UPI Transfer" : "Unrecognized Merchant",
                          style: TextStyle(
                            color: isP2P ? AppTheme.lavenderDeep : const Color(0xFFB45309),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Categorize Payment",
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    merchant,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                "₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}",
                style: const TextStyle(
                  color: AppTheme.roseDanger,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Row 1: Quick Chips for P2P / Context
          const Text(
            "What's this for?",
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _p2pChips.map((chip) {
                final isSelected = _selectedP2PReason == chip;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(chip),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedP2PReason = selected ? chip : null;
                        if (chip == "Rent") _selectedCategory = "Housing";
                        if (chip == "Gift") _selectedCategory = "Shopping";
                        if (chip == "Split") _selectedCategory = "Food & Dining";
                        if (chip == "Personal") _selectedCategory = "Personal";
                      });
                    },
                    selectedColor: AppTheme.lavenderAccent,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? AppTheme.lavenderAccent : AppTheme.glassBorder,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 18),

          // Row 2: Standard Categories Grid
          const Text(
            "Select Budget Category",
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                    _isCustomLabelActive = false;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.tealPrimary.withValues(alpha: 0.2) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.tealPrimary : AppTheme.glassBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? AppTheme.tealPrimary : AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (_isCustomLabelActive) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _customLabelController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: "Enter custom category (e.g. Gym, Books, Pets)",
                prefixIcon: Icon(Icons.tag, color: AppTheme.tealPrimary, size: 20),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Actions: Confirm & Learn vs Skip
          Row(
            children: [
              TextButton(
                onPressed: _skip,
                child: const Text(
                  "Skip",
                  style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  String finalCategory = _selectedCategory ?? "Food & Dining";
                  if (_isCustomLabelActive && _customLabelController.text.trim().isNotEmpty) {
                    finalCategory = _customLabelController.text.trim();
                  }
                  _confirmSelection(finalCategory, note: _selectedP2PReason);
                },
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text("Confirm & Remember"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
