import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';

class TradingProvider extends ChangeNotifier with WidgetsBindingObserver {
  late ApiService _apiService;
  late SocketService _socketService;

  late String _serverUrl;
  bool _isLoading = false;
  bool _isServerOnline = false;

  Map<String, dynamic>? _dashboardData;
  List<dynamic> _trades = [];
  List<dynamic> _signals = [];

  Timer? _autoRefreshTimer;

  String get serverUrl => _serverUrl;
  bool get isLoading => _isLoading;
  bool get isServerOnline => _isServerOnline;
  bool get isSocketConnected => _socketService.isConnected;

  Map<String, dynamic>? get dashboardData => _dashboardData;
  List<dynamic> get trades => _trades;
  List<dynamic> get signals => _signals;

  List<dynamic> get activeTrades => _trades.where((t) => t['status'] == 'OPEN' || t['status'] == 'PENDING' || t['status'] == 'QUEUED').toList();

  double get dailyPnl {
    if (_dashboardData != null && _dashboardData!['dailyPnl'] != null) {
      return (_dashboardData!['dailyPnl'] as num).toDouble();
    }
    return 0.0;
  }

  int get totalSignalsToday => _dashboardData?['totalSignalsToday'] ?? 0;
  int get activePositions => _dashboardData?['activePositions'] ?? 0;

  TradingProvider() {
    // Default URL from dotenv or fallback
    _serverUrl = dotenv.env['SERVER_URL'] ??
        dotenv.env['API_BASE_URL'] ??
        'https://apitrading.iqsync.in';
    _apiService = ApiService(baseUrl: _serverUrl);
    _socketService = SocketService();

    WidgetsBinding.instance.addObserver(this);
    _setupSocketListeners();
    initConnection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('⚡ Mobile app resumed from background/cold state. Re-synchronizing...');
      refreshAll(silent: true);
      if (PushService.deviceToken != null) {
        PushService.registerTokenWithBackend(_serverUrl, PushService.deviceToken!);
      }
    }
  }

  Function(Map<String, dynamic> data)? onSignalAlertReceived;

  void _setupSocketListeners() {
    _socketService.onConnectionChanged = () {
      notifyListeners();
    };

    _socketService.onSignalReceived = (data) {
      if (data != null) {
        final mapData = Map<String, dynamic>.from(data as Map);
        if (!mapData.containsKey('receivedAt') || mapData['receivedAt'] == null) {
          mapData['receivedAt'] = DateTime.now().toIso8601String();
        }
        _signals.insert(0, mapData);
        fetchDashboard();
        notifyListeners();

        // High priority system push notification (works in background & lock screen)
        LocalNotificationService.showSignalNotification(mapData);

        // Full screen 15s popup
        onSignalAlertReceived?.call(mapData);
      }
    };

    _socketService.onOrderPlaced = (data) {
      fetchTrades();
      fetchDashboard();
    };

    _socketService.onTradeClosed = (data) {
      fetchTrades();
      fetchDashboard();
    };
  }

  Future<void> initConnection() async {
    await refreshAll();

    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshAll(silent: true);
    });
  }

  Future<void> updateServerUrl(String newUrl) async {
    String formattedUrl = newUrl.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'http://$formattedUrl';
    }
    _serverUrl = formattedUrl;
    _apiService.updateBaseUrl(_serverUrl);
    _socketService.connect(_serverUrl);
    await refreshAll();
  }

  Future<void> _autoDiscoverServer() async {
    final candidateUrls = [
      'https://apitrading.iqsync.in',
      'http://13.205.189.169:3010',
      'https://grained-nontelegraphical-gwen.ngrok-free.dev',
      'http://10.255.198.129:3001',
      (!kIsWeb && Platform.isAndroid) ? 'http://10.0.2.2:3001' : 'http://localhost:3001',
      'http://localhost:3001',
    ];

    for (final candidate in candidateUrls) {
      if (candidate == _serverUrl) continue;
      final tempApi = ApiService(baseUrl: candidate);
      final isAlive = await tempApi.checkHealth();
      if (isAlive) {
        print('⚡ Auto-discovered active server at $candidate');
        _serverUrl = candidate;
        _apiService.updateBaseUrl(_serverUrl);
        _socketService.connect(_serverUrl);
        return;
      }
    }
  }

  Future<void> refreshAll({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    _isServerOnline = await _apiService.checkHealth() || _socketService.isConnected;

    // Only attempt candidate auto-discovery on explicit non-silent refresh/startup
    if (!_isServerOnline && !silent) {
      await _autoDiscoverServer();
      _isServerOnline = await _apiService.checkHealth() || _socketService.isConnected;
    }

    if (_isServerOnline) {
      if (!_socketService.isConnected) {
        _socketService.connect(_serverUrl);
      }
      await Future.wait([
        fetchDashboard(),
        fetchTrades(),
        fetchSignals(),
      ]);
    } else {
      _dashboardData = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchDashboard() async {
    final data = await _apiService.getDashboard();
    if (data != null) {
      _dashboardData = data;
      notifyListeners();
    }
  }

  Future<void> fetchTrades() async {
    final list = await _apiService.getTrades();
    _trades = list;
    notifyListeners();
  }

  Future<void> fetchSignals() async {
    final list = await _apiService.getSignals();
    _signals = list;
    notifyListeners();
  }

  Future<bool> closeTradeManually(String tradeId) async {
    final res = await _apiService.closeTrade(tradeId);
    if (res != null) {
      await fetchTrades();
      await fetchDashboard();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _socketService.disconnect();
    super.dispose();
  }
}
