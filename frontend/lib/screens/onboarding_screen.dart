import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'permissions_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Page 2: Persona & Spend
  String _selectedPersona = "Salaried";
  double _monthlySpend = 45000.0;

  // Page 3: Categories
  final Set<String> _selectedCategories = {
    "Food & Dining",
    "Housing",
    "Transportation",
    "Bills & Utilities",
    "Shopping",
  };

  final List<Map<String, String>> _personas = [
    {"title": "Salaried", "desc": "Fixed monthly paycheck & recurring bills", "icon": "💼"},
    {"title": "Freelancer", "desc": "Variable income & flexible spending", "icon": "💻"},
    {"title": "Student", "desc": "Pocket allowance & tight budgets", "icon": "🎓"},
  ];

  final List<String> _availableCategories = [
    "Food & Dining",
    "Housing",
    "Transportation",
    "Bills & Utilities",
    "Shopping",
    "Entertainment",
    "Healthcare",
    "Personal & Grooming",
    "Investments",
  ];

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => PermissionsScreen(onCompleted: widget.onFinish),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Header progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(3, (index) {
                        final isActive = _currentPage == index;
                        final isDone = _currentPage > index;
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: isActive ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.tealPrimary
                                : (isDone ? AppTheme.lavenderAccent : AppTheme.glassBorder),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    if (_currentPage < 2)
                      TextButton(
                        onPressed: () => _pageController.jumpToPage(2),
                        child: const Text("Skip", style: TextStyle(color: AppTheme.textMuted)),
                      ),
                  ],
                ),
              ),

              // Page Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  children: [
                    _buildAuthPage(),
                    _buildPersonaAndSpendPage(),
                    _buildCategorySelectionPage(),
                  ],
                ),
              ),

              // Bottom Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.tealPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _currentPage == 2 ? "Configure Permissions →" : "Continue",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF042F2E),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Page 1: Auth Options ---
  Widget _buildAuthPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.tealPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.3)),
            ),
            child: const Text(
              "Minimal, Effortless Budgeting",
              style: TextStyle(color: AppTheme.tealPrimary, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "FinTrack AI",
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Zero manual bookkeeping. Automatically tracks PhonePe, GPay, Paytm, and bank SMS via local intelligence.",
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.5, height: 1.45),
          ),
          const Spacer(),

          // Google Sign In
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            margin: const EdgeInsets.only(bottom: 12),
            onTap: _nextPage,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text(
                  "Continue with Google",
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          // Phone OTP Sign In
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            margin: const EdgeInsets.only(bottom: 12),
            onTap: _nextPage,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_android, color: AppTheme.lavenderAccent, size: 20),
                SizedBox(width: 10),
                Text(
                  "Sign In with Phone OTP",
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          // Guest Mode
          Center(
            child: TextButton(
              onPressed: _nextPage,
              child: const Text(
                "Continue without an account (Offline-First)",
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13, decoration: TextDecoration.underline),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- Page 2: Persona & Spend ---
  Widget _buildPersonaAndSpendPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            "Tell us about yourself",
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "This helps the AI agent calibrate baseline category caps.",
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),

          ..._personas.map((p) {
            final isSelected = _selectedPersona == p["title"];
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              borderColor: isSelected ? AppTheme.tealPrimary : null,
              backgroundColor: isSelected ? AppTheme.tealPrimary.withValues(alpha: 0.12) : null,
              onTap: () => setState(() => _selectedPersona = p["title"]!),
              child: Row(
                children: [
                  Text(p["icon"]!, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p["title"]!,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          p["desc"]!,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppTheme.tealPrimary, size: 20),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Estimated Monthly Spend",
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              Text(
                "₹${_monthlySpend.toStringAsFixed(0)}",
                style: const TextStyle(
                  color: AppTheme.tealPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _monthlySpend,
            min: 10000,
            max: 200000,
            divisions: 38,
            activeColor: AppTheme.tealPrimary,
            inactiveColor: AppTheme.glassBorder,
            onChanged: (val) => setState(() => _monthlySpend = val),
          ),
        ],
      ),
    );
  }

  // --- Page 3: Suggested Categories ---
  Widget _buildCategorySelectionPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            "Select your spend categories",
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "FinTrack auto-allocates your monthly cap into these envelopes.",
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _availableCategories.map((cat) {
                  final isSelected = _selectedCategories.contains(cat);
                  return FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategories.add(cat);
                        } else {
                          _selectedCategories.remove(cat);
                        }
                      });
                    },
                    selectedColor: AppTheme.tealPrimary.withValues(alpha: 0.2),
                    backgroundColor: AppTheme.glassSurface,
                    checkmarkColor: AppTheme.tealPrimary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.tealPrimary : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected ? AppTheme.tealPrimary : AppTheme.glassBorder,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
