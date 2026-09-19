import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trading_provider.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

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
    // Group by symbol
    final Map<String, List<Map<String, dynamic>>> bySymbol = {};
    for (final s in signals) {
      final sym = s['symbol'] ?? s['rawSymbol'] ?? 'UNKNOWN';
      bySymbol.putIfAbsent(sym, () => []).add(Map<String, dynamic>.from(s as Map));
    }

    final List<Map<String, dynamic>> reports = [];

    bySymbol.forEach((symbol, symSignals) {
      // Sort oldest → newest
      symSignals.sort((a, b) {
        final aTime = _parseDateTime(a['receivedAt'] ?? a['createdAt'] ?? a['timestamp']);
        final bTime = _parseDateTime(b['receivedAt'] ?? b['createdAt'] ?? b['timestamp']);
        if (aTime == null || bTime == null) return 0;
        return aTime.compareTo(bTime);
      });

      // Pair: first BUY → next SELL (or first SELL → next BUY)
      Map<String, dynamic>? openEntry;
      for (final sig in symSignals) {
        final action = (sig['action'] ?? '').toString().toUpperCase();
        final price = (sig['price'] ?? 0).toDouble();
        final receivedAt = sig['receivedAt'] ?? sig['createdAt'] ?? sig['timestamp'];

        if (openEntry == null) {
          // Start a new open entry
          openEntry = {
            'symbol': symbol,
            'entryAction': action,
            'entryPrice': price,
            'entryTime': receivedAt,
          };
        } else {
          final entryAction = openEntry['entryAction'] as String;
          // Close when opposite side comes
          if ((entryAction == 'BUY' && action == 'SELL') ||
              (entryAction == 'SELL' && action == 'BUY')) {
            final entryPrice = openEntry['entryPrice'] as double;
            final exitPrice = price;
            final double pointsDiff = entryAction == 'BUY'
                ? exitPrice - entryPrice
                : entryPrice - exitPrice;

            reports.add({
              'symbol': symbol,
              'entryAction': entryAction,
              'exitAction': action,
              'entryPrice': entryPrice,
              'exitPrice': exitPrice,
              'points': pointsDiff,
              'entryTime': openEntry['entryTime'],
              'exitTime': receivedAt,
            });
            openEntry = null; // Reset for next pair
          } else {
            // Same side came again — treat as new entry
            openEntry = {
              'symbol': symbol,
              'entryAction': action,
              'entryPrice': price,
              'entryTime': receivedAt,
            };
          }
        }
      }

      // If there's an open entry with no exit, show it as "Open"
      if (openEntry != null) {
        reports.add({
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

    // Sort reports by entryTime descending
    reports.sort((a, b) {
      final aTime = _parseDateTime(a['entryTime']);
      final bTime = _parseDateTime(b['entryTime']);
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return reports;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TradingProvider>(context);
    final reports = _buildTradeReports(provider.signals);

    // Summary totals
    final closedReports = reports.where((r) => r['points'] != null).toList();
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
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Summary Banner ──────────────────────────────────────────
          if (closedReports.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: totalPoints >= 0
                      ? [const Color(0xFF047857), const Color(0xFF10B981)]
                      : [const Color(0xFFB91C1C), const Color(0xFFEF4444)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (totalPoints >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                        .withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
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
                          'TOTAL P&L (Points)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${totalPoints >= 0 ? '+' : ''}${totalPoints.toStringAsFixed(1)} pts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _statBadge('$winners', '▲ Win', Colors.white.withValues(alpha: 0.25)),
                          const SizedBox(width: 8),
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
            child: reports.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () => provider.refreshAll(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        return _buildReportCard(reports[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String value, String label, [Color? bg]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg ?? Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
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
            // ── Header: Symbol + Points Badge ──
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isProfit
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${isProfit ? '+' : ''}${points!.toStringAsFixed(1)} pts',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: isProfit
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // ── BUY → SELL Flow ──
            Row(
              children: [
                // Entry side
                Expanded(
                  child: _priceBox(
                    label: entryAction,
                    price: entryPrice,
                    time: entryTimeStr,
                    color: entryColor,
                    isEntry: true,
                  ),
                ),

                // Arrow
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
                        size: 22,
                      ),
                      if (!isOpen && points != null)
                        Text(
                          '${isProfit ? '+' : ''}${points.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isProfit ? AppTheme.buyGreen : AppTheme.sellRed,
                          ),
                        ),
                    ],
                  ),
                ),

                // Exit side
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
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '₹${price.toStringAsFixed(1)}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
          if (time.isNotEmpty)
            Text(
              time,
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
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
          Text('AWAITING',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11)),
          SizedBox(height: 3),
          Text('Next Signal',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(Icons.bar_chart_rounded, size: 52, color: AppTheme.textSecondary),
              SizedBox(height: 12),
              Text(
                'No trade pairs yet.',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
              SizedBox(height: 6),
              Text(
                'Reports appear when a BUY is followed by a SELL\n(or vice versa) on the same symbol.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
