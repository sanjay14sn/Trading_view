import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Production-ready service for exporting trade reports as CSV or PDF.
class ReportExportService {
  // ─── Helpers ────────────────────────────────────────────────────────────────

  static String _fmt(dynamic val) {
    if (val == null) return '--';
    return val.toString();
  }

  static String _fmtPrice(dynamic val) {
    if (val == null) return '--';
    try {
      return NumberFormat('#,##0.0#').format((val as num).toDouble());
    } catch (_) {
      return val.toString();
    }
  }

  static String _fmtPoints(double? pts) {
    if (pts == null) return 'Pending';
    return '${pts >= 0 ? '+' : ''}${pts.toStringAsFixed(1)}';
  }

  static String _fmtTime(dynamic val) {
    if (val == null) return '--';
    try {
      DateTime dt;
      if (val is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(val).toLocal();
      } else {
        dt = DateTime.parse(val.toString()).toLocal();
      }
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return val.toString();
    }
  }

  static String _status(Map<String, dynamic> r) {
    final pts = r['points'] as double?;
    if (pts == null) return 'OPEN';
    if (pts > 0) return 'WIN';
    if (pts < 0) return 'LOSS';
    return 'EVEN';
  }

  static String _type(Map<String, dynamic> r) =>
      (r['entryAction'] ?? 'BUY').toString().toUpperCase() == 'BUY'
          ? 'CALL'
          : 'PUT';

  // ─── Summary Stats ───────────────────────────────────────────────────────────

  static Map<String, dynamic> _buildStats(List<Map<String, dynamic>> reports) {
    final closed = reports.where((r) => r['points'] != null).toList();
    final wins = closed.where((r) => (r['points'] as double) > 0).length;
    final losses = closed.where((r) => (r['points'] as double) < 0).length;
    final totalPnl = closed.fold<double>(
        0, (sum, r) => sum + (r['points'] as double));
    final winRate = closed.isEmpty ? 0.0 : (wins / closed.length) * 100;
    return {
      'total': reports.length,
      'closed': closed.length,
      'open': reports.length - closed.length,
      'wins': wins,
      'losses': losses,
      'totalPnl': totalPnl,
      'winRate': winRate,
    };
  }

  // ─── CSV Export ─────────────────────────────────────────────────────────────

