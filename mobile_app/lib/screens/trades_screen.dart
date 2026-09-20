import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trading_provider.dart';
import '../theme/app_theme.dart';

class TradesScreen extends StatefulWidget {
  const TradesScreen({super.key});

  @override
  State<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends State<TradesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TradingProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Trades & Positions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.sellRed),
            tooltip: 'Clear History',
            onPressed: () => _confirmClearAllTrades(context, provider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Open'),
            Tab(text: 'Closed'),
            Tab(text: 'Failed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTradeList(context, provider, filter: null),
          _buildTradeList(context, provider, filter: 'OPEN'),
          _buildTradeList(context, provider, filter: 'CLOSED'),
          _buildTradeList(context, provider, filter: 'FAILED'),
        ],
      ),
    );
  }

  Widget _buildTradeList(BuildContext context, TradingProvider provider, {String? filter}) {
    List<dynamic> filtered = provider.trades;
    if (filter != null) {
      if (filter == 'CLOSED') {
        filtered = provider.trades.where((t) => t['status'] != 'OPEN' && t['status'] != 'PENDING' && t['status'] != 'QUEUED' && t['status'] != 'FAILED').toList();
      } else {
        filtered = provider.trades.where((t) => t['status'] == filter).toList();
      }
    }

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => provider.refreshAll(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Center(
              child: Text('No trades found for this filter', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refreshAll(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final trade = filtered[index];
          return _buildTradeCard(context, provider, trade);
        },
      ),
    );
  }

  Widget _buildTradeCard(BuildContext context, TradingProvider provider, dynamic trade) {
    final symbol = trade['symbol'] ?? 'N/A';
    final action = (trade['action'] ?? 'BUY').toString().toUpperCase();
    final isBuy = action == 'BUY';
    final status = (trade['status'] ?? 'PENDING').toString();
    final isOpen = status == 'OPEN' || status == 'PENDING' || status == 'QUEUED';
    final entryPrice = trade['entryPrice'] ?? 0;
    final pnl = trade['pnl'];

    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isBuy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  action,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isBuy ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  symbol,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              _buildStatusTag(status),
              const SizedBox(width: 4),
              if (trade['_id'] != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                  tooltip: 'Delete Trade Record',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  onPressed: () => _confirmDeleteTrade(context, provider, trade['_id'].toString(), symbol),
                ),
            ],
          ),
          const Divider(height: 24, color: AppTheme.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Entry Price', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text('₹$entryPrice', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quantity', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text('${trade['quantity']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              if (pnl != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('P&L', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      formatter.format(pnl),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: (pnl as num) >= 0 ? AppTheme.buyGreen : AppTheme.sellRed,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (isOpen) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.sellRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                label: const Text('MANUAL EXIT POSITION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      title: Text('Close $symbol Position?'),
                      content: const Text('This will execute a market order to close this active trade instantly.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.sellRed),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Confirm Exit', style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await provider.closeTradeManually(trade['_id']);
                  }
                },
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = AppTheme.textSecondary;

    if (status == 'OPEN' || status == 'QUEUED') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (status == 'FAILED') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else if (status.contains('HIT') || status == 'CLOSED') {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF1D4ED8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Future<void> _confirmDeleteTrade(BuildContext context, TradingProvider provider, String tradeId, String symbol) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Delete $symbol Trade?'),
        content: const Text('This will permanently delete this trade record from database history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.sellRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.deleteTrade(tradeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trade deleted successfully.')),
        );
      }
    }
  }

  Future<void> _confirmClearAllTrades(BuildContext context, TradingProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Clear All Trades?'),
        content: const Text('This will permanently delete all trade history and signals. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.sellRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.clearAllTrades();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All trades cleared successfully.')),
        );
      }
    }
  }
}
