import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trading_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedOutcome = 'ALL'; // ALL, PROFITS, LOSSES
  String _selectedSymbol = 'ALL'; // ALL or specific symbol
  String _selectedDateRange = 'TODAY'; // TODAY, THIS_WEEK, THIS_MONTH, CUSTOM
  String _sortOrder = 'LATEST'; // LATEST, OLDEST, HIGHEST_PNL

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
    return DateFormat('dd MMM, hh:mm a').format(dt);
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
            'tradeId': sig['tradeId'],
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
              'entrySignalId': openEntry['id']?.toString(),
              'exitSignalId': id?.toString(),
              'tradeId': openEntry['tradeId']?.toString() ?? sig['tradeId']?.toString(),
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
              'tradeId': sig['tradeId'],
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
          'entrySignalId': openEntry['id']?.toString(),
          'exitSignalId': null,
          'tradeId': openEntry['tradeId']?.toString(),
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

    return reports;
  }

  List<Map<String, dynamic>> _filterAndSortReports(List<Map<String, dynamic>> rawReports) {
    final now = DateTime.now();

    List<Map<String, dynamic>> filtered = rawReports.where((r) {
      // 1. Outcome Filter
      if (_selectedOutcome == 'PROFITS' && (r['points'] == null || (r['points'] as double) <= 0)) {
        return false;
      }
      if (_selectedOutcome == 'LOSSES' && (r['points'] == null || (r['points'] as double) >= 0)) {
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
      } else if (_selectedDateRange == 'THIS_MONTH' && entryDt != null) {
        if (entryDt.year != now.year || entryDt.month != now.month) return false;
      }

      return true;
    }).toList();

    // Sorting
    filtered.sort((a, b) {
      if (_sortOrder == 'HIGHEST_PNL') {
        final aPoints = (a['points'] as double?) ?? -999999;
        final bPoints = (b['points'] as double?) ?? -999999;
        return bPoints.compareTo(aPoints);
      } else if (_sortOrder == 'OLDEST') {
        final aTime = _parseDateTime(a['entryTime']);
        final bTime = _parseDateTime(b['entryTime']);
        if (aTime == null || bTime == null) return 0;
        return aTime.compareTo(bTime);
      } else {
        // LATEST
        final aTime = _parseDateTime(a['entryTime']);
        final bTime = _parseDateTime(b['entryTime']);
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TradingProvider>(context);
    final allReports = _buildTradeReports(provider.signals);
    final filteredReports = _filterAndSortReports(allReports);

    // Dynamic symbols list
    final availableSymbols = ['ALL', ...allReports.map((r) => r['symbol'] as String).toSet()];

    // Metrics calculation
    final closedReports = filteredReports.where((r) => r['points'] != null).toList();
    final totalPoints = closedReports.fold<double>(0, (sum, r) => sum + (r['points'] as double));
    final winners = closedReports.where((r) => (r['points'] as double) > 0).length;
    final losers = closedReports.where((r) => (r['points'] as double) < 0).length;
    final totalTradesCount = filteredReports.length;
    final winRate = closedReports.isNotEmpty
        ? ((winners / closedReports.length) * 100).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1D61E7),
        elevation: 6,
        icon: const Icon(Icons.add, color: Colors.white, size: 22),
        label: const Text('Add Trade', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        onPressed: () => _showAddTradeDialog(context, provider),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.refreshAll(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── Header Title Row ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trade Reports',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Analyze your trades and track performance',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      _actionIconButton(Icons.refresh_rounded, () => provider.refreshAll()),
                      const SizedBox(width: 8),
                      _actionIconButton(Icons.calendar_today_rounded, () => _showDatePicker(context)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Filter Row 1: Segmented Control & Symbol Selector ──
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _segmentedTab('ALL', 'All'),
                          _segmentedTab('PROFITS', 'Profits'),
                          _segmentedTab('LOSSES', 'Losses'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _symbolDropdown(availableSymbols),
                ],
              ),

              const SizedBox(height: 10),

              // ── Filter Row 2: Date Filters ────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _datePill('TODAY', 'Today'),
                    const SizedBox(width: 8),
                    _datePill('THIS_WEEK', 'This Week'),
                    const SizedBox(width: 8),
                    _datePill('THIS_MONTH', 'This Month'),
                    const SizedBox(width: 8),
                    _datePill('CUSTOM', 'Custom 📅'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Performance Analytics Card (Total P&L) ────────────
              _buildPerformanceCard(totalPoints, totalTradesCount, winners, losers, winRate, availableSymbols),

              const SizedBox(height: 20),

              // ── Recent Trades Header & Sort Dropdown ──────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Trades',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  _sortDropdown(),
                ],
              ),

              const SizedBox(height: 12),

              // ── Trade Report Cards List ───────────────────────────
              if (filteredReports.isEmpty)
                _buildEmptyState()
              else
                ...filteredReports.map((report) => _buildTradeCard(context, provider, report)),

              const SizedBox(height: 80), // bottom padding for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionIconButton(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: const Color(0xFF334155)),
        onPressed: onPressed,
      ),
    );
  }

  Widget _segmentedTab(String key, String label) {
    final isSelected = _selectedOutcome == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedOutcome = key),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1D61E7) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _symbolDropdown(List<String> symbols) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSymbol,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          onChanged: (val) {
            if (val != null) setState(() => _selectedSymbol = val);
          },
          items: symbols.map((sym) {
            final displayLabel = sym == 'ALL' ? 'All Pairs' : sym;
            return DropdownMenuItem<String>(
              value: sym,
              child: Text(displayLabel),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _datePill(String key, String label) {
    final isSelected = _selectedDateRange == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedDateRange = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1D61E7) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1D61E7) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(
      double totalPoints, int totalTrades, int wins, int losses, String winRate, List<String> symbols) {
    final isPositive = totalPoints >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFFDF5), Color(0xFFF0FDF4), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.06),
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
              const Text(
                'Total P&L (Points)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF047857),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedSymbol == 'ALL' ? 'All Pairs' : _selectedSymbol,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Big P&L readout & Mini Sparkline Graph
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isPositive ? '+' : ''}${NumberFormat('#,##0.0').format(totalPoints)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF047857),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                size: 12,
                                color: const Color(0xFF15803D),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${isPositive ? '+' : ''}12.4%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'vs previous period',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Sparkline graph
              SizedBox(
                width: 110,
                height: 50,
                child: CustomPaint(
                  painter: _SparklinePainter(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 4 Stat Grid
          Row(
            children: [
              _statGridCard(
                icon: Icons.bar_chart_rounded,
                iconColor: const Color(0xFF2563EB),
                value: '$totalTrades',
                label: 'Total Trades',
                bg: Colors.white,
              ),
              const SizedBox(width: 8),
              _statGridCard(
                icon: Icons.keyboard_arrow_up_rounded,
                iconColor: const Color(0xFF16A34A),
                value: '$wins',
                label: 'Wins',
                bg: Colors.white,
              ),
              const SizedBox(width: 8),
              _statGridCard(
                icon: Icons.keyboard_arrow_down_rounded,
                iconColor: const Color(0xFFDC2626),
                value: '$losses',
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortOrder,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              onChanged: (val) {
                if (val != null) setState(() => _sortOrder = val);
              },
              items: const [
                DropdownMenuItem(value: 'LATEST', child: Text('Latest First')),
                DropdownMenuItem(value: 'OLDEST', child: Text('Oldest First')),
                DropdownMenuItem(value: 'HIGHEST_PNL', child: Text('Highest P&L')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeCard(BuildContext context, TradingProvider provider, Map<String, dynamic> report) {
    final symbol = report['symbol'] as String;
    final entryAction = report['entryAction'] as String;
    final exitAction = report['exitAction'] as String;
    final entryPrice = report['entryPrice'] as double;
    final exitPrice = report['exitPrice'] as double?;
    final double? points = report['points'] as double?;
    final isOpen = exitAction == 'OPEN';
    final isWin = (points ?? 0) > 0;
    final isLoss = (points ?? 0) < 0;

    final String timeStr = _formatTime(report['entryTime']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card Header: Avatar + Symbol + BUY Tag + Chevron/Delete Menu
          Row(
            children: [
              // Crypto / Asset Avatar Circle
              _assetAvatar(symbol),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      symbol,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              // Action Badge (BUY / SELL)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: entryAction == 'BUY' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  entryAction,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: entryAction == 'BUY' ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              PopupMenuButton<String>(
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'delete') {
                    _confirmDeleteTrade(context, provider, report);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Delete Record', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3-Column Metrics Row: Entry Price | Exit Price | P&L (Points) + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Entry Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Entry Price', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text('₹${NumberFormat('#,##0.0').format(entryPrice)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                ],
              ),

              // Exit Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Exit Price', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(
                    exitPrice != null ? '₹${NumberFormat('#,##0.0').format(exitPrice)}' : '-',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),

              // P&L (Points)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('P&L (Points)', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(
                    points != null ? '${points >= 0 ? '+' : ''}${points.toStringAsFixed(0)}' : '-',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isOpen
                          ? const Color(0xFF94A3B8)
                          : isWin
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),

              // Status Pill (WIN / LOSS / OPEN)
              _statusBadge(isOpen, isWin, isLoss),
            ],
          ),
        ],
      ),
    );
  }

  Widget _assetAvatar(String symbol) {
    bool isBtc = symbol.toUpperCase().contains('BTC');
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isBtc ? const Color(0xFFF7931A) : const Color(0xFF1D61E7),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: isBtc
          ? const Text('₿', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20))
          : Text(
              symbol.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
    );
  }

  Widget _statusBadge(bool isOpen, bool isWin, bool isLoss) {
    String text = 'OPEN';
    Color bg = const Color(0xFFEFF6FF);
    Color fg = const Color(0xFF2563EB);

    if (!isOpen) {
      if (isWin) {
        text = 'WIN';
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
      } else {
        text = 'LOSS';
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 56, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text(
            'No recent trades found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
          ),
          SizedBox(height: 4),
          Text(
            'Reports will populate as signals arrive.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  void _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = 'CUSTOM');
    }
  }

  void _showAddTradeDialog(BuildContext context, TradingProvider provider) {
    final symbolCtrl = TextEditingController(text: 'BTCUSDT');
    final priceCtrl = TextEditingController(text: '81280.0');
    String action = 'BUY';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Manual Signal/Trade', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: symbolCtrl,
              decoration: const InputDecoration(labelText: 'Symbol (e.g. BTCUSDT, NIFTY)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: action,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'BUY', child: Text('BUY Signal')),
                DropdownMenuItem(value: 'SELL', child: Text('SELL Signal')),
              ],
              onChanged: (v) {
                if (v != null) action = v;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D61E7)),
            onPressed: () {
              Navigator.pop(ctx);
              provider.refreshAll();
            },
            child: const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTrade(BuildContext context, TradingProvider provider, Map<String, dynamic> report) async {
    final symbol = report['symbol'] as String? ?? 'Trade';
    final entrySignalId = report['entrySignalId']?.toString() ?? report['id']?.toString();
    final exitSignalId = report['exitSignalId']?.toString();
    final tradeId = report['tradeId']?.toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete $symbol Record?'),
        content: const Text('This will permanently delete this trade report pair from history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.deleteReportPair(
        entrySignalId: entrySignalId,
        exitSignalId: exitSignalId,
        tradeId: tradeId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trade report record deleted successfully.')),
        );
      }
    }
  }
}

/// CustomPainter to draw smooth green sparkline wave graph in Total P&L Card
class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final paintLine = Paint()
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF10B981);

    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.2, size.height * 0.65),
      Offset(size.width * 0.4, size.height * 0.75),
      Offset(size.width * 0.6, size.height * 0.35),
      Offset(size.width * 0.8, size.height * 0.45),
      Offset(size.width, size.height * 0.15),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
    }

    // Fill Gradient under curve
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF10B981).withValues(alpha: 0.3),
          const Color(0xFF10B981).withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
