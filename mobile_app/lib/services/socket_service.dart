import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  io.Socket? socket;
  bool isConnected = false;

  Function(dynamic data)? onSignalReceived;
  Function(dynamic data)? onOrderPlaced;
  Function(dynamic data)? onTradeClosed;
  Function()? onConnectionChanged;

  void connect(String serverUrl) {
    disconnect();

    String cleanUrl = serverUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    try {
      socket = io.io(
        cleanUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .build(),
      );

      socket?.onConnect((_) {
        print('⚡ WebSocket Connected to $serverUrl');
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
    } catch (e) {
      print('SocketService Connect Exception: $e');
      isConnected = false;
      onConnectionChanged?.call();
    }
  }

  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    isConnected = false;
    onConnectionChanged?.call();
  }
}
