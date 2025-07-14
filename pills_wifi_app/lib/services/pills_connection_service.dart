import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class PillsConnectionService {
  factory PillsConnectionService() => _instance;

  PillsConnectionService._internal();
  static final PillsConnectionService _instance = PillsConnectionService._internal();

  Socket? _socket;

  // CC3200 作為 Access Point，IP 通常固定為 192.168.4.1
  final String targetIp = '192.168.1.1';
  final int targetPort = 8080;

  Future<void> init() async {
    try {
      _socket = await Socket.connect(targetIp, targetPort, timeout: const Duration(seconds: 5));
      debugPrint('Connected to CC3200 at $targetIp:$targetPort');

      _socket!.listen((data) {
        final message = utf8.decode(data);
        debugPrint('CC3200 response: $message');
      }, onDone: () {
        debugPrint('❌Connection closed by CC3200');
        _socket = null;
      }, onError: (error) {
        debugPrint('❌TCP Error: $error');
        _socket = null;
      });
    } catch (e) {
      debugPrint('❌Connection failed: $e');
    }
  }

  void sendCommand(String command, dynamic data) {
    if (_socket == null) {
      debugPrint('⚠️Socket not connected!');
      return;
    }

    final String message = _buildMessage(command, data);
    _socket!.add(utf8.encode(message));
    debugPrint('Sent to CC3200: $message');
  }

  String _buildMessage(String command, dynamic data) {
    if (command == 'left_stick' || command == 'right_stick') {
      return '\x02$command:${data.x.toStringAsFixed(2)},${data.y.toStringAsFixed(2)}\x03';
    }
    return '\x02$command\x03'; // 使用 STX / ETX 封包包起來
  }

  void dispose() {
    _socket?.close();
    _socket = null;
  }
}
