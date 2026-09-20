import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trading_provider.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedOutcome = 'ALL'; // ALL, PROFIT, LOSS, OPEN
  String _selectedSymbol = 'ALL'; // ALL or specific symbol
  String _selectedDateRange = 'ALL'; // ALL, TODAY, THIS_WEEK

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val.toLocal();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val).toLocal();
    try {
      final dt = DateTime.parse(val.toString());
      return dt.toLocal();
    } catch (_) {
      return null;
    }
  }

  static String _formatTime(dynamic val) {
    final dt = _parseDateTime(val);
    if (dt == null) return '';
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      return DateFormat('hh:mm a').format(dt);
    } else {
      return DateFormat('dd MMM, hh:mm a').format(dt);
    }
  }

  /// Pairs BUY → SELL signals per symbol and calculates point difference
  List<Map<String, dynamic>> _buildTradeReports(List<dynamic> signals) {
    final Map<String, List<Map<String, dynamic>>> bySymbol = {};
    for (final s in signals) {
      final sym = s['symbol'] ?? s['rawSymbol'] ?? 'UNKNOWN';
      bySymbol.putIfAbsent(sym, () => []).add(Map<String, dynamic>.from(s as Map));
    }

    final List<Map<String, dynamic>> reports = [];

    bySymbol.forEach((symbol, symSignals) {
      symSignals.sort((a, b) {
        final aTime = _parseDateTime(a['receivedAt'] ?? a['createdAt'] ?? a['timestamp']);
        final bTime = _parseDateTime(b['receivedAt'] ?? b['createdAt'] ?? b['timestamp']);
        if (aTime == null || bTime == null) return 0;
        return aTime.compareTo(bTime);
      });

      Map<String, dynamic>? openEntry;
      for (final sig in symSignals) {
        final action = (sig['action'] ?? '').toString().toUpperCase();
        final price = (sig['price'] ?? 0).toDouble();
        final receivedAt = sig['receivedAt'] ?? sig['createdAt'] ?? sig['timestamp'];
        final id = sig['_id'] ?? sig['id'];

        if (openEntry == null) {
          openEntry = {
            'id': id,
            'symbol': symbol,
            'entryAction': action,
            'entryPrice': price,
            'entryTime': receivedAt,
          };
        } else {
          final entryAction = openEntry['entryAction'] as String;
          if ((entryAction == 'BUY' && action == 'SELL') ||
              (entryAction == 'SELL' && action == 'BUY')) {
            final entryPrice = openEntry['entryPrice'] as double;
            final exitPrice = price;
            final double pointsDiff = entryAction == 'BUY'
                ? exitPrice - entryPrice
                : entryPrice - exitPrice;

            reports.add({
              'id': openEntry['id'] ?? id,
              'symbol': symbol,
              'entryAction': entryAction,
              'exitAction': action,
              'entryPrice': entryPrice,
              'exitPrice': exitPrice,
              'points': pointsDiff,
              'entryTime': openEntry['entryTime'],
              'exitTime': receivedAt,
            });
            openEntry = null;
          } else {
            openEntry = {
              'id': id,
              'symbol': symbol,
              'entryAction': action,
              'entryPrice': price,
              'entryTime': receivedAt,
            };
          }
        }
      }

      if (openEntry != null) {
        reports.add({
          'id': openEntry['id'],
          'symbol': symbol,
          'entryAction': openEntry['entryAction'],
          'exitAction': 'OPEN',
          'entryPrice': openEntry['entryPrice'],
          'exitPrice': null,
          'points': null,
          'entryTime': openEntry['entryTime'],
          'exitTime': null,
        });
      }
    });

    reports.sort((a, b) {
      final aTime = _parseDateTime(a['entryTime']);
      final bTime = _parseDateTime(b['entryTime']);
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return reports;
  }

  List<Map<String, dynamic>> _filterReports(List<Map<String, dynamic>> rawReports) {
    final now = DateTime.now();
    return rawReports.where((r) {
      // 1. Outcome Filter
      if (_selectedOutcome == 'PROFIT' && (r['points'] == null || (r['points'] as double) <= 0)) {
        return false;
      }
      if (_selectedOutcome == 'LOSS' && (r['points'] == null || (r['points'] as double) >= 0)) {
        return false;
      }
      if (_selectedOutcome == 'OPEN' && r['exitAction'] != 'OPEN') {
        return false;
      }

      // 2. Symbol Filter
      if (_selectedSymbol != 'ALL' && r['symbol'] != _selectedSymbol) {
        return false;
      }

      // 3. Date Filter
      final entryDt = _parseDateTime(r['entryTime']);
      if (_selectedDateRange == 'TODAY' && entryDt != null) {
        if (entryDt.year != now.year || entryDt.month != now.month || entryDt.day != now.day) {
          return false;
        }
      } else if (_selectedDateRange == 'THIS_WEEK' && entryDt != null) {
        final diffDays = now.difference(entryDt).inDays;
        if (diffDays > 7) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TradingProvider>(context);
    final allReports = _buildTradeReports(provider.signals);
    final filteredReports = _filterReports(allReports);

    // Dynamic symbols list
    final availableSymbols = ['ALL', ...allReports.map((r) => r['symbol'] as String).toSet()];

    // Summary totals based on filtered reports
    final closedReports = filteredReports.where((r) => r['points'] != null).toList();
    final totalPoints = closedReports.fold<double>(0, (sum, r) => sum + (r['points'] as double));
    final winners = closedReports.where((r) => (r['points'] as double) > 0).length;
    final losers = closedReports.where((r) => (r['points'] as double) < 0).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Trade Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => provider.fetchSignals(),
            tooltip: 'Refresh Reports',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.sellRed),
            tooltip: 'Clear All Reports',
            onPressed: () => _confirmClearAll(context, provider),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Controls ───────────────────────────────────────
          _buildFilterBar(availableSymbols),

          // ── Summary Banner ──────────────────────────────────────────
          if (closedReports.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: totalPoints >= 0
                      ? [const Color(0xFF047857), const Color(0xFF10B981)]
                      : [const Color(0xFFB91C1C), const Color(0xFFEF4444)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: (totalPoints >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                        .withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FILTERED P&L (Points)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${totalPoints >= 0 ? '+' : ''}${totalPoints.toStringAsFixed(1)} pts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statBadge('${closedReports.length}', 'Trades'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _statBadge('$winners', '▲ Win', Colors.white.withValues(alpha: 0.25)),
                          const SizedBox(width: 6),
                          _statBadge('$losers', '▼ Loss', Colors.white.withValues(alpha: 0.15)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ── Trade List ──────────────────────────────────────────────
          Expanded(
            child: filteredReports.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () => provider.refreshAll(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: filteredReports.length,
                      itemBuilder: (context, index) {
                        return _buildReportCard(context, provider, filteredReports[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<String> symbols) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        children: [
          // Filter Chips Row 1: Outcome Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                _filterChip('ALL', 'All Outcomes', _selectedOutcome == 'ALL', (v) {
                  setState(() => _selectedOutcome = 'ALL');
                }),
                const SizedBox(width: 6),
                _filterChip('PROFIT', 'Profit Only (Win)', _selectedOutcome == 'PROFIT', (v) {
                  setState(() => _selectedOutcome = 'PROFIT');
                }, bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D)),
                const SizedBox(width: 6),
                _filterChip('LOSS', 'Loss Only', _selectedOutcome == 'LOSS', (v) {
                  setState(() => _selectedOutcome = 'LOSS');
                }, bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C)),
                const SizedBox(width: 6),
                _filterChip('OPEN', 'Open Positions', _selectedOutcome == 'OPEN', (v) {
                  setState(() => _selectedOutcome = 'OPEN');
                }),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Filter Chips Row 2: Symbol & Date Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                _filterChip('ALL_DATE', 'All Time', _selectedDateRange == 'ALL', (v) {
                  setState(() => _selectedDateRange = 'ALL');
                }),
                const SizedBox(width: 4),
                _filterChip('TODAY', 'Today', _selectedDateRange == 'TODAY', (v) {
                  setState(() => _selectedDateRange = 'TODAY');
                }),
                const SizedBox(width: 4),
                _filterChip('THIS_WEEK', 'This Week', _selectedDateRange == 'THIS_WEEK', (v) {
                  setState(() => _selectedDateRange = 'THIS_WEEK');
                }),
                const SizedBox(width: 12),
                const Icon(Icons.show_chart_rounded, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                ...symbols.map((sym) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _filterChip(sym, sym, _selectedSymbol == sym, (v) {
                      setState(() => _selectedSymbol = sym);
                    }),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String id, String label, bool isSelected, Function(bool) onSelected, {Color? bg, Color? fg}) {
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? (fg ?? Colors.white) : AppTheme.textSecondary,
        ),
      ),
      selectedColor: bg ?? AppTheme.primary,
      backgroundColor: Colors.grey.shade100,
      checkmarkColor: fg ?? Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      onSelected: onSelected,
    );
  }

  Widget _statBadge(String value, String label, [Color? bg]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, TradingProvider provider, Map<String, dynamic> report) {
    final reportId = report['id']?.toString();
    final symbol = report['symbol'] as String;
    final entryAction = report['entryAction'] as String;
    final exitAction = report['exitAction'] as String;
    final entryPrice = report['entryPrice'] as double;
    final exitPrice = report['exitPrice'] as double?;
    final double? points = report['points'] as double?;
    final isOpen = exitAction == 'OPEN';
    final isProfit = (points ?? 0) >= 0;

    final String entryTimeStr = _formatTime(report['entryTime']);
    final String exitTimeStr = _formatTime(report['exitTime']);

    final entryColor = entryAction == 'BUY' ? AppTheme.buyGreen : AppTheme.sellRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOpen
              ? AppTheme.border
              : isProfit
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : const Color(0xFFEF4444).withValues(alpha: 0.3),
          width: isOpen ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Symbol + Points Badge + Delete Menu ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    symbol,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isOpen)
                  _chip('OPEN', const Color(0xFFF1F5F9), AppTheme.textSecondary)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isProfit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${isProfit ? '+' : ''}${points!.toStringAsFixed(1)} pts',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: isProfit ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                if (reportId != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey),
                    tooltip: 'Delete Report Record',
                    onPressed: () => _confirmDeleteTrade(context, provider, reportId, symbol),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // ── BUY → SELL Flow ──
            Row(
              children: [
                Expanded(
                  child: _priceBox(
                    label: entryAction,
                    price: entryPrice,
                    time: entryTimeStr,
                    color: entryColor,
                    isEntry: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: isOpen
                            ? AppTheme.textSecondary
                            : isProfit
                                ? AppTheme.buyGreen
                                : AppTheme.sellRed,
                        size: 20,
                      ),
                      if (!isOpen && points != null)
                        Text(
                          '${isProfit ? '+' : ''}${points.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isProfit ? AppTheme.buyGreen : AppTheme.sellRed,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: isOpen
                      ? _pendingBox()
                      : _priceBox(
                          label: exitAction,
                          price: exitPrice!,
                          time: exitTimeStr,
                          color: exitAction == 'BUY' ? AppTheme.buyGreen : AppTheme.sellRed,
                          isEntry: false,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceBox({
    required String label,
    required double price,
    required String time,
    required Color color,
    required bool isEntry,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: isEntry ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
          const SizedBox(height: 3),
          Text('₹${price.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary)),
          if (time.isNotEmpty)
            Text(time, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _pendingBox() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('AWAITING', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 10)),
          SizedBox(height: 3),
          Text('Next Signal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Icon(Icons.bar_chart_rounded, size: 52, color: AppTheme.textSecondary),
              SizedBox(height: 12),
              Text(
                'No trade reports found.',
                style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text(
                'Try adjusting your filter selection or clear history.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteTrade(BuildContext context, TradingProvider provider, String tradeId, String symbol) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Delete $symbol Record?'),
        content: const Text('This will permanently delete this trade report record from history.'),
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
          const SnackBar(content: Text('Trade record deleted successfully.')),
        );
      }
    }
  }

  Future<void> _confirmClearAll(BuildContext context, TradingProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Clear All Trade Reports?'),
        content: const Text('This will permanently delete all trades and report history. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.sellRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All History', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.clearAllTrades();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All trade reports cleared successfully.')),
        );
      }
    }
  }
}
