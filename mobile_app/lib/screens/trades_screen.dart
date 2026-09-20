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

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val.toLocal();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val).toLocal();
    try {
      return DateTime.parse(val.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  static String _formatTime(dynamic val) {
    final dt = _parseDateTime(val);
    if (dt == null) return 'N/A';
    return DateFormat('dd MMM yyyy, hh:mm:ss a').format(dt);
  }

  void _showTradeDetailsBottomSheet(BuildContext context, TradingProvider provider, dynamic trade) {
    final symbol = (trade['symbol'] ?? 'N/A').toString();
    final action = (trade['action'] ?? 'BUY').toString().toUpperCase();
    final isBuy = action == 'BUY';
    final status = (trade['status'] ?? 'PENDING').toString();
    final isOpen = status == 'OPEN' || status == 'PENDING' || status == 'QUEUED';
    final entryPrice = trade['entryPrice'] ?? 0;
    final exitPrice = trade['exitPrice'];
    final pnl = trade['pnl'];
    final quantity = trade['quantity'] ?? 1;
    final tradeId = (trade['_id'] ?? trade['id'] ?? 'N/A').toString();
    final timestamp = trade['receivedAt'] ?? trade['createdAt'] ?? trade['timestamp'];

    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Indicator Bar
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header: Action Tag + Symbol + Status + Close Button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isBuy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      action,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: isBuy ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      symbol,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusTag(status),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // P&L or Status Highlight Banner Card
              if (pnl != null) ...[
                Builder(
                  builder: (context) {
                    final numPnl = (pnl is num) ? pnl.toDouble() : 0.0;
                    final isPnlPositive = numPnl >= 0;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isPnlPositive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPnlPositive ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL P&L',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isPnlPositive ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatter.format(pnl),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: isPnlPositive ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            isPnlPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            size: 32,
                            color: isPnlPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Signal Details Grid Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _detailRow('Entry Price', '₹$entryPrice', icon: Icons.login_rounded),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _detailRow('Exit Price', exitPrice != null ? '₹$exitPrice' : 'OPEN / ACTIVE', icon: Icons.logout_rounded),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _detailRow('Quantity', '$quantity Units', icon: Icons.numbers_rounded),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _detailRow('Received Time', _formatTime(timestamp), icon: Icons.schedule_rounded),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _detailRow('Signal ID', tradeId, icon: Icons.fingerprint_rounded, isId: true),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              if (isOpen) ...[
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.sellRed,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                    label: const Text('MANUAL EXIT POSITION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          backgroundColor: Colors.white,
                          title: Text('Close $symbol Position?'),
                          content: const Text('This will execute a market order to close this active trade instantly.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.sellRed),
                              onPressed: () => Navigator.pop(dialogCtx, true),
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
                const SizedBox(height: 10),
              ],

              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECDD3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete Trade Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    _confirmDeleteTrade(context, provider, tradeId, symbol);
                  },
                ),
              ),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {required IconData icon, bool isId = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isId ? 11 : 13,
              fontWeight: FontWeight.w700,
              color: isId ? const Color(0xFF475569) : const Color(0xFF0F172A),
              fontFamily: isId ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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
        padding: const EdgeInsets.all(14),
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
    final entryPrice = trade['entryPrice'] ?? 0;
    final pnl = trade['pnl'];

    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return GestureDetector(
      onTap: () => _showTradeDetailsBottomSheet(context, provider, trade),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    symbol,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                _buildStatusTag(status),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Entry Price', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text('₹$entryPrice', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quantity', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text('${trade['quantity']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
                if (pnl != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('P&L', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text(
                        formatter.format(pnl),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: (pnl as num) >= 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    if (status == 'OPEN' || status == 'QUEUED') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (status == 'FAILED') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else if (status.contains('HIT') || status == 'CLOSED') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
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