  static Future<void> exportCsv({
    required List<Map<String, dynamic>> reports,
    required String label, // e.g. "All Trades", "NIFTY – Profits"
  }) async {
    final stats = _buildStats(reports);
    final now = DateFormat('dd-MMM-yyyy HH:mm').format(DateTime.now());

    final rows = <List<dynamic>>[
      // ── Meta ──
      ['TradingView Signal Report'],
      ['Generated', now],
      ['Filter', label],
      ['Total Trades', stats['total']],
      ['Closed', stats['closed']],
      ['Open', stats['open']],
      ['Wins', stats['wins']],
      ['Losses', stats['losses']],
      ['Net P&L (Points)', _fmtPoints(stats['totalPnl'] as double)],
      ['Win Rate', '${(stats['winRate'] as double).toStringAsFixed(1)}%'],
      [],
      // ── Headers ──
      [
        '#',
        'Symbol',
        'Type',
        'Status',
        'Entry Action',
        'Buy Price',
        'Buy Time',
        'Sell Price',
        'Sell Time',
        'Points P&L',
        'Trade ID',
        'Entry Signal ID',
        'Exit Signal ID',
      ],
    ];

    for (var i = 0; i < reports.length; i++) {
      final r = reports[i];
      final isBuyEntry =
          (r['entryAction'] ?? 'BUY').toString().toUpperCase() == 'BUY';
      final buyPrice = isBuyEntry ? r['entryPrice'] : r['exitPrice'];
      final buyTime = isBuyEntry ? r['entryTime'] : r['exitTime'];
      final sellPrice = isBuyEntry ? r['exitPrice'] : r['entryPrice'];
      final sellTime = isBuyEntry ? r['exitTime'] : r['entryTime'];

      rows.add([
        i + 1,
        _fmt(r['symbol']),
        _type(r),
        _status(r),
        _fmt(r['entryAction']),
        _fmtPrice(buyPrice),
        _fmtTime(buyTime),
        _fmtPrice(sellPrice),
        _fmtTime(sellTime),
        _fmtPoints(r['points'] as double?),
        _fmt(r['tradeId']),
        _fmt(r['entrySignalId'] ?? r['id']),
        _fmt(r['exitSignalId']),
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final safeLabel = label.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
    final fileName =
        'TradeReport_${safeLabel}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Trade Report – $label',
      text: 'Trade Report | $label | $now',
    );
  }

  // ─── PDF Export ─────────────────────────────────────────────────────────────

  static Future<void> exportPdf({
    required List<Map<String, dynamic>> reports,
    required String label,
  }) async {
    final stats = _buildStats(reports);
    final now = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final doc = pw.Document();

    // ── Color palette ──
    const primaryColor = PdfColor.fromInt(0xFF0F172A);
    const accentGreen = PdfColor.fromInt(0xFF16A34A);
    const accentRed = PdfColor.fromInt(0xFFDC2626);
    const surfaceGrey = PdfColor.fromInt(0xFFF8FAFC);
    const borderGrey = PdfColor.fromInt(0xFFE2E8F0);
    const textMuted = PdfColor.fromInt(0xFF64748B);

    final pnl = stats['totalPnl'] as double;
    final pnlColor = pnl >= 0 ? accentGreen : accentRed;

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          buildBackground: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: PdfColors.white),
          ),
        ),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Title Bar ──
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const pw.BoxDecoration(color: primaryColor),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TRADE REPORT',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        label,
                        style: const pw.TextStyle(
                          color: PdfColor.fromInt(0xFF94A3B8),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    now,
                    style: const pw.TextStyle(
                      color: PdfColor.fromInt(0xFF94A3B8),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // ── Summary Stats Grid ──
            pw.Row(
              children: [
                _pdfStatBox('Total Trades', '${stats['total']}', PdfColors.blueGrey50, primaryColor),
                pw.SizedBox(width: 6),
                _pdfStatBox('Wins', '${stats['wins']}', const PdfColor.fromInt(0xFFDCFCE7), accentGreen),
                pw.SizedBox(width: 6),
                _pdfStatBox('Losses', '${stats['losses']}', const PdfColor.fromInt(0xFFFEE2E2), accentRed),
                pw.SizedBox(width: 6),
                _pdfStatBox(
                  'Win Rate',
                  '${(stats['winRate'] as double).toStringAsFixed(1)}%',
                  const PdfColor.fromInt(0xFFEFF6FF),
                  const PdfColor.fromInt(0xFF2563EB),
                ),
                pw.SizedBox(width: 6),
                _pdfStatBox(
                  'Net P&L (Pts)',
                  _fmtPoints(pnl),
                  pnl >= 0 ? const PdfColor.fromInt(0xFFDCFCE7) : const PdfColor.fromInt(0xFFFEE2E2),
                  pnlColor,
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // ── Table Header ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: primaryColor,
              child: pw.Row(
                children: [
                  _pdfHeaderCell('#', flex: 1),
                  _pdfHeaderCell('Symbol', flex: 4),
                  _pdfHeaderCell('Type', flex: 2),
                  _pdfHeaderCell('Buy Price', flex: 4),
                  _pdfHeaderCell('Buy Time', flex: 6),
                  _pdfHeaderCell('Sell Price', flex: 4),
                  _pdfHeaderCell('Sell Time', flex: 6),
                  _pdfHeaderCell('P&L (Pts)', flex: 3, align: pw.TextAlign.right),
                  _pdfHeaderCell('Status', flex: 3, align: pw.TextAlign.right),
                ],
              ),
            ),
          ],
        ),
        build: (ctx) {
          final rows = <pw.Widget>[];
          for (var i = 0; i < reports.length; i++) {
            final r = reports[i];
            final isBuyEntry =
                (r['entryAction'] ?? 'BUY').toString().toUpperCase() == 'BUY';
            final buyPrice = isBuyEntry ? r['entryPrice'] : r['exitPrice'];
            final buyTime = isBuyEntry ? r['entryTime'] : r['exitTime'];
            final sellPrice = isBuyEntry ? r['exitPrice'] : r['entryPrice'];
            final sellTime = isBuyEntry ? r['exitTime'] : r['entryTime'];
            final pts = r['points'] as double?;
            final status = _status(r);
            final statusColor = status == 'WIN'
                ? accentGreen
                : (status == 'LOSS' ? accentRed : textMuted);
            final rowBg = i.isEven ? surfaceGrey : PdfColors.white;

            rows.add(
              pw.Container(
                color: rowBg,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: borderGrey, width: 0.5),
                  ),
                ),
                child: pw.Row(
                  children: [
                    _pdfCell('${i + 1}', flex: 1, muted: true),
                    _pdfCell(_fmt(r['symbol']), flex: 4, bold: true),
                    _pdfCell(
                      _type(r),
                      flex: 2,
                      color: isBuyEntry ? accentGreen : accentRed,
                      bold: true,
                    ),
                    _pdfCell(_fmtPrice(buyPrice), flex: 4),
                    _pdfCell(_fmtTime(buyTime), flex: 6, muted: true),
                    _pdfCell(_fmtPrice(sellPrice), flex: 4),
                    _pdfCell(_fmtTime(sellTime), flex: 6, muted: true),
                    _pdfCell(
                      _fmtPoints(pts),
                      flex: 3,
                      align: pw.TextAlign.right,
                      color: pts == null
                          ? textMuted
                          : (pts > 0 ? accentGreen : (pts < 0 ? accentRed : textMuted)),
                      bold: true,
                    ),
                    _pdfCell(
                      status,
                      flex: 3,
                      align: pw.TextAlign.right,
                      color: statusColor,
                      bold: true,
                    ),
                  ],
                ),
              ),
            );
          }

          if (reports.isEmpty) {
            rows.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                alignment: pw.Alignment.center,
                child: pw.Text('No trade records found.',
                    style: const pw.TextStyle(color: textMuted)),
              ),
            );
          }

          return rows;
        },
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TradingView Signal Engine  •  Confidential',
                style: const pw.TextStyle(fontSize: 7, color: textMuted),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: textMuted),
              ),
            ],
          ),
        ),
      ),
    );

    final pdfBytes = await doc.save();
    final safeLabel = label.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
    final fileName =
        'TradeReport_${safeLabel}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Trade Report – $label',
      text: 'Trade Report | $label | $now',
    );
  }

  // ─── PDF Widget Helpers ──────────────────────────────────────────────────────

  static pw.Widget _pdfStatBox(
      String label, String value, PdfColor bg, PdfColor valueColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(
                    fontSize: 7, color: PdfColor.fromInt(0xFF64748B))),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: valueColor)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _pdfHeaderCell(String text,
      {int flex = 4, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _pdfCell(
    String text, {
    int flex = 4,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
    bool bold = false,
    bool muted = false,
  }) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        textAlign: align,
        overflow: pw.TextOverflow.clip,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ??
              (muted
                  ? const PdfColor.fromInt(0xFF94A3B8)
                  : const PdfColor.fromInt(0xFF0F172A)),
        ),
      ),
    );
  }
}
