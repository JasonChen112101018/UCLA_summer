import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class PillsConnectionService {
  factory PillsConnectionService() => _instance;

  PillsConnectionService._internal();
  static final PillsConnectionService _instance =
      PillsConnectionService._internal();

  RawDatagramSocket? _socket;
  Timer? _fetchTimer; // 用於定期發送搖桿等重複指令的計時器
  Timer? _heartbeatTimer; // 用於維持連線的心跳計時器

  final StreamController<String> _responseController =
      StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  final String targetIp = '192.168.1.1';
  final int targetPort = 8080;
  InternetAddress? _targetAddress;

  /// 初始化並綁定 UDP Socket
  Future<bool> init() async {
    // 防止重複初始化
    if (_socket != null) {
      debugPrint('UDP Service already initialized.');
      return true;
    }

    try {
      _targetAddress = InternetAddress(targetIp);
    } catch (e) {
      debugPrint('❌ Invalid target IP address: $e');
      return false;
    }

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      debugPrint('✅ UDP Socket bound to local port: ${_socket!.port}');

      _socket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            Datagram? datagram = _socket!.receive();
            if (datagram == null) return;

            final String message = utf8.decode(datagram.data);
            debugPrint(
                'CC3200 response from ${datagram.address.address}:${datagram.port}: $message');
            _responseController.add(message);
          }
        },
        onError: (error) {
          debugPrint('❌ UDP Error: $error');
          dispose();
        },
        onDone: () {
          debugPrint('❌ UDP Socket closed');
          dispose();
        },
      );

      // 啟動心跳機制
      startHeartbeat();
      return true;
    } catch (e) {
      debugPrint('❌ Failed to bind UDP socket: $e');
      _socket = null;
      return false;
    }
  }
  
  /// 啟動心跳，每秒發送一次
  void startHeartbeat() {
    stopHeartbeat(); // 先停止舊的，以防萬一
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      // 定期發送一個專門的 "heartbeat" 指令
      sendCommand('heartbeat', null); 
    });
    debugPrint('💓 Heartbeat started.');
  }

  /// 停止心跳
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 啟動定期抓取數據 (例如搖桿)
  void startPeriodicFetching({
    required String command,
    dynamic data,
    Duration interval = const Duration(milliseconds: 100), // 提高搖桿發送頻率
  }) {
    stopPeriodicFetching();

    _fetchTimer = Timer.periodic(interval, (Timer timer) {
      if (_socket != null) {
        sendCommand(command, data);
      } else {
        debugPrint('⚠️ UDP Socket not bound, stopping timer.');
        stopPeriodicFetching();
      }
    });
    debugPrint(
        '🕒 Started periodic fetching for "$command" with a ${interval.inMilliseconds}ms interval.');
  }

  /// 停止定期抓取數據
  void stopPeriodicFetching() {
    if (_fetchTimer != null) {
        _fetchTimer?.cancel();
        _fetchTimer = null;
        debugPrint('🛑 Stopped periodic fetching.');
    }
  }

  /// 發送命令到指定的目標
  void sendCommand(String command, dynamic data) {
    if (_socket == null || _targetAddress == null) {
      debugPrint('⚠️ UDP Socket not bound or target address is invalid!');
      return;
    }

    final String message = _buildMessage(command, data);
    final List<int> dataBytes = utf8.encode(message);
    _socket!.send(dataBytes, _targetAddress!, targetPort);
  }

  String _buildMessage(String command, dynamic data) {
    String payload = command;
    if (command == 'left_stick' || command == 'right_stick') {
      if (data is Map) {
         // 範例: command:x,y
         payload = '$command:${data['x']},${data['y']}';
      }
    }
    // 使用 STX / ETX 封包包起來
    return '\x02$payload\x03';
  }

  /// 釋放資源
  void dispose() {
    stopPeriodicFetching();
    stopHeartbeat();
    _socket?.close();
    _socket = null;
    if (!_responseController.isClosed) {
      _responseController.close();
    }
    debugPrint('PillsUdpConnectionService disposed.');
  }
}