import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  Map<String, dynamic>? _healthInfo;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = ApiService().baseUrl;
    _runHealthCheck();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _runHealthCheck() async {
    setState(() => _isChecking = true);
    final health = await ApiService().checkHealth();
    if (mounted) {
      setState(() {
        _healthInfo = health;
        _isChecking = false;
      });
    }
  }

  void _saveUrl() {
    final newUrl = _urlController.text.trim();
    if (newUrl.isNotEmpty) {
      ApiService().baseUrl = newUrl;
      _runHealthCheck();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Backend URL updated to: $newUrl"),
          backgroundColor: AppTheme.emeraldPrimary,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings & Engine"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isConnected ? AppTheme.emeraldPrimary.withOpacity(0.4) : AppTheme.surfaceBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isConnected ? Icons.cloud_done : Icons.cloud_off,
                      color: isConnected ? AppTheme.emeraldPrimary : AppTheme.amberWarning,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isConnected ? "Backend Connected (Port 8000)" : "Offline / Fallback Mode",
                      style: TextStyle(
                        color: isConnected ? AppTheme.emeraldPrimary : AppTheme.amberWarning,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    if (_isChecking)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
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
                        color: isOllamaConnected ? AppTheme.cyanTech : AppTheme.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOllamaConnected
                          ? "Ollama Daemon Active (${models.isNotEmpty ? models.join(', ') : 'llama3.2'})"
                          : "Ollama: Simulation & Fallback Mode",
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Backend URL Configuration
          const Text(
            "Backend Gateway Endpoint",
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: "http://localhost:8000",
                    prefixIcon: Icon(Icons.link, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveUrl,
                child: const Text("Save"),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Use 'http://10.0.2.2:8000' if testing on Android Emulator, or 'http://localhost:8000' on Web/Desktop.",
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),

          const SizedBox(height: 24),

          // Architecture Specs & Security Guarantee
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline, color: AppTheme.emeraldPrimary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Local Compute & Privacy Architecture",
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  "• 100% Offline-First: All transactions, budgets, and savings goals are persisted locally.\n"
                  "• Confidence Gating: Known merchants are resolved locally without cloud roundtrips.\n"
                  "• Deterministic Math: Reallocation calculus and slack detection run purely mathematically.\n"
                  "• Safety Gate: The AI proposes virtual adjustments; you always retain 1-tap confirmation authority.",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
