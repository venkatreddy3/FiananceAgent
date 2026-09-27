import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const PermissionsScreen({super.key, required this.onCompleted});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  static const MethodChannel _channel = MethodChannel('com.fintrack/capture_bridge');

  bool _isSmsGranted = true;
  bool _isNotificationGranted = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final bool? notif = await _channel.invokeMethod('checkNotificationPermission');
      if (mounted && notif != null) {
        setState(() => _isNotificationGranted = notif);
      }
    } catch (_) {}
  }

  Future<void> _openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
      // Recheck when user returns
      Future.delayed(const Duration(seconds: 2), _checkPermissions);
    } catch (_) {
      setState(() => _isNotificationGranted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Capture Permissions"),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Enable Real-Time Capture",
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "FinTrack operates on-device to pick up bank SMS and payment app notifications without uploading personal texts.",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 24),

                // SMS Permission Card
                GlassCard(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.sms_outlined, color: AppTheme.tealPrimary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Bank SMS Reader",
                                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "HDFC, SBI, ICICI, Axis, Kotak alerts",
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isSmsGranted ? AppTheme.tealPrimary.withValues(alpha: 0.2) : AppTheme.amberWarning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _isSmsGranted ? "Granted" : "Pending",
                              style: TextStyle(
                                color: _isSmsGranted ? AppTheme.tealPrimary : AppTheme.amberWarning,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "• Automatically filters out OTPs and non-financial messages.\n• 100% processed locally on Android.",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),

                // Notification Access Card
                GlassCard(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.lavenderAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.notifications_active_outlined, color: AppTheme.lavenderAccent, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Notification Listener",
                                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "PhonePe, Google Pay, Paytm, CRED",
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isNotificationGranted ? AppTheme.tealPrimary.withValues(alpha: 0.2) : AppTheme.amberWarning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _isNotificationGranted ? "Active" : "Enable in Settings",
                              style: TextStyle(
                                color: _isNotificationGranted ? AppTheme.tealPrimary : AppTheme.amberWarning,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (!_isNotificationGranted)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openNotificationSettings,
                            icon: const Icon(Icons.settings, size: 16, color: AppTheme.lavenderAccent),
                            label: const Text("Open Android Notification Access Settings", style: TextStyle(color: AppTheme.lavenderAccent)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.lavenderAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onCompleted,
                    child: const Text("Go to Financial Dashboard →"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
