import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'models/models.dart';
import 'screens/onboarding_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/ai_agents_hub_screen.dart';
import 'services/storage_service.dart';
import 'services/transaction_capture_service.dart';
import 'widgets/categorize_bottom_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
  ));

  // Initialize Hive local persistence
  await StorageService().initialize();

  // Initialize native capture listeners
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
  @override
  Widget build(BuildContext context) {
    if (!StorageService().isOnboarded) {
      return OnboardingScreen(
        onFinish: () {
          setState(() {
            StorageService().isOnboarded = true;
          });
        },
      );
    }

    if (!StorageService().isPermissionsGranted) {
      return PermissionsScreen(
        onCompleted: () {
          setState(() {
            StorageService().isPermissionsGranted = true;
          });
        },
      );
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
  StreamSubscription<TransactionModel>? _captureSub;

  @override
  void initState() {
    super.initState();
    _captureSub = TransactionCaptureService().onTransactionCaptured.listen((tx) {
      if (mounted) {
        final isP2P = tx.source == 'p2p';
        final isLowConf = tx.confidence < 0.85 || tx.category == 'Uncategorized';
        if (isP2P || isLowConf) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF333333),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 90),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Text(
                "New ₹${tx.amount.toStringAsFixed(0)} to ${tx.merchant} - tap to categorize",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              action: SnackBarAction(
                label: "Categorize",
                textColor: AppTheme.tealLight,
                onPressed: () {
                  CategorizeBottomSheet.show(
                    context,
                    transaction: tx,
                    onCategorized: (_) {
                      setState(() {});
                    },
                  );
                },
              ),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _captureSub?.cancel();
    super.dispose();
  }

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
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xCCFFFFFF), // 80% white background
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.tealPrimary.withValues(alpha: 0.15) : Colors.transparent,
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
