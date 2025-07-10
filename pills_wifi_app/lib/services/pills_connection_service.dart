import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class PillsConnectionService {
  static final PillsConnectionService _instance = PillsConnectionService._internal();
  factory PillsConnectionService() => _instance;

  RawDatagramSocket? _socket;
  final String targetIp = "192.168.4.1";
  final int targetPort = 8888;

  PillsConnectionService._internal();
  Future<void> init() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) {
          final message = utf8.decode(datagram.data);
          debugPrint('WCE response: $message');
        }
      }
    });
  }

  void sendCommand(String command, dynamic data) {
    if (_socket == null) {
      debugPrint('Socket not ready!');
      return;
    }

    final message = _buildMessage(command, data);
    _socket!.send(utf8.encode(message), InternetAddress(targetIp), targetPort);
    debugPrint('Sent to WCE: $message');
  }

  String _buildMessage(String command, dynamic data) {
    if (command == 'left_stick' || command == 'right_stick') {
      return "$command:${data.x.toStringAsFixed(2)},${data.y.toStringAsFixed(2)}";
    }
    return command;
  }
}
