import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/trading_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Could not load .env file: $e");
  }
  await LocalNotificationService.init();
  runApp(const TradingViewAlgoApp());
}

class TradingViewAlgoApp extends StatelessWidget {
  const TradingViewAlgoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TradingProvider(),
      child: MaterialApp(
        title: 'TradingView Algo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
