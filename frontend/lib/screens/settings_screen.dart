import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/notification_simulator_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  Map<String, dynamic>? _healthInfo;
  bool _isChecking = false;
  String? _testResultStatus;

  @override
  void initState() {
    super.initState();
    _urlController.text = StorageService().baseUrl;
    _apiKeyController.text = StorageService().apiKey;
    _runHealthCheck();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _runHealthCheck() async {
    setState(() {
      _isChecking = true;
      _testResultStatus = null;
    });
    final health = await ApiService().checkHealth();
    if (mounted) {
      setState(() {
        _healthInfo = health;
        _isChecking = false;
        _testResultStatus = health["status"] == "healthy" ? "Connected successfully! ⚡" : "Connection failed (Offline)";
      });
    }
  }

  void _saveSettings() {
    final newUrl = _urlController.text.trim();
    final newKey = _apiKeyController.text.trim();
    if (newUrl.isNotEmpty) {
      StorageService().baseUrl = newUrl;
      StorageService().apiKey = newKey;
      _runHealthCheck();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Settings saved: $newUrl"),
          backgroundColor: AppTheme.tealPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _healthInfo?["status"] == "healthy";
    final isOllamaConnected = _healthInfo?["ollama_connected"] == true;
    final List models = _healthInfo?["available_models"] ?? [];

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Settings & Engine"),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          children: [
            // Connection Status Card
            GlassCard(
              padding: const EdgeInsets.all(18),
              borderColor: isConnected ? AppTheme.tealPrimary.withValues(alpha: 0.5) : AppTheme.amberWarning.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isConnected ? Icons.cloud_done : Icons.cloud_off,
                        color: isConnected ? AppTheme.tealPrimary : AppTheme.amberWarning,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isConnected ? "Backend Gateway Connected" : "Offline / Local Mode",
                        style: TextStyle(
                          color: isConnected ? AppTheme.tealPrimary : AppTheme.amberWarning,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      if (_isChecking)
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.tealPrimary))
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18, color: AppTheme.textMuted),
                          onPressed: _runHealthCheck,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOllamaConnected ? AppTheme.tealPrimary : AppTheme.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOllamaConnected
                            ? "Ollama Daemon Active (${models.isNotEmpty ? models.join(', ') : 'llama3.2'})"
                            : "Ollama: Simulation & Offline Fallback",
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  if (_testResultStatus != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _testResultStatus!,
                      style: TextStyle(
                        color: isConnected ? AppTheme.tealPrimary : AppTheme.roseDanger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Backend URL Configuration
            const Text(
              "Backend Gateway Endpoint",
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
              decoration: const InputDecoration(
                labelText: "Base URL",
                hintText: "http://10.0.2.2:8000",
                prefixIcon: Icon(Icons.link, size: 18, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
              decoration: const InputDecoration(
                labelText: "API Token (X-API-Key)",
                hintText: "fintrack_secret_key",
                prefixIcon: Icon(Icons.key, size: 18, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isChecking ? null : _runHealthCheck,
                    icon: const Icon(Icons.network_check, size: 16, color: AppTheme.tealPrimary),
                    label: const Text("Test Connection", style: TextStyle(color: AppTheme.tealPrimary, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.tealPrimary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text("Save Settings"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Default: http://10.0.2.2:8000 on Android Emulator, http://localhost:8000 on Web/Desktop.",
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),

            const SizedBox(height: 20),

            // Debug-only Simulator
            if (kDebugMode) ...[
              const Text(
                "Developer Testing Tools",
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.developer_mode, color: AppTheme.lavenderDeep, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Notification & SMS Simulator", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textPrimary)),
                          Text("Simulate PhonePe, GPay, and Bank SMS", style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        NotificationSimulatorDialog.show(
                          context,
                          onTransactionProcessed: (tx, wasAuto) {},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.lavenderDeep,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text("Launch", style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Architecture Specs & Security Guarantee
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline, color: AppTheme.tealPrimary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Local Compute & Privacy Architecture",
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    "• 100% Offline-First: All transactions, budgets, and savings goals are persisted locally via Hive.\n"
                    "• Confidence Gating: Known merchants are resolved locally without cloud roundtrips.\n"
                    "• Deterministic Math: Reallocation calculus and slack detection run purely mathematically.\n"
                    "• Safety Gate: The AI proposes virtual adjustments; you always retain 1-tap confirmation authority.",
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
