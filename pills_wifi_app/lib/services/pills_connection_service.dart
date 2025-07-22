import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class PillsConnectionService {
  factory PillsConnectionService() => _instance;

  PillsConnectionService._internal();
  static final PillsConnectionService _instance =
      PillsConnectionService._internal();

  // Socket & Stream
  RawDatagramSocket? _socket;
  final StreamController<String> _responseController =
      StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  final String targetIp = '192.168.1.1';
  final int targetPort = 8080;
  InternetAddress? _targetAddress;

  // 計時器與狀態管理
  Timer? _sendLoopTimer;

  // ✅ 1. 新增狀態變數，用來追蹤 App 是否正在等待 CC3200 的回應
  bool _isWaitingForResponse = false;
  Timer? _responseTimeoutTimer; // 用於處理 CC3200 未回應的超時

  // 搖桿狀態
  Map<String, double>? _latestLeftStickData;
  Map<String, double>? _latestRightStickData;

  Future<bool> init() async {
    if (_socket != null) return true;

    try {
      _targetAddress = InternetAddress(targetIp);
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      debugPrint('UDP Socket bound to local port: ${_socket!.port}');

      // 2. 在監聽器中加入處理回應的邏輯
      _socket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            Datagram? datagram = _socket!.receive();
            if (datagram == null) return;
            
            // --- 當收到任何來自 CC3200 的回覆時 ---
            // A. 取消等待超時計時器
            _responseTimeoutTimer?.cancel();
            // B. 解鎖發送器，允許發送下一個指令
            _isWaitingForResponse = false;
            
            final String message = utf8.decode(datagram.data);
            debugPrint('Response from CC3200: $message. Sender unlocked.');
            _responseController.add(message);
          }
        },
        onError: (error) { /* ... */ },
        onDone: () { /* ... */ },
      );

      _startSendLoop();
      return true;
    } catch (e) {
      debugPrint('❌ Failed to bind UDP socket: $e');
      _socket = null;
      return false;
    }
  }

  void _startSendLoop() {
    _sendLoopTimer?.cancel();
    _sendLoopTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // 3. 在發送前，先檢查是否正處於等待狀態
      if (_isWaitingForResponse) {
        return; // 如果正在等待，則本次迴圈直接跳過，不發送任何指令
      }
      
      // 以下邏輯與之前類似，但現在有了等待機制的保護
      bool didSendCommand = false;

      if (_latestLeftStickData != null) {
        final data = _latestLeftStickData!;
        _sendCommandInternal('left_stick', data);
        didSendCommand = true;
        if (data['x'] == 0.0 && data['y'] == 0.0) {
          _latestLeftStickData = null;
        }
      }
      
      if (_latestRightStickData != null) {
        final data = _latestRightStickData!;
        _sendCommandInternal('right_stick', data);
        didSendCommand = true;
        if (data['x'] == 0.0 && data['y'] == 0.0) {
          _latestRightStickData = null;
        }
      }

      if (!didSendCommand) {
        _sendCommandInternal('heartbeat', null);
      }
    });
    debugPrint('Unified send loop started with 500ms interval.');
  }

  void updateJoystickState({Map<String, double>? left, Map<String, double>? right}) {
    if (left != null) _latestLeftStickData = left;
    if (right != null) _latestRightStickData = right;
  }

  void sendOneTimeCommand(String command, {dynamic data}) {
    if (_isWaitingForResponse) {
      debugPrint('Flutter App is busy, ignoring one-time command: $command');
      return;
    }
    _sendCommandInternal(command, data);
  }

  void _sendCommandInternal(String command, dynamic data) {
    if (_socket == null || _targetAddress == null) return;
    
    // 心跳包是例外，它不應該觸發等待狀態
    bool isHeartbeat = (command == 'heartbeat');

    final String message = _buildMessage(command, data);
    final List<int> dataBytes = utf8.encode(message);
    _socket!.send(dataBytes, _targetAddress!, targetPort);

    // 4. 如果發送的不是心跳包，則進入等待狀態並啟動超時
    if (!isHeartbeat) {
      _isWaitingForResponse = true;
      _responseTimeoutTimer?.cancel();
      // 設定一個2秒的超時，如果2秒後沒收到CC3200的回應，就自動解鎖
      _responseTimeoutTimer = Timer(const Duration(seconds: 2), () {
        if (_isWaitingForResponse) {
          debugPrint('Timeout: No response from CC3200. Unlocking sender.');
          _isWaitingForResponse = false;
        }
      });
    }
  }

  String _buildMessage(String command, dynamic data) {
    String payload = command;
    if ((command == 'left_stick' || command == 'right_stick') && data is Map<String, double>) {
      final String x = data['x']?.toStringAsFixed(2) ?? '0.00';
      final String y = data['y']?.toStringAsFixed(2) ?? '0.00';
      payload = '5'; 
    }
    return '$payload';
  }

  void dispose() {
    _sendLoopTimer?.cancel();
    _responseTimeoutTimer?.cancel();
    _responseController.close();
    _socket?.close();
    
  }
}