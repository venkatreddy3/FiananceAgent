import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/categorization_service.dart';
import '../services/api_service.dart';
import 'glass_card.dart';

class UncategorizedTransactionCard extends StatefulWidget {
  final TransactionModel transaction;
  final Function(TransactionModel resolved) onResolved;

  const UncategorizedTransactionCard({
    super.key,
    required this.transaction,
    required this.onResolved,
  });

  @override
  State<UncategorizedTransactionCard> createState() => _UncategorizedTransactionCardState();
}

class _UncategorizedTransactionCardState extends State<UncategorizedTransactionCard> {
  bool _isExpanded = false;
  String? _selectedP2PChip;
  String? _selectedCategory;
  final TextEditingController _otherController = TextEditingController();
  bool _isOtherActive = false;

  final List<String> _quickChips = ["Personal", "Friend", "Rent", "Gift", "Split", "Other"];
  final List<String> _categories = [
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
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _resolve(String category, {String? note}) async {
    final tx = widget.transaction;
    final updatedTx = TransactionModel(
      id: tx.id,
      title: tx.title,
      amount: tx.amount,
      merchant: tx.merchant,
      rawText: tx.rawText,
      category: category,
      source: tx.source,
      type: tx.type,
      date: tx.date,
      confidence: 1.0,
      status: "confirmed",
      notes: note ?? _selectedP2PChip,
    );

    // Learn mapping in dictionary
    CategorizationService().learnMerchant(tx.merchant, category);
    await ApiService().addTransaction(updatedTx);
    await ApiService().learnMerchantMapping(tx.merchant, category);

    widget.onResolved(updatedTx);
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderColor: AppTheme.lavenderAccent.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsed Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.lavenderAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.help_outline, color: AppTheme.lavenderAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.merchant.isNotEmpty ? tx.merchant : tx.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            tx.date,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.amberWarning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Needs Category",
                              style: TextStyle(color: AppTheme.amberWarning, fontSize: 9.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  "₹${tx.amount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: AppTheme.roseDanger,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),

          // Expanded Categorization Controls
          if (_isExpanded) ...[
            const SizedBox(height: 14),
            const Divider(color: AppTheme.glassBorder),
            const SizedBox(height: 8),
            const Text(
              "What's this for?",
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // Quick-pick chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickChips.map((chip) {
                  final isSelected = _selectedP2PChip == chip;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(chip),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedP2PChip = selected ? chip : null;
                          if (chip == "Rent") _selectedCategory = "Housing";
                          if (chip == "Gift") _selectedCategory = "Shopping";
                          if (chip == "Personal") _selectedCategory = "Personal";
                        });
                      },
                      selectedColor: AppTheme.lavenderAccent,
                      backgroundColor: const Color(0x1FFFFFFF),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : AppTheme.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              "Category Envelope",
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // Scrolling row of categories
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat;
                            _isOtherActive = false;
                          });
                          _resolve(cat);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.tealPrimary.withValues(alpha: 0.25) : const Color(0x1FFFFFFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppTheme.tealPrimary : AppTheme.glassBorder,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? AppTheme.tealPrimary : AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      label: const Text("Other +"),
                      backgroundColor: const Color(0x1FFFFFFF),
                      onPressed: () => setState(() => _isOtherActive = true),
                    ),
                  ),
                ],
              ),
            ),

            if (_isOtherActive) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _otherController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Enter custom label (e.g. Gym, Books)...",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check, color: AppTheme.tealPrimary),
                    onPressed: () {
                      if (_otherController.text.trim().isNotEmpty) {
                        _resolve(_otherController.text.trim());
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
