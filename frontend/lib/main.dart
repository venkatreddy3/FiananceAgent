import 'dart:ui';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/ai_agents_hub_screen.dart';
import 'services/transaction_capture_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize native capture listeners and drain queue
  TransactionCaptureService().initialize();
  runApp(const FinTrackApp());
}

class FinTrackApp extends StatelessWidget {
  const FinTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinTrack — Effortless Local Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.softGlassTheme,
      home: const AppEntryRouter(),
    );
  }
}

class AppEntryRouter extends StatefulWidget {
  const AppEntryRouter({super.key});

  @override
  State<AppEntryRouter> createState() => _AppEntryRouterState();
}

class _AppEntryRouterState extends State<AppEntryRouter> {
  bool _isOnboarded = true; // Set to true by default for immediate dev usage or toggle

  @override
  Widget build(BuildContext context) {
    if (!_isOnboarded) {
      return OnboardingScreen(onFinish: () => setState(() => _isOnboarded = true));
    }
    return const MainNavigationShell();
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  void _onNavigateTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(onNavigateTab: _onNavigateTab),
      const BudgetScreen(),
      const GoalsScreen(),
      const TransactionsScreen(),
      const AIAgentsHubScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildFloatingPillNavBar(),
    );
  }

  // Floating Pill-Shaped Glassmorphic Bottom Navigation Bar
  Widget _buildFloatingPillNavBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xB3131B2E), // 70% opacity dark surface
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppTheme.glassBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.dashboard_outlined, Icons.dashboard, "Home", 0),
                  _buildNavItem(Icons.pie_chart_outline, Icons.pie_chart, "Budget", 1),
                  _buildNavItem(Icons.flag_outlined, Icons.flag, "Goals", 2),
                  _buildNavItem(Icons.receipt_long_outlined, Icons.receipt_long, "Ledger", 3),
                  _buildNavItem(Icons.auto_awesome_outlined, Icons.auto_awesome, "AI Council", 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData outlineIcon, IconData filledIcon, String label, int index) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.tealPrimary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlineIcon,
              color: isSelected ? AppTheme.tealPrimary : AppTheme.textMuted,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.tealPrimary : AppTheme.textMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
