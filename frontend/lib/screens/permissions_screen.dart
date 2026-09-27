import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../widgets/glass_card.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const PermissionsScreen({super.key, required this.onCompleted});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('com.fintrack/capture_bridge');

  bool _isSmsGranted = false;
  bool _isNotificationGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    // Check SMS Permission
    final smsStatus = await Permission.sms.status;
    final isSms = smsStatus.isGranted;

    // Check Notification Listener Service Status via MethodChannel
    bool isNotif = false;
    try {
      final bool? notifResult = await _channel.invokeMethod('checkNotificationPermission');
      isNotif = notifResult == true;
    } catch (_) {
      isNotif = false; // Never set to granted in catch block
    }

    if (mounted) {
      setState(() {
        _isSmsGranted = isSms;
        _isNotificationGranted = isNotif;
      });
    }
  }

  Future<void> _requestSmsPermission() async {
    final status = await Permission.sms.request();
    if (mounted) {
      setState(() {
        _isSmsGranted = status.isGranted;
      });
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Permissions"),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Enable Live Auto-Capture",
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "FinTrack operates 100% on-device. It extracts transaction amounts and merchant names without uploading raw SMS messages.",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 20),

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
                                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Detects debit SMS from all Indian banks",
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
                              _isSmsGranted ? "Granted ✓" : "Required",
                              style: TextStyle(
                                color: _isSmsGranted ? AppTheme.tealPrimary : const Color(0xFFB45309),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_isSmsGranted)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _requestSmsPermission,
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text("Allow SMS Permission"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.tealPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
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
                              color: AppTheme.lavenderAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.notifications_active_outlined, color: AppTheme.lavenderDeep, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Notification Listener",
                                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
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
                              _isNotificationGranted ? "Active ✓" : "Pending",
                              style: TextStyle(
                                color: _isNotificationGranted ? AppTheme.tealPrimary : const Color(0xFFB45309),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_isNotificationGranted)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openNotificationSettings,
                            icon: const Icon(Icons.settings, size: 16, color: AppTheme.lavenderDeep),
                            label: const Text("Open System Notification Access", style: TextStyle(color: AppTheme.lavenderDeep, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.lavenderDeep),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
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
                    onPressed: () {
                      StorageService().isPermissionsGranted = true;
                      widget.onCompleted();
                    },
                    child: const Text("Continue to Dashboard →"),
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
