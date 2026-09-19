import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trading_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/signal_alert_overlay.dart';

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
                      child: const Text('SAVE & TEST CONNECTION', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.buyGreen,
                        side: const BorderSide(color: AppTheme.buyGreen, width: 1.5),
                      ),
                      icon: const Icon(Icons.notifications_active_rounded, size: 18),
                      label: const Text('TEST FULL-SCREEN SIGNAL ALERT (5s)', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        SignalAlertOverlay.show(context, {
                          'symbol': 'BANKNIFTY26SEPFUT',
                          'action': 'BUY',
                          'price': 51250.00,
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Zerodha Broker Setup Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance, color: AppTheme.buyGreen),
                      SizedBox(width: 8),
                      Text('Zerodha Kite Broker Connection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Daily access token authentication is managed automatically via session manager.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.buyGreen,
                      side: const BorderSide(color: AppTheme.buyGreen),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Login to Zerodha Kite'),
                    onPressed: () {
                      final url = '${provider.serverUrl}/api/zerodha/auth/login';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Open in browser: $url')),
                      );
                    },
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
                      Icon(Icons.shield, color: AppTheme.warningOrange),
                      SizedBox(width: 8),
                      Text('Active Risk Rules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text('• Max Concurrent Positions: 3', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 4),
                  Text('• Max Daily Loss Limit: ₹5,000', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 4),
                  Text('• Symbol Cooldown: 30 Seconds', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 4),
                  Text('• EOD Auto Square-off: 3:20 PM IST', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
