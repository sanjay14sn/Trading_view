import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trading_provider.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _timePeriod = 'DAILY'; // DAILY, WEEKLY, MONTHLY, CUSTOM, ALL
  DateTime? _customDate;
  String _pairFilter = 'ALL'; // ALL, USD (USD/USDT pairs), or specific symbol

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
              'entryAction': entryAction,
              'entryPrice': entryPrice,
              'exitPrice': exitPrice,
              'points': pointsDiff,
              'entryTime': openEntry['entryTime'],
              'exitTime': receivedAt,
            });

            // Automatic Reversal: Exit signal opens the next container!
            openEntry = {
              'id': id,
              'symbol': symbol,
              'entryAction': action,
              'entryPrice': price,
              'entryTime': receivedAt,
            };
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
          'symbol': symbol,
          'entryAction': openEntry['entryAction'],
          'entryPrice': openEntry['entryPrice'],
          'exitPrice': null,
          'points': null,
          'entryTime': openEntry['entryTime'],
          'exitTime': null,
        });
      }
    });

    return reports;
  }

  bool _matchesTimePeriod(dynamic entryTimeVal) {
    if (_timePeriod == 'ALL') return true;
    final entryDt = _parseDateTime(entryTimeVal);
    if (entryDt == null) return true;

    final now = DateTime.now();
    if (_timePeriod == 'DAILY') {
      return entryDt.year == now.year &&
          entryDt.month == now.month &&
          entryDt.day == now.day;
    } else if (_timePeriod == 'WEEKLY') {
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      return entryDt.isAfter(sevenDaysAgo);
    } else if (_timePeriod == 'MONTHLY') {
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      return entryDt.isAfter(thirtyDaysAgo);
    } else if (_timePeriod == 'CUSTOM') {
      if (_customDate == null) return true;
      return entryDt.year == _customDate!.year &&
          entryDt.month == _customDate!.month &&
          entryDt.day == _customDate!.day;
    }
    return true;
  }

  bool _matchesPairFilter(String symbol) {
    if (_pairFilter == 'ALL') return true;
    if (_pairFilter == 'USD') {
      final symUpper = symbol.toUpperCase();
      return symUpper.contains('USD') || symUpper.contains('USDT');
    }
    return symbol == _pairFilter;
  }

  Future<void> _selectCustomDate(BuildContext context, StateSetter setModalState) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF16A34A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _customDate = picked;
        _timePeriod = 'CUSTOM';
      });
      setModalState(() {});
    }
  }

  void _openFilterBottomSheet(BuildContext context, List<String> availableSymbols) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
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
                  // Drag Handle Bar
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

                  // Modal Header & Reset Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.tune_rounded, size: 20, color: Color(0xFF0F172A)),
                          SizedBox(width: 8),
                          Text(
                            'Report Filters',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _timePeriod = 'DAILY';
                            _customDate = null;
                            _pairFilter = 'ALL';
                          });
                          setModalState(() {});
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Section 1: Time Period
                  const Text(
                    'TIME PERIOD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _modalTimeChip('DAILY', 'Daily (Today)', setModalState),
                      _modalTimeChip('WEEKLY', 'Week (7 Days)', setModalState),
                      _modalTimeChip('MONTHLY', 'Month (30 Days)', setModalState),
                      _modalTimeChip('ALL', 'All Time', setModalState),
                      _modalCustomDateChip(ctx, setModalState),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Section 2: Pairs & Currency
                  const Text(
                    'CURRENCY & PAIRS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _modalPairChip('ALL', 'All Pairs', setModalState),
                      _modalPairChip('USD', 'USD / USDT Pairs', setModalState),
                      ...availableSymbols.where((s) => s != 'ALL' && s != 'USD').map((sym) {
                        return _modalPairChip(sym, sym, setModalState);
                      }),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Apply Filters Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(modalContext),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(modalContext).padding.bottom + 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _modalTimeChip(String period, String label, StateSetter setModalState) {
    final isSelected = _timePeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() => _timePeriod = period);
        setModalState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _modalCustomDateChip(BuildContext context, StateSetter setModalState) {
    final isSelected = _timePeriod == 'CUSTOM';
    return GestureDetector(
      onTap: () => _selectCustomDate(context, setModalState),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 14,
              color: isSelected ? const Color(0xFF15803D) : const Color(0xFF334155),
            ),
            const SizedBox(width: 4),
            Text(
              isSelected && _customDate != null
                  ? DateFormat('dd MMM').format(_customDate!)
                  : 'Custom Date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF15803D) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalPairChip(String value, String label, StateSetter setModalState) {
    final isSelected = _pairFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _pairFilter = value);
        setModalState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value == 'USD') ...[
              const Icon(Icons.attach_money_rounded, size: 13, color: Color(0xFF15803D)),
              const SizedBox(width: 2),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF15803D) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TradingProvider>(context);
    final allReports = _buildTradeReports(provider.signals);

    // Apply Time Period & Pair Filters
    final filteredReports = allReports.where((r) {
      final timeOk = _matchesTimePeriod(r['entryTime']);
      final pairOk = _matchesPairFilter(r['symbol'] as String);
      return timeOk && pairOk;
    }).toList();

    // Extract available symbols for pair filter
    final availableSymbols = [
      'ALL',
      'USD',
      ...allReports.map((r) => r['symbol'] as String).toSet(),
    ];

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

              // 📈 Performance Dashboard Hero Card (With Image Background & Black/White/Red/Green theme)
              _buildPerformanceCard(context, provider, filteredReports, availableSymbols),

              const SizedBox(height: 16),

              // 📊 Quick Stats Grid
              _buildStatsGrid(context, provider),

              const SizedBox(height: 16),

              // 🛡️ System & Storage Engine Card
              _buildSystemHealthCard(context, provider),

              const SizedBox(height: 16),
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
            color: const Color(0xFF0F172A),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
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
                color: Colors.white,
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
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Sanjay',
                style: TextStyle(
                  fontSize: 17,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),

        // 🔴/🟢 Status Chip (Green for LIVE, Red for OFFLINE)
        _buildStatusChip(provider),

        const SizedBox(width: 6),

        // Notification Bell Icon with Red Indicator
        Stack(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                color: Color(0xFF0F172A),
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
                  color: Color(0xFFDC2626),
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
    final color = isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final bg = isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final border = isOnline ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);

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
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // 📈 Trade Performance Dashboard Hero Card (With Image Background & Black/White/Red/Green theme)
  Widget _buildPerformanceCard(
    BuildContext context,
    TradingProvider provider,
    List<Map<String, dynamic>> reports,
    List<String> availableSymbols,
  ) {
    final closedReports = reports.where((r) => r['points'] != null).toList();
    final totalPoints = closedReports.fold<double>(0, (sum, r) => sum + (r['points'] as double));
    final winners = closedReports.where((r) => (r['points'] as double) > 0).length;
    final losers = closedReports.where((r) => (r['points'] as double) < 0).length;
    final totalTradesCount = reports.length;
    final winRate = closedReports.isNotEmpty
        ? ((winners / closedReports.length) * 100).toStringAsFixed(1)
        : '0.0';

    final isPositive = totalPoints >= 0;

    String periodBadge = 'Today';
    if (_timePeriod == 'WEEKLY') periodBadge = 'Week (7D)';
    if (_timePeriod == 'MONTHLY') periodBadge = 'Month (30D)';
    if (_timePeriod == 'ALL') periodBadge = 'All Time';
    if (_timePeriod == 'CUSTOM' && _customDate != null) {
      periodBadge = DateFormat('dd MMM').format(_customDate!);
    }

    String pairBadge = 'All Pairs';
    if (_pairFilter == 'USD') {
      pairBadge = 'USD/USDT';
    } else if (_pairFilter != 'ALL') {
      pairBadge = _pairFilter;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark Slate Black
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=800'),
          fit: BoxFit.cover,
          opacity: 0.20,
        ),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header inside Card with Bottom Sheet Filter Trigger Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total P&L (Points)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                ),
              ),

              // Filter Trigger Chip (Opens Bottom Sheet)
              GestureDetector(
                onTap: () => _openFilterBottomSheet(context, availableSymbols),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '$periodBadge • $pairBadge',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

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
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: isPositive ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPositive
                                ? const Color(0xFF16A34A).withValues(alpha: 0.25)
                                : const Color(0xFFDC2626).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                size: 11,
                                color: isPositive ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${isPositive ? '+' : ''}Live Report',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isPositive ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Performance Summary',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Sparkline graph
              SizedBox(
                width: 90,
                height: 48,
                child: CustomPaint(
                  painter: _SparklinePainter(isPositive: isPositive),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 4 Stat Grid (Black & White with Red/Green highlights)
          Row(
            children: [
              _statGridCard(
                icon: Icons.bar_chart_rounded,
                iconColor: const Color(0xFF0F172A),
                value: '$totalTradesCount',
                label: 'Trades',
                bg: Colors.white,
              ),
              const SizedBox(width: 8),
              _statGridCard(
                icon: Icons.arrow_upward_rounded,
                iconColor: const Color(0xFF15803D),
                value: '$winners',
                label: 'Wins',
                bg: const Color(0xFFDCFCE7),
              ),
              const SizedBox(width: 8),
              _statGridCard(
                icon: Icons.arrow_downward_rounded,
                iconColor: const Color(0xFFB91C1C),
                value: '$losers',
                label: 'Losses',
                bg: const Color(0xFFFEE2E2),
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: Color(0xFF16A34A),
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
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Real-time alerts processed',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
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
              color: Color(0xFF16A34A),
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
              const Icon(Icons.dns_rounded, color: Color(0xFF0F172A), size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'System & Storage Engine',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
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
                              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
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
                      const Icon(Icons.layers_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Redis Queue',
                              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
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
    final color = isPositive ? const Color(0xFF4ADE80) : const Color(0xFFF87171);

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
        color.withValues(alpha: 0.28),
        color.withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
