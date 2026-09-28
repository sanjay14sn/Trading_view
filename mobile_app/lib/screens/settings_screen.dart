import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trading_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<TradingProvider>(context, listen: false);
    _urlController = TextEditingController(text: provider.serverUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TradingProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Configuration'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Server URL Configuration Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dns, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text('Backend Server Connection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Enter local server URL or ngrok domain:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'https://apitrading.iqsync.in or https://xxx.ngrok-free.dev',
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Quick Connection Presets:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.cloud_done, size: 14, color: AppTheme.buyGreen),
                        label: const Text('Production API', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          _urlController.text = 'https://apitrading.iqsync.in';
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.cloud, size: 14, color: AppTheme.primary),
                        label: const Text('ngrok Tunnel', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          _urlController.text = 'https://grained-nontelegraphical-gwen.ngrok-free.dev';
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.computer, size: 14, color: AppTheme.textSecondary),
                        label: const Text('Localhost', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          _urlController.text = 'http://localhost:3001';
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.background,
                      ),
                      onPressed: () async {
                        await provider.updateServerUrl(_urlController.text);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(provider.isServerOnline ? 'Connected successfully! ✅' : 'Failed to connect to server ❌'),
                            ),
                          );
                        }
                      },
                      child: const Text('SAVE & TEST CONNECTION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // MT5 Hantec Broker Setup Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.currency_bitcoin, color: AppTheme.buyGreen),
                      SizedBox(width: 8),
                      Text('MT5 Hantec Bridge (BTCUSD)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'MT5 EA (HantecBridgeEA.mq5) polls pending orders & posts execution results to the backend.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Target Symbol: BTCUSD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('EA Polling Endpoint: ${provider.serverUrl}/api/mt5/pending-orders', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Risk Rules Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.flash_on, color: AppTheme.buyGreen),
                      SizedBox(width: 8),
                      Text('Risk Management Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text('⚡ Risk Management Disabled (Direct Pass-Through)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.buyGreen)),
                  SizedBox(height: 4),
                  Text('• Every valid signal is sent directly to MT5 EA', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  SizedBox(height: 4),
                  Text('• No daily trade count or loss caps enforced', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
