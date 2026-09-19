import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class SignalAlertOverlay extends StatefulWidget {
  final Map<String, dynamic> signalData;

  const SignalAlertOverlay({super.key, required this.signalData});

  static final AudioPlayer _player = AudioPlayer();

  static void show(BuildContext context, Map<String, dynamic> signalData) {
    // Sound and heavy vibration alert
    _triggerSoundAndHaptics();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Signal Alert',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return SignalAlertOverlay(signalData: signalData);
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  static void _triggerSoundAndHaptics() async {
    try {
      // Route audio to ALARM stream at MAXIMUM volume
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ));

      await _player.stop();
      await _player.setVolume(1.0);
      // 🔁 Loop the sound so it rings for the full 15 seconds
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/alert.wav'));
    } catch (e) {
      print('AudioPlayer asset error: $e');
    }

    try {
      // Trigger 5 repeated heavy vibration bursts
      for (int i = 0; i < 5; i++) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 180));
      }
    } catch (_) {}
  }

  /// Call this to stop the looping sound (on dismiss or auto-close)
  static Future<void> stopSound() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
    } catch (_) {}
  }

  @override
  State<SignalAlertOverlay> createState() => _SignalAlertOverlayState();
}

class _SignalAlertOverlayState extends State<SignalAlertOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _countdownController;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    // 15-second countdown timer for auto dismiss
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    _countdownController.reverse(from: 1.0);

    _dismissTimer = Timer(const Duration(seconds: 15), () {
      SignalAlertOverlay.stopSound(); // ⏹ Stop sound after 15s
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _countdownController.dispose();
    _dismissTimer?.cancel();
    SignalAlertOverlay.stopSound(); // ⏹ Stop sound when dismissed manually too
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final symbol = widget.signalData['symbol'] ?? widget.signalData['rawSymbol'] ?? 'NIFTY';
    final action = (widget.signalData['action'] ?? 'BUY').toString().toUpperCase();
    final isBuy = action == 'BUY';
    final price = widget.signalData['price'] ?? 0;

    final primaryBg = isBuy
        ? const [Color(0xFF047857), Color(0xFF10B981), Color(0xFF059669)]
        : const [Color(0xFFB91C1C), Color(0xFFEF4444), Color(0xFF991B1B)];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: primaryBg,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. Top Header Banner with Explicit CLOSE (X) Icon Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40), // Spacer for centering
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.sensors_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '🚨 LIVE SIGNAL ALERTS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Explicit CLOSE (X) Button
                    GestureDetector(
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. Center Action & Hero Symbol Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // BUY / SELL Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: isBuy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          action,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: isBuy ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Symbol
                      Text(
                        '$symbol',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Price
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'PRICE: ₹$price',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isBuy ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text(
                            'Auto-Executing via Zerodha Engine',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Bottom Progress Bar & Close Button Action
                Column(
                  children: [
                    const Text(
                      'AUTO DISMISSING IN 15 SECONDS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Countdown Progress Bar (15s)
                    AnimatedBuilder(
                      animation: _countdownController,
                      builder: (context, child) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _countdownController.value,
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // Tap X icon or button to dismiss
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: isBuy ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text(
                        'CLOSE ALERT NOW',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
