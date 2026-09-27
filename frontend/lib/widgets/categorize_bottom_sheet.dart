import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class CategorizeBottomSheet extends StatefulWidget {
  final Map<String, dynamic> extractedData;
  final Function(TransactionModel) onCategorized;

  const CategorizeBottomSheet({
    super.key,
    required this.extractedData,
    required this.onCategorized,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> extractedData,
    required Function(TransactionModel) onCategorized,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategorizeBottomSheet(
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
  final List<String> _categories = [
    "Food & Dining",
    "Shopping",
    "Transportation",
    "Bills & Utilities",
    "Entertainment",
    "Healthcare",
    "Housing",
    "Other",
  ];

  @override
  void dispose() {
    _customLabelController.dispose();
    super.dispose();
  }

  void _confirmSelection(String category, {String? note}) async {
    final extracted = widget.extractedData;
    final double amount = (extracted['amount'] as num?)?.toDouble() ?? 0.0;
    final String merchant = extracted['merchant'] ?? 'Unknown Merchant';
    final String rawText = extracted['raw_text'] ?? '';
    final String source = extracted['is_p2p'] == true ? 'p2p' : 'notification';

    final newTx = TransactionModel(
      title: merchant,
      amount: amount,
      merchant: merchant,
      rawText: rawText,
      category: category,
      source: source,
      type: "expense",
      date: DateTime.now().toIso8601String().substring(0, 10),
      confidence: 1.0,
      status: "confirmed",
      notes: note,
    );

    // Save transaction via ApiService
    await ApiService().addTransaction(newTx);
    // Learn mapping in dictionary
    await ApiService().learnMerchantMapping(merchant, category);

    if (mounted) {
      Navigator.of(context).pop();
      widget.onCategorized(newTx);
    }
  }

  void _skip() {
    final extracted = widget.extractedData;
    final double amount = (extracted['amount'] as num?)?.toDouble() ?? 0.0;
    final String merchant = extracted['merchant'] ?? 'Unknown Merchant';

    final newTx = TransactionModel(
      title: merchant,
      amount: amount,
      merchant: merchant,
      category: "Uncategorized",
      source: "notification",
      type: "expense",
      date: DateTime.now().toIso8601String().substring(0, 10),
      confidence: 0.0,
      status: "skipped",
    );

    ApiService().addTransaction(newTx);
    Navigator.of(context).pop();
    widget.onCategorized(newTx);
  }

  @override
  Widget build(BuildContext context) {
    final extracted = widget.extractedData;
    final double amount = (extracted['amount'] as num?)?.toDouble() ?? 0.0;
    final String merchant = extracted['merchant'] ?? 'Unknown Merchant';
    final bool isP2P = extracted['is_p2p'] == true;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppTheme.surfaceBorder, width: 1.5),
          left: BorderSide(color: AppTheme.surfaceBorder, width: 1),
          right: BorderSide(color: AppTheme.surfaceBorder, width: 1),
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
                color: AppTheme.surfaceBorder,
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
                          color: isP2P ? AppTheme.purpleAgent.withOpacity(0.2) : AppTheme.amberWarning.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isP2P ? "P2P UPI Transfer" : "Unrecognized Merchant",
                          style: TextStyle(
                            color: isP2P ? AppTheme.purpleAgent : AppTheme.amberWarning,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                "₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}",
                style: const TextStyle(
                  color: AppTheme.roseDanger,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
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
                      });
                    },
                    selectedColor: AppTheme.indigoAccent,
                    backgroundColor: AppTheme.surfaceElevated,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppTheme.indigoAccent : AppTheme.surfaceBorder,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 18),

          // Row 2: Standard Categories Grid / Wrap
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
                  if (cat == "Other") {
                    setState(() {
                      _isCustomLabelActive = true;
                      _selectedCategory = "Other";
                    });
                  } else {
                    setState(() {
                      _selectedCategory = cat;
                      _isCustomLabelActive = false;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.emeraldPrimary.withOpacity(0.2) : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppTheme.emeraldPrimary : AppTheme.surfaceBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? AppTheme.emeraldPrimary : AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
                prefixIcon: Icon(Icons.tag, color: AppTheme.emeraldPrimary, size: 20),
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
