import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';

// Data model for structured data from the MCU.
class McuData {

  McuData({
    this.dutyCycle = 0.0,
    this.accelX = 0.0,
    this.accelY = 0.0,
    this.accelZ = 0.0,
  });
  final double dutyCycle;
  final double accelX;
  final double accelY;
  final double accelZ;
}

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
  // Broadcasts structured McuData objects instead of raw strings.
  final StreamController<McuData> _responseController = StreamController<McuData>.broadcast();
  Stream<McuData> get responseStream => _responseController.stream;

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
            // New parsing logic for incoming messages.
            _parseMcuMessage(message);
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

  // New method to parse messages from the MCU.
  void _parseMcuMessage(String message) {
    if (message.startsWith('\x02') && message.endsWith('\x03')) {
      final String payload = message.substring(1, message.length - 1);
      final RegExp regex = RegExp(r'([+-][0-9]+\.[0-9]{2})');
      final List<Match> matches = regex.allMatches(payload).toList();

      if (matches.length == 4) {
        try {
          final double dutyCycle = double.parse(matches[0].group(0)!);
          final double accelX = double.parse(matches[1].group(0)!);
          final double accelY = double.parse(matches[2].group(0)!);
          final double accelZ = double.parse(matches[3].group(0)!);

          final mcuData = McuData(dutyCycle: dutyCycle, accelX: accelX, accelY: accelY, accelZ: accelZ);
          _responseController.add(mcuData);
        } catch (e) {
          developer.log('❌ Error parsing MCU data: $e', name: 'MCU.Parse');
        }
      }
    } else {
       developer.log('⬅️ Received non-standard message: $message', name: 'MCU.Raw');
    }
  }

  void _startSendLoop() {
    stopSendLoop();
    const int fps = 1;
    const int intervalMs = 1000 ~/ fps;
    _sendLoopTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      _executeSendLogic();
    });
    developer.log('✅ Unified send loop started at $fps FPS.');
  }

  void _executeSendLogic() {
    if (_oneTimeCommand != null) {
      _sendCommandInternal(_oneTimeCommand!);
      _oneTimeCommand = null;
      return;
    }

    if (_latestJoystickData != null &&
        (_latestJoystickData!['x'] != 0.0 || _latestJoystickData!['y'] != 0.0)) {
      final double throttleMultiplier = _latestThrottlePercentage / 100.0;
      final double finalX = (_latestJoystickData!['x'] ?? 0.0) * throttleMultiplier;
      final double finalY = (_latestJoystickData!['y'] ?? 0.0) * throttleMultiplier;
      final Map<String, double> finalMoveData = {'x': finalX, 'y': finalY};
      _sendCommandInternal('move', data: finalMoveData);
      return;
    }
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
          final xFormatter = NumberFormat('+0.00;-0.00');
          final yFormatter = NumberFormat('+0.00;-0.00');
          final String x = xFormatter.format(data['x'] ?? 0.0);
          final String y = yFormatter.format(data['y'] ?? 0.0);
          return '\x02$x$y\x03';
        }
        return '';
      case 'heartbeat':
        return '\x02$command\x03';
      case 'start':
      case 'stop':
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