import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  io.Socket? socket;
  bool isConnected = false;
  Timer? _reconnectCheckTimer;
  String? _currentServerUrl;

  Function(dynamic data)? onSignalReceived;
  Function(dynamic data)? onOrderPlaced;
  Function(dynamic data)? onTradeClosed;
  Function()? onConnectionChanged;

  void connect(String serverUrl) {
    disconnect();

    _currentServerUrl = serverUrl.trim();
    if (_currentServerUrl!.endsWith('/')) {
      _currentServerUrl = _currentServerUrl!.substring(0, _currentServerUrl!.length - 1);
    }

    try {
      socket = io.io(
        _currentServerUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(99999)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setTimeout(10000)
            .build(),
      );

      socket?.onConnect((_) {
        print('⚡ WebSocket Connected to $_currentServerUrl');
        isConnected = true;
        onConnectionChanged?.call();
      });

      socket?.onDisconnect((_) {
        print('🔌 WebSocket Disconnected');
        isConnected = false;
        onConnectionChanged?.call();
      });

      socket?.onConnectError((err) {
        print('⚠️ WebSocket Connect Error: $err');
        isConnected = false;
        onConnectionChanged?.call();
      });

      socket?.on('signal_received', (data) {
        print('🎯 Signal received event: $data');
        onSignalReceived?.call(data);
      });

      socket?.on('order_placed', (data) {
        print('✅ Order placed event: $data');
        onOrderPlaced?.call(data);
      });

      socket?.on('trade_closed', (data) {
        print('💰 Trade closed event: $data');
        onTradeClosed?.call(data);
      });

      socket?.connect();

      // Start periodic safety timer to retry if disconnected
      _reconnectCheckTimer?.cancel();
      _reconnectCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (!isConnected && socket != null) {
          print('🔄 Socket auto-reconnect trigger...');
          socket?.connect();
        }
      });
    } catch (e) {
      print('SocketService Connect Exception: $e');
      isConnected = false;
      onConnectionChanged?.call();
    }
  }

  void disconnect() {
    _reconnectCheckTimer?.cancel();
    _reconnectCheckTimer = null;
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    isConnected = false;
    onConnectionChanged?.call();
  }
}
