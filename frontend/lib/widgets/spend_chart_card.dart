import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class SpendChartCard extends StatefulWidget {
  final double totalSpend;

  const SpendChartCard({super.key, required this.totalSpend});

  @override
  State<SpendChartCard> createState() => _SpendChartCardState();
}

class _SpendChartCardState extends State<SpendChartCard> {
  String _timeframe = "Daily"; // "Daily", "Weekly", "Monthly"

  // Realistic sample points for each view
  final Map<String, List<Map<String, dynamic>>> _chartData = {
    "Daily": [
      {"label": "Mon", "amount": 420.0, "ratio": 0.35},
      {"label": "Tue", "amount": 1240.0, "ratio": 0.85},
      {"label": "Wed", "amount": 580.0, "ratio": 0.45},
      {"label": "Thu", "amount": 999.0, "ratio": 0.70},
      {"label": "Fri", "amount": 6499.0, "ratio": 1.0},
      {"label": "Sat", "amount": 1500.0, "ratio": 0.60},
      {"label": "Sun", "amount": 890.0, "ratio": 0.50},
    ],
    "Weekly": [
      {"label": "W1 (Sep 1-7)", "amount": 20450.0, "ratio": 0.90},
      {"label": "W2 (Sep 8-14)", "amount": 2659.0, "ratio": 0.35},
      {"label": "W3 (Sep 15-21)", "amount": 8579.0, "ratio": 0.65},
      {"label": "W4 (Sep 22-28)", "amount": 3590.0, "ratio": 0.40},
    ],
    "Monthly": [
      {"label": "Jun", "amount": 32400.0, "ratio": 0.75},
      {"label": "Jul", "amount": 35100.0, "ratio": 0.82},
      {"label": "Aug", "amount": 29800.0, "ratio": 0.70},
      {"label": "Sep (Current)", "amount": 35278.0, "ratio": 0.83},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final points = _chartData[_timeframe]!;

    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Spend Velocity Trend",
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$_timeframe Distribution",
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                  ),
                ],
              ),

              // Daily / Weekly / Monthly Toggle Chips
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: Row(
                  children: ["Daily", "Weekly", "Monthly"].map((tf) {
                    final isSelected = _timeframe == tf;
                    return InkWell(
                      onTap: () => setState(() => _timeframe = tf),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.tealPrimary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tf,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF042F2E) : AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Bar Chart Visualization
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: points.map((p) {
                final double ratio = p["ratio"];
                final String label = p["label"];
                final double amount = p["amount"];
                final isHighlight = ratio > 0.8;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "₹${amount > 999 ? '${(amount / 1000).toStringAsFixed(1)}k' : amount.toStringAsFixed(0)}",
                          style: TextStyle(
                            color: isHighlight ? AppTheme.tealLight : AppTheme.textMuted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: (ratio * 75).clamp(8.0, 75.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isHighlight
                                  ? [AppTheme.tealPrimary, AppTheme.lavenderAccent]
                                  : [AppTheme.tealPrimary.withValues(alpha: 0.5), AppTheme.tealDark.withValues(alpha: 0.3)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
