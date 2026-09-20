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
  DateTime? _selectedCustomDate; // Picked via top calendar button
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

  /// Pairs BUY ↔ SELL signals per symbol in continuous reversal mode
  /// (First signal BUY = CALL, First signal SELL = PUT)
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

            // Close current position
            reports.add({
              'id': openEntry['id'] ?? id,
              'entrySignalId': openEntry['id']?.toString(),
              'exitSignalId': id?.toString(),
              'tradeId': openEntry['tradeId']?.toString() ?? sig['tradeId']?.toString(),
              'symbol': symbol,
              'entryAction': entryAction,
              'type': entryAction == 'BUY' ? 'CALL' : 'PUT',
              'exitAction': action,
              'entryPrice': entryPrice,
              'exitPrice': exitPrice,
              'points': pointsDiff,
              'entryTime': openEntry['entryTime'],
              'exitTime': receivedAt,
            });

            // Automatic Reversal: Exit signal opens the next container!
            openEntry = {
              'id': id,
              'tradeId': sig['tradeId'],
              'symbol': symbol,
              'entryAction': action,
              'entryPrice': price,
              'entryTime': receivedAt,
            };
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
        final entryAction = openEntry['entryAction'] as String;
        reports.add({
          'id': openEntry['id'],
          'entrySignalId': openEntry['id']?.toString(),
          'exitSignalId': null,
          'tradeId': openEntry['tradeId']?.toString(),
          'symbol': symbol,
          'entryAction': entryAction,
          'type': entryAction == 'BUY' ? 'CALL' : 'PUT',
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

      // 3. Custom Date Filter from Calendar Button
      if (_selectedCustomDate != null) {
        final entryDt = _parseDateTime(r['entryTime']);
        if (entryDt == null ||
            entryDt.year != _selectedCustomDate!.year ||
            entryDt.month != _selectedCustomDate!.month ||
            entryDt.day != _selectedCustomDate!.day) {
          return false;
        }
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

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
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
                      _actionIconButton(
                        Icons.calendar_today_rounded,
                        () => _showDatePicker(context),
                        isHighlighted: _selectedCustomDate != null,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Filter Row: Segmented Control & Symbol Selector ──
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

              // ── Active Date Filter Badge Chip (if calendar date selected) ──
              if (_selectedCustomDate != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event_rounded, size: 14, color: Color(0xFF1D61E7)),
                          const SizedBox(width: 6),
                          Text(
                            'Date: ${DateFormat('dd MMM yyyy').format(_selectedCustomDate!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D61E7),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _selectedCustomDate = null),
                            child: const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFF1D61E7)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              // ── Recent Trades Header & Sort Dropdown ──────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trade Log (${filteredReports.length})',
                    style: const TextStyle(
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

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionIconButton(IconData icon, VoidCallback onPressed, {bool isHighlighted = false}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFDCFCE7) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: isHighlighted ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: isHighlighted ? const Color(0xFF15803D) : const Color(0xFF334155)),
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
            color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _symbolDropdown(List<String> symbols) {
    final cleanSymbols = ['ALL', ...symbols.where((s) => s != 'ALL' && s.isNotEmpty).toSet()];
    final activeValue = cleanSymbols.contains(_selectedSymbol) ? _selectedSymbol : 'ALL';

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: activeValue,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          onChanged: (val) {
            if (val != null) setState(() => _selectedSymbol = val);
          },
          items: cleanSymbols.map((sym) {
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

  Widget _sortDropdown() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortOrder,
          icon: const Icon(Icons.unfold_more_rounded, color: Color(0xFF64748B), size: 15),
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
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
    );
  }

  Widget _buildTradeCard(BuildContext context, TradingProvider provider, Map<String, dynamic> report) {
    final symbol = (report['symbol'] ?? 'UNKNOWN').toString();
    final entryAction = (report['entryAction'] ?? 'BUY').toString().toUpperCase();
    final isBuyEntry = entryAction == 'BUY';
    final points = report['points'] as double?;
    final isClosed = points != null;
    final isWin = isClosed && points > 0;
    final isLoss = isClosed && points < 0;

    // BUY Details (whether BUY came first or second)
    final dynamic rawBuyPrice = isBuyEntry ? report['entryPrice'] : report['exitPrice'];
    final dynamic rawBuyTime = isBuyEntry ? report['entryTime'] : report['exitTime'];
    final buyPriceStr = rawBuyPrice != null ? NumberFormat('#,##0.0#').format(rawBuyPrice) : '--';
    final buyTimeStr = _formatTime(rawBuyTime);

    // SELL Details (whether SELL came first or second)
    final dynamic rawSellPrice = isBuyEntry ? report['exitPrice'] : report['entryPrice'];
    final dynamic rawSellTime = isBuyEntry ? report['exitTime'] : report['entryTime'];
    final sellPriceStr = rawSellPrice != null ? NumberFormat('#,##0.0#').format(rawSellPrice) : '--';
    final sellTimeStr = _formatTime(rawSellTime);

    // Primary Container Time (Time of initial entry)
    final primaryTimeStr = _formatTime(report['entryTime']);

    // Status Badge colors (Green / Red / Grey)
    Color statusBg = const Color(0xFFF1F5F9);
    Color statusText = const Color(0xFF475569);
    String statusLabel = 'OPEN';
    if (isClosed) {
      if (isWin) {
        statusBg = const Color(0xFFDCFCE7); // Soft Green
        statusText = const Color(0xFF15803D); // Dark Green
        statusLabel = 'WIN';
      } else if (isLoss) {
        statusBg = const Color(0xFFFEE2E2); // Soft Red
        statusText = const Color(0xFFB91C1C); // Dark Red
        statusLabel = 'LOSS';
      } else {
        statusBg = const Color(0xFFF1F5F9); // Soft Grey
        statusText = const Color(0xFF475569);
        statusLabel = 'EVEN';
      }
    }

    // CALL/PUT Tag Colors (Green / Red)
    final tagBg = isBuyEntry ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final tagText = isBuyEntry ? const Color(0xFF15803D) : const Color(0xFFB91C1C);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            // Top Row: Avatar + Symbol + Action Tag (CALL / PUT) + Status Badge + Delete Menu
            Row(
              children: [
                // Asset Icon (Green/Red)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: tagBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBuyEntry ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: tagText,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              symbol,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tagBg,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              isBuyEntry ? 'CALL' : 'PUT',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: tagText,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        primaryTimeStr,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Badge Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: statusText,
                    ),
                  ),
                ),

                const SizedBox(width: 2),

                // Delete Action Menu
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF94A3B8)),
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
                          Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 16),
                          SizedBox(width: 6),
                          Text('Delete Trade Pair', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),

            // Middle Row: BUY (Price + Time), SELL (Price + Time), Result (Pts + Status)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _metricColumn(
                  'BUY',
                  buyPriceStr,
                  buyTimeStr.isNotEmpty ? buyTimeStr : 'Pending',
                  CrossAxisAlignment.start,
                  labelColor: const Color(0xFF16A34A),
                ),
                _metricColumn(
                  'SELL',
                  sellPriceStr,
                  sellTimeStr.isNotEmpty ? sellTimeStr : 'Pending',
                  CrossAxisAlignment.center,
                  labelColor: const Color(0xFFDC2626),
                ),
                _metricColumn(
                  'Result (Pts)',
                  points != null
                      ? '${points >= 0 ? '+' : ''}${points.toStringAsFixed(1)}'
                      : 'Pending',
                  isClosed ? statusLabel : 'In Progress',
                  CrossAxisAlignment.end,
                  valueColor: points != null
                      ? (points > 0 ? const Color(0xFF16A34A) : (points < 0 ? const Color(0xFFDC2626) : const Color(0xFF475569)))
                      : const Color(0xFF475569),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricColumn(
    String label,
    String value,
    String timeText,
    CrossAxisAlignment alignment, {
    Color? labelColor,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: labelColor ?? const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          timeText,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: const [
          Icon(Icons.query_stats_rounded, size: 54, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text(
            'No Trade Reports Found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          SizedBox(height: 4),
          Text(
            'Signals will automatically pair into reports once completed.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedCustomDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedCustomDate = picked);
    }
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
