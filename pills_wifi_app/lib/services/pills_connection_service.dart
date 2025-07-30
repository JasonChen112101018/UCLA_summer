import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';

class PillsConnectionService {
  // --- Singleton Pattern ---
  factory PillsConnectionService() => _instance;
  PillsConnectionService._internal();
  static final PillsConnectionService _instance = PillsConnectionService._internal();

  // --- Network & Socket ---
  RawDatagramSocket? _socket;
  final String targetIp = '192.168.1.1';
  final int targetPort = 8080;
  InternetAddress? _targetAddress;

  // --- Main Sending Loop Timer ---
  Timer? _sendLoopTimer;

  // --- State Management ---
  Map<String, double>? _latestJoystickData;
  double _latestThrottlePercentage = 0.0; 
  String? _oneTimeCommand;

  // --- Response Stream ---
  final StreamController<String> _responseController = StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  Future<bool> init() async {
    if (_socket != null) {
      return true;
    }
    developer.log('Initializing UDP Connection Service...');
    try {
      _targetAddress = InternetAddress(targetIp);
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      developer.log('✅ UDP Socket bound to local port: ${_socket!.port}');

      _socket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            Datagram? datagram = _socket!.receive();
            if (datagram == null) return;
            final String message = utf8.decode(datagram.data);
            developer.log('⬅️ MSG from Capsule: $message');
            _responseController.add(message);
          }
        },
        onError: (error) {
          developer.log('❌ UDP Socket Error: $error');
          dispose();
        },
        onDone: () {
          developer.log('UDP Socket closed.');
          dispose();
        },
      );

      _startSendLoop();
      return true;
    } catch (e) {
      developer.log('❌ Failed to initialize UDP socket: $e');
      _socket = null;
      return false;
    }
  }

  void _startSendLoop() {
    stopSendLoop();
    const int fps = 20;
    const int intervalMs = 1000 ~/ fps;
    _sendLoopTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      _executeSendLogic();
    });
    developer.log('✅ Unified send loop started at $fps FPS.');
  }

  /// REWRITTEN: 完全重寫的核心發送邏輯
  void _executeSendLogic() {
    // 優先度 1: 一次性指令 (例如 'start', 'stop')
    if (_oneTimeCommand != null) {
      _sendCommandInternal(_oneTimeCommand!); // 直接發送指令字串
      _oneTimeCommand = null;
      return;
    }

    // 優先度 2: 搖桿移動指令
    // 檢查搖桿是否有活動 (x 或 y 不為 0)
    if (_latestJoystickData != null &&
        (_latestJoystickData!['x'] != 0.0 || _latestJoystickData!['y'] != 0.0)) {
      
      // 計算最終的 x, y 值 (搖桿 * 油門百分比)
      final double throttleMultiplier = _latestThrottlePercentage / 100.0;
      final double finalX = (_latestJoystickData!['x'] ?? 0.0) * throttleMultiplier;
      final double finalY = (_latestJoystickData!['y'] ?? 0.0) * throttleMultiplier;

      final Map<String, double> finalMoveData = {'x': finalX, 'y': finalY};
      
      // 使用一個新的內部指令 'move' 來觸發新的訊息格式
      _sendCommandInternal('move', data: finalMoveData);
      return;
    }

    // 優先度 3: 心跳 (當沒有任何操作時)
    _sendCommandInternal('heartbeat');
  }

  void updateJoystickState(Map<String, double> data) {
    _latestJoystickData = data;
  }

  void updateThrottlePercentage(double percentage) {
    _latestThrottlePercentage = percentage;
  }

  void sendOneTimeCommand(String command) {
    _oneTimeCommand = command;
  }

  void _sendCommandInternal(String command, {dynamic data}) {
    if (_socket == null || _targetAddress == null) return;

    final String message = _buildMessage(command, data);
    if (message.isEmpty) return;

    final List<int> dataBytes = utf8.encode(message);
    try {
      _socket!.send(dataBytes, _targetAddress!, targetPort);
    } catch (e) {
      developer.log("❌ Failed to send command '$command': $e");
    }
  }

  String _buildMessage(String command, dynamic data) {
    switch (command) {
      case 'move':
        if (data is Map<String, double>) {
          // 使用 intl 套件來格式化數字，確保總是顯示正負號
          final xFormatter = NumberFormat('+0.00;-0.00');
          final yFormatter = NumberFormat('+0.00;-0.00');

          final String x = xFormatter.format(data['x'] ?? 0.0);
          final String y = yFormatter.format(data['y'] ?? 0.0);
          
          // 組合成最終格式
          return '\x02$x''$y\x03';
        }
        return '';
      
      case 'heartbeat':
        return '\x02$command\x03';

      default:
        return '';
    }
  }
  
  void dispose() {
    developer.log('Disposing PillsConnectionService...');
    stopSendLoop();
    _socket?.close();
    _socket = null;
    if (!_responseController.isClosed) {
      _responseController.close();
    }
  }

  void stopSendLoop() {
    _sendLoopTimer?.cancel();
    _sendLoopTimer = null;
  }
}