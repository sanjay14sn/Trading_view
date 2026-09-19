import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trading_provider.dart';
import '../theme/app_theme.dart';

class SignalsScreen extends StatelessWidget {
  const SignalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TradingProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('TradingView Signals Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => provider.fetchSignals(),
          )
        ],
      ),
      body: provider.signals.isEmpty
          ? RefreshIndicator(
              onRefresh: () => provider.refreshAll(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.sensors_rounded, size: 48, color: AppTheme.textSecondary),
                        SizedBox(height: 12),
                        Text('No webhooks received yet.', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('Send a signal from TradingView or test via cURL.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => provider.refreshAll(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: provider.signals.length,
                itemBuilder: (context, index) {
                  final signal = provider.signals[index];
                  return _buildSignalCard(context, signal);
                },
              ),
            ),
    );
  }

  Widget _buildSignalCard(BuildContext context, dynamic signal) {
    final symbol = signal['symbol'] ?? signal['rawSymbol'] ?? 'N/A';
    final action = (signal['action'] ?? 'BUY').toString().toUpperCase();
    final isBuy = action == 'BUY';
    final price = signal['price'] ?? 0;
    final status = (signal['status'] ?? 'pending').toString();
    final receivedAtStr = signal['receivedAt'];

    String formattedTime = 'Just now';
    if (receivedAtStr != null) {
      try {
        final dt = DateTime.parse(receivedAtStr.toString());
        formattedTime = DateFormat('hh:mm:ss a').format(dt);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Signal Details - $symbol', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  Text('Symbol: $symbol'),
                  Text('Action: $action'),
                  Text('Price: ₹$price'),
                  Text('Status: $status'),
                  Text('Received At: $receivedAtStr'),
                  if (signal['rejectionReason'] != null)
                    Text('Rejection Reason: ${signal['rejectionReason']}', style: const TextStyle(color: AppTheme.sellRed)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isBuy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                child: Icon(
                  isBuy ? Icons.north_east_rounded : Icons.south_east_rounded,
                  color: isBuy ? AppTheme.buyGreen : AppTheme.sellRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            symbol,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildStatusChip(status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Price: ₹$price • $formattedTime',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                action,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isBuy ? AppTheme.buyGreen : AppTheme.sellRed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = AppTheme.textSecondary;

    if (status == 'accepted' || status == 'OPEN') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (status.contains('rejected') || status.contains('risk') || status == 'duplicate') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
