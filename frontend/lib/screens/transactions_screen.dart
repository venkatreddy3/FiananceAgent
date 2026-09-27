import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/transaction_capture_service.dart';
import '../widgets/glass_card.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<TransactionModel> _transactions = [];
  String _selectedCategory = "All";
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  final List<String> _categories = [
    "All",
    "Food & Dining",
    "Shopping",
    "Transportation",
    "Bills & Utilities",
    "Entertainment",
    "Healthcare",
    "Housing",
    "Personal",
    "Income",
    "P2P Transfer",
    "Uncategorized",
  ];

  StreamSubscription? _captureSub;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _captureSub = TransactionCaptureService().onTransactionCaptured.listen((_) {
      if (mounted) _loadTransactions();
    });
  }

  @override
  void dispose() {
    _captureSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final data = await ApiService().getTransactions();
    if (mounted) {
      setState(() {
        _transactions = data;
        _isLoading = false;
      });
    }
  }

  void _showAddTransactionDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final merchantController = TextEditingController();
    String category = "Food & Dining";
    String type = "expense";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFF0F5F8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.glassBorder),
          ),
          title: const Text("Add Transaction", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("Expense"),
                        selected: type == "expense",
                        onSelected: (s) => setDialogState(() => type = "expense"),
                        selectedColor: AppTheme.roseDanger.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: type == "expense" ? AppTheme.roseDanger : AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("Income"),
                        selected: type == "income",
                        onSelected: (s) => setDialogState(() => type = "income"),
                        selectedColor: AppTheme.tealPrimary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: type == "income" ? AppTheme.tealPrimary : AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "Description (e.g. Swiggy Lunch)"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Amount (₹)", prefixText: "₹ "),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: merchantController,
                  decoration: const InputDecoration(labelText: "Merchant / Contact"),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: const Color(0xFFF0F5F8),
                  decoration: const InputDecoration(labelText: "Category"),
                  items: _categories.where((c) => c != "All").map((c) {
                    return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: AppTheme.textPrimary)));
                  }).toList(),
                  onChanged: (val) => setDialogState(() => category = val ?? "Food & Dining"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                final merchant = merchantController.text.trim().isNotEmpty ? merchantController.text.trim() : title;

                if (title.isNotEmpty && amount > 0) {
                  final newTx = TransactionModel(
                    title: title,
                    amount: amount,
                    merchant: merchant,
                    category: category,
                    type: type,
                    date: DateTime.now().toIso8601String().substring(0, 10),
                    confidence: 1.0,
                    status: "confirmed",
                    source: "manual",
                  );
                  _transactions.insert(0, newTx);
                  Navigator.pop(ctx);
                  setState(() {});
                  ApiService().addTransaction(newTx);
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
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

    final query = _searchController.text.toLowerCase();
    final filtered = _transactions.where((t) {
      final matchesCat = _selectedCategory == "All" || t.category == _selectedCategory;
      final matchesSearch = query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          t.merchant.toLowerCase().contains(query) ||
          t.category.toLowerCase().contains(query);
      return matchesCat && matchesSearch;
    }).toList();

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Transactions Ledger"),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: AppTheme.tealPrimary),
              tooltip: "Manual Entry",
              onPressed: _showAddTransactionDialog,
            ),
          ],
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "Search transactions, merchants...",
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategory = cat);
                      },
                      selectedColor: AppTheme.tealPrimary,
                      backgroundColor: AppTheme.glassSurface,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? AppTheme.tealPrimary : AppTheme.glassBorder,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 6),

            // Transaction List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadTransactions,
                color: AppTheme.tealPrimary,
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          "No transactions found",
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, index) {
                          final tx = filtered[index];
                          final isExpense = tx.type == "expense";

                          return Dismissible(
                            key: Key("${tx.id ?? index}"),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppTheme.roseDanger.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete, color: AppTheme.roseDanger),
                            ),
                            onDismissed: (_) {
                              if (tx.id != null) ApiService().deleteTransaction(tx.id!);
                              _transactions.remove(tx);
                            },
                            child: GlassCard(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isExpense
                                          ? AppTheme.lavenderAccent.withValues(alpha: 0.15)
                                          : AppTheme.tealPrimary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isExpense ? Icons.receipt_long_outlined : Icons.payments_outlined,
                                      color: isExpense ? AppTheme.lavenderDeep : AppTheme.tealPrimary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.title,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              "${tx.date} • ${tx.category}",
                                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                                            ),
                                            const SizedBox(width: 6),
                                            if (tx.source == "sms" || tx.source == "notification")
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  tx.source.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: AppTheme.tealPrimary,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "${isExpense ? '-' : '+'}₹${tx.amount.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      color: isExpense ? AppTheme.textPrimary : AppTheme.tealPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
