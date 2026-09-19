import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trading_provider.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();

    // Initialize connection and navigate after splash display
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAppInitialization();
    });
  }

  Future<void> _startAppInitialization() async {
    final provider = Provider.of<TradingProvider>(context, listen: false);
    
    // Wait minimum 2 seconds for splash visibility while provider connects
    await Future.wait([
      provider.refreshAll(silent: true),
      Future.delayed(const Duration(milliseconds: 2200)),
    ]);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => const MainScreen(),
        transitionsBuilder: (context, anim1, anim2, child) {
          return FadeTransition(opacity: anim1, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // Top Center Logo & App Name
            Positioned(
              top: MediaQuery.of(context).size.height * 0.16,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Electric Blue Stylized Bolt Icon
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          blurRadius: 24,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      size: 58,
                      color: Color(0xFF2563EB),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // App Title: "TradingView Algo"
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'TradingView ',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'Algo',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2563EB),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Climbing Candlestick Chart Graphic
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.58,
              child: CustomPaint(
                painter: CandlestickChartPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🎨 Custom Painter for Upward Trending Candlestick Chart
class CandlestickChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Candlestick data points (Open, High, Low, Close) relative heights (0.0 to 1.0)
    final List<Map<String, double>> candles = [
      {'o': 0.15, 'h': 0.22, 'l': 0.12, 'c': 0.20}, // Bull
      {'o': 0.20, 'h': 0.28, 'l': 0.18, 'c': 0.26}, // Bull
      {'o': 0.26, 'h': 0.32, 'l': 0.24, 'c': 0.30}, // Bull
      {'o': 0.30, 'h': 0.36, 'l': 0.27, 'c': 0.35}, // Bull
      {'o': 0.35, 'h': 0.38, 'l': 0.29, 'c': 0.31}, // Bear
      {'o': 0.31, 'h': 0.39, 'l': 0.28, 'c': 0.37}, // Bull
      {'o': 0.37, 'h': 0.42, 'l': 0.33, 'c': 0.35}, // Bear
      {'o': 0.35, 'h': 0.37, 'l': 0.28, 'c': 0.30}, // Bear
      {'o': 0.30, 'h': 0.34, 'l': 0.25, 'c': 0.28}, // Bear
      {'o': 0.28, 'h': 0.36, 'l': 0.26, 'c': 0.34}, // Bull
      {'o': 0.34, 'h': 0.44, 'l': 0.32, 'c': 0.42}, // Bull
      {'o': 0.42, 'h': 0.48, 'l': 0.40, 'c': 0.46}, // Bull
      {'o': 0.46, 'h': 0.55, 'l': 0.44, 'c': 0.52}, // Bull
      {'o': 0.52, 'h': 0.54, 'l': 0.46, 'c': 0.48}, // Bear
      {'o': 0.48, 'h': 0.52, 'l': 0.43, 'c': 0.45}, // Bear
      {'o': 0.45, 'h': 0.50, 'l': 0.41, 'c': 0.47}, // Bull
      {'o': 0.47, 'h': 0.51, 'l': 0.42, 'c': 0.44}, // Bear
      {'o': 0.44, 'h': 0.49, 'l': 0.39, 'c': 0.42}, // Bear
      {'o': 0.42, 'h': 0.52, 'l': 0.41, 'c': 0.50}, // Bull
      {'o': 0.50, 'h': 0.60, 'l': 0.48, 'c': 0.58}, // Bull
      {'o': 0.58, 'h': 0.65, 'l': 0.55, 'c': 0.62}, // Bull
      {'o': 0.62, 'h': 0.64, 'l': 0.56, 'c': 0.59}, // Bear
      {'o': 0.59, 'h': 0.68, 'l': 0.57, 'c': 0.66}, // Bull
      {'o': 0.66, 'h': 0.75, 'l': 0.64, 'c': 0.72}, // Bull
      {'o': 0.72, 'h': 0.82, 'l': 0.70, 'c': 0.80}, // Bull
      {'o': 0.80, 'h': 0.92, 'l': 0.78, 'c': 0.88}, // Strong Bull
      {'o': 0.88, 'h': 0.96, 'l': 0.85, 'c': 0.91}, // Strong Bull
    ];

    final int count = candles.length;
    final double stepX = width / (count + 1);
    final double candleWidth = stepX * 0.55;

    final greenColor = const Color(0xFF10B981);
    final redColor = const Color(0xFFEF4444);

    for (int i = 0; i < count; i++) {
      final candle = candles[i];
      final double openVal = candle['o']!;
      final double highVal = candle['h']!;
      final double lowVal = candle['l']!;
      final double closeVal = candle['c']!;

      final bool isBullish = closeVal >= openVal;
      final Color color = isBullish ? greenColor : redColor;

      final double cx = stepX * (i + 1);

      // Invert Y axis for Canvas (0 is top, height is bottom)
      final double yHigh = height * (1.0 - highVal);
      final double yLow = height * (1.0 - lowVal);
      final double yOpen = height * (1.0 - openVal);
      final double yClose = height * (1.0 - closeVal);

      final double topY = isBullish ? yClose : yOpen;
      final double bottomY = isBullish ? yOpen : yClose;
      final double bodyHeight = (bottomY - topY).clamp(3.0, height);

      // 1. Draw Wick Line
      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(cx, yHigh), Offset(cx, yLow), wickPaint);

      // 2. Draw Candle Body RRect
      final bodyPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final Rect bodyRect = Rect.fromLTWH(
        cx - (candleWidth / 2),
        topY,
        candleWidth,
        bodyHeight,
      );

      final RRect bodyRRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(2));
      canvas.drawRRect(bodyRRect, bodyPaint);
    }

    // 3. Draw Faint Volume Bars at Bottom Right
    final volumePaint = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    for (int i = 12; i < count; i++) {
      final double cx = stepX * (i + 1);
      final double volHeight = height * (0.05 + (i - 12) * 0.015);
      final Rect volRect = Rect.fromLTWH(
        cx - (candleWidth / 2),
        height - volHeight,
        candleWidth,
        volHeight,
      );
      canvas.drawRect(volRect, volumePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
