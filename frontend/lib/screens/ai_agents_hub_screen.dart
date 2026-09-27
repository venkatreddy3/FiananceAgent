import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class AIAgentsHubScreen extends StatefulWidget {
  const AIAgentsHubScreen({super.key});

  @override
  State<AIAgentsHubScreen> createState() => _AIAgentsHubScreenState();
}

class _AIAgentsHubScreenState extends State<AIAgentsHubScreen> {
  String _activeAgent = "auditor"; // "auditor", "advisor", "strategist"
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  final List<Map<String, dynamic>> _messages = [
    {
      "role": "assistant",
      "agent": "auditor",
      "content": "👋 Hello! I am your **FinTrack Forensic Expense Auditor**.\n\nI continuously monitor your UPI transactions for spending velocity spikes, subscription leakage, and category anomalies.\n\nAsk me to review your monthly burn rate or highlight recent spikes!",
    }
  ];

  final Map<String, Map<String, dynamic>> _agentProfiles = {
    "auditor": {
      "title": "Expense Auditor",
      "icon": Icons.search,
      "color": AppTheme.cyanTech,
      "badge": "Forensic Ledger",
      "intro": "👋 Switched to **Forensic Expense Auditor**.\n\nI can analyze your spending spikes, detect recurring subscription leakage, and identify category surges.",
      "quickPrompts": [
        "Audit my recent spending spikes",
        "Check my recurring subscriptions",
        "What is my highest burn category?",
      ],
    },
    "advisor": {
      "title": "Budget Advisor",
      "icon": Icons.pie_chart_outline,
      "color": AppTheme.amberWarning,
      "badge": "50/30/20 Framework",
      "intro": "📊 Switched to **50/30/20 Budget Advisor**.\n\nI evaluate your living costs (Needs), lifestyle expenses (Wants), and monthly savings pace.",
      "quickPrompts": [
        "How is my 50/30/20 split this month?",
        "What is my remaining daily allowance?",
        "Which category is closest to overrun?",
      ],
    },
    "strategist": {
      "title": "Wealth Strategist",
      "icon": Icons.auto_awesome,
      "color": AppTheme.purpleAgent,
      "badge": "Goal Accelerator",
      "intro": "💎 Switched to **Wealth & Goal Strategist**.\n\nI can project your laptop & emergency fund completion dates and formulate weekly surplus reallocations.",
      "quickPrompts": [
        "When will I reach my MacBook goal?",
        "How can I accelerate my emergency fund?",
        "Suggest a surplus reallocation plan",
      ],
    },
  };

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _switchAgent(String agentKey) {
    if (_activeAgent == agentKey) return;
    setState(() {
      _activeAgent = agentKey;
      final profile = _agentProfiles[agentKey]!;
      _messages.add({
        "role": "assistant",
        "agent": agentKey,
        "content": profile["intro"],
      });
    });
    _scrollToBottom();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    final userMsg = text.trim();
    _messageController.clear();

    setState(() {
      _messages.add({"role": "user", "content": userMsg});
      _isSending = true;
    });
    _scrollToBottom();

    final res = await ApiService().chatWithAgent(_activeAgent, userMsg);

    if (mounted) {
      setState(() {
        _messages.add({
          "role": "assistant",
          "agent": _activeAgent,
          "content": res["response"] ?? "No response received.",
          "model": res["model_used"],
        });
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = _agentProfiles[_activeAgent]!;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (currentProfile["color"] as Color).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(currentProfile["icon"] as IconData, color: currentProfile["color"] as Color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(currentProfile["title"] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(currentProfile["badge"] as String, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Agent Selector Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.surfaceBorder)),
            ),
            child: Row(
              children: _agentProfiles.entries.map((entry) {
                final isSelected = _activeAgent == entry.key;
                final color = entry.value["color"] as Color;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: InkWell(
                      onTap: () => _switchAgent(entry.key),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withOpacity(0.15) : AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? color : AppTheme.surfaceBorder,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              entry.value["icon"] as IconData,
                              size: 16,
                              color: isSelected ? color : AppTheme.textMuted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.value["title"] as String,
                              style: TextStyle(
                                color: isSelected ? color : AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, index) {
                final msg = _messages[index];
                final isUser = msg["role"] == "user";
                final agent = msg["agent"] ?? _activeAgent;
                final agentColor = (_agentProfiles[agent]?["color"] as Color?) ?? AppTheme.indigoAccent;

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser ? AppTheme.indigoAccent : AppTheme.surface,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                        bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
                      ),
                      border: Border.all(
                        color: isUser ? AppTheme.indigoAccent : AppTheme.surfaceBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: agentColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _agentProfiles[agent]?["title"] ?? "Assistant",
                                style: TextStyle(
                                  color: agentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          msg["content"] ?? "",
                          style: TextStyle(
                            color: isUser ? Colors.white : AppTheme.textPrimary,
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                        if (msg["model"] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            "Model: ${msg['model']}",
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Quick Prompts Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: (currentProfile["quickPrompts"] as List<String>).map((prompt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    label: Text(prompt, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                    backgroundColor: AppTheme.surfaceElevated,
                    side: const BorderSide(color: AppTheme.surfaceBorder),
                    onPressed: () => _sendMessage(prompt),
                  ),
                );
              }).toList(),
            ),
          ),

          // Input Bar
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: "Ask ${_agentProfiles[_activeAgent]!['title']}...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emeraldPrimary))
                      : const Icon(Icons.send_rounded, color: AppTheme.emeraldPrimary),
                  onPressed: () => _sendMessage(_messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
