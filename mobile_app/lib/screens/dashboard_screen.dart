import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trading_provider.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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

  /// Pairs BUY → SELL signals to calculate reports & performance metrics
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
              'symbol': symbol,
              'points': pointsDiff,
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
        reports.add({'symbol': symbol, 'points': null});
      }
    });

    return reports;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TradingProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.refreshAll(),
          color: AppTheme.primary,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // 👤 Top User Profile Header Row
              _buildTopHeader(context, provider),

              const SizedBox(height: 16),

              // 📈 Performance Dashboard Card (Moved from Trade Reports page)
              _buildPerformanceCard(context, provider),

              const SizedBox(height: 16),

              // 📊 Quick Stats Grid (Total Signals)
              _buildStatsGrid(context, provider),

              const SizedBox(height: 16),

              // 🛡️ System & Storage Engine Card
              _buildSystemHealthCard(context, provider),
            ],
          ),
        ),
      ),
    );
  }

  // 👤 Top Header Row
  Widget _buildTopHeader(BuildContext context, TradingProvider provider) {
    return Row(
      children: [
        // User Profile Avatar
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE2E8F0),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Image.network(
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => const Icon(
                Icons.person_rounded,
                color: AppTheme.textSecondary,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Hello,',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                'Sanjay',
                style: TextStyle(
                  fontSize: 17,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),

        // 🔴/🟢 Status Chip
        _buildStatusChip(provider),

        const SizedBox(width: 6),

        // Notification Bell Icon with indicator
        Stack(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppTheme.textPrimary,
                size: 19,
              ),
            ),
            Positioned(
              right: 7,
              top: 7,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppTheme.sellRed,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 🔴/🟢 Status Chip
  Widget _buildStatusChip(TradingProvider provider) {
    final isOnline = provider.isServerOnline;
    final color = isOnline ? AppTheme.buyGreen : AppTheme.sellRed;
    final bg = isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFFF0F0);
    final border = isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFFFCACA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'LIVE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // 📈 Trade Performance Dashboard Card (Moved from Trade Reports page)
  Widget _buildPerformanceCard(BuildContext context, TradingProvider provider) {
    final reports = _buildTradeReports(provider.signals);
    final closedReports = reports.where((r) => r['points'] != null).toList();
    final totalPoints = closedReports.fold<double>(0, (sum, r) => sum + (r['points'] as double));
    final winners = closedReports.where((r) => (r['points'] as double) > 0).length;
    final losers = closedReports.where((r) => (r['points'] as double) < 0).length;
    final totalTradesCount = reports.length;
    final winRate = closedReports.isNotEmpty
        ? ((winners / closedReports.length) * 100).toStringAsFixed(1)
        : '0.0';

    final isPositive = totalPoints >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [const Color(0xFFEFFDF5), const Color(0xFFF0FDF4), Colors.white]
              : [const Color(0xFFFEF2F2), const Color(0xFFFFF1F1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFECDD3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header inside Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total P&L (Points)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPositive ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      provider.isSocketConnected ? 'WebSocket' : 'Polling',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Big P&L readout & Sparkline Graph
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isPositive ? '+' : ''}${NumberFormat('#,##0.0').format(totalPoints)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: isPositive ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                size: 12,
                                color: isPositive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${isPositive ? '+' : ''}Live',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isPositive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Performance Analytics',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Sparkline graph
              SizedBox(
                width: 100,
                height: 48,
                child: CustomPaint(
                  painter: _SparklinePainter(isPositive: isPositive),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 4 Stat Grid
          Row(
            children: [
              _statGridCard(
                icon: Icons.bar_chart_rounded,
                iconColor: const Color(0xFF2563EB),
                value: '$totalTradesCount',
                label: 'Total Trades',
                bg: Colors.white,
              ),
              const SizedBox(width: 8),
              _statGridCard(
                icon: Icons.keyboard_arrow_up_rounded,
                iconColor: const Color(0xFF16A34A),
                value: '$winners',
                label: 'Wins',
                bg: Colors.white,
              ),
              const SizedBox(width: 8),
              _statGridCard(
                icon: Icons.keyboard_arrow_down_rounded,
                iconColor: const Color(0xFFDC2626),
                value: '$losers',
                label: 'Losses',
                bg: const Color(0xFFFEF2F2),
              ),
              const SizedBox(width: 8),
              _statGridCard(
                icon: Icons.percent_rounded,
                iconColor: const Color(0xFF0F172A),
                value: '$winRate%',
                label: 'Win Rate',
                bg: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statGridCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required Color bg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // 📊 Quick Stats Grid
  Widget _buildStatsGrid(BuildContext context, TradingProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Total Signals Today',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Real-time alerts processed',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '${provider.totalSignalsToday}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }

  // 🛡️ System & Storage Engine Card
  Widget _buildSystemHealthCard(BuildContext context, TradingProvider provider) {
    final riskStats = provider.dashboardData?['riskStats'] ?? {};
    final isDbMock = riskStats['isDbMock'] ?? true;
    final isRedisMock = riskStats['isRedisMock'] ?? true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_rounded, color: AppTheme.primary, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'System & Storage Engine',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF166534)),
                    SizedBox(width: 3),
                    Text(
                      'All Systems Ready',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Database Badge
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storage_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Database',
                              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDbMock ? const Color(0xFFEFF6FF) : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isDbMock ? 'In-Memory Mock' : 'MongoDB Live',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isDbMock ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Redis Queue Badge
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.layers_rounded, color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Redis Queue',
                              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isRedisMock ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isRedisMock ? 'Internal Mock' : 'Redis Active',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isRedisMock ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// CustomPainter for green/red sparkline wave line in performance card
class _SparklinePainter extends CustomPainter {
  final bool isPositive;
  _SparklinePainter({required this.isPositive});

  @override
  void paint(Canvas canvas, Size size) {
    final color = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    final path = Path();
    path.moveTo(0, size.height * 0.75);
    path.cubicTo(
      size.width * 0.25, size.height * 0.55,
      size.width * 0.4, size.height * 0.85,
      size.width * 0.6, size.height * 0.45,
    );
    path.cubicTo(
      size.width * 0.75, size.height * 0.15,
      size.width * 0.85, size.height * 0.35,
      size.width, size.height * 0.15,
    );

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.18),
        color.withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
