import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;


class PillsConnectionService {
  // --- Singleton Pattern ---
  factory PillsConnectionService() => _instance;
  PillsConnectionService._internal();
  static final PillsConnectionService _instance = PillsConnectionService._internal();

  // --- Network & Socket ---
  RawDatagramSocket? _socket;
  final String targetIp = '192.168.1.1'; // Target IP of the CC3200 AP
  final int targetPort = 8080;          // Target Port on the CC3200
  InternetAddress? _targetAddress;

  // --- Main Sending Loop Timer ---
  Timer? _sendLoopTimer;

  // --- State Management ---
  // These variables hold the latest state from the UI. The loop reads them.
  Map<String, double>? _latestJoystickData;
  double? _latestThrottleData;
  String? _oneTimeCommand; // A queue for single, important commands

  // --- Response Stream ---
  // Listens for any messages sent back from the C2000.
  final StreamController<String> _responseController = StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  /// Initializes the UDP service, binds the socket, and starts the main communication loop.
  /// Returns true on success, false on failure.
  Future<bool> init() async {
    if (_socket != null) {
      developer.log('UDP Service already initialized.');
      return true;
    }

    developer.log('Initializing UDP Connection Service...');
    try {
      _targetAddress = InternetAddress(targetIp);
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      developer.log('✅ UDP Socket bound to local port: ${_socket!.port}');

      // Start listening for any incoming messages from the capsule
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
          dispose(); // Clean up on error
        },
        onDone: () {
          developer.log('UDP Socket closed.');
          dispose();
        },
      );

      // Start the main loop to handle sending commands
      _startSendLoop();
      return true;
    } catch (e) {
      developer.log('❌ Failed to initialize UDP socket: $e');
      _socket = null;
      return false;
    }
  }

  /// Starts the unified send loop. This is the heart of the service.
  void _startSendLoop() {
    stopSendLoop(); // Ensure no other loop is running

    // Set the desired FPS. 20 FPS is a great, stable target for this application.
    const int fps = 20;
    const int intervalMs = 1000 ~/ fps;

    _sendLoopTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      _executeSendLogic();
    });

    developer.log('✅ Unified send loop started at $fps FPS (${intervalMs}ms interval).');
  }

  /// The logic executed in every "frame" of the send loop.
  /// It decides which command to send based on priority.
  void _executeSendLogic() {
    // Priority 1: One-Time Commands
    // If there's a critical command waiting, send it immediately and clear it.
    if (_oneTimeCommand != null) {
      _sendCommandInternal(_oneTimeCommand!);
      _oneTimeCommand = null; // Clear after sending
      return; // End this frame
    }

    // Priority 2: Movement Commands
    // Check for active joystick movement first.
    if (_latestJoystickData != null &&
        (_latestJoystickData!['x'] != 0.0 || _latestJoystickData!['y'] != 0.0)) {
      _sendCommandInternal('joystick', data: _latestJoystickData);
      return; // End this frame
    }

    // If no joystick movement, check for active throttle.
    if (_latestThrottleData != null && _latestThrottleData! > 0.0) {
      _sendCommandInternal('throttle', data: _latestThrottleData);
      return; // End this frame
    }

    // Priority 3: Heartbeat
    // If there's nothing else to do, send a heartbeat to keep the connection alive
    // and let the CC3200 know our address.
    _sendCommandInternal('heartbeat');
  }

  /// Updates the current joystick state. Called by the UI.
  /// This method ONLY updates the state variable; the send loop does the sending.
  void updateJoystickState(Map<String, double> data, {required Map<String, double> right}) {
    _latestJoystickData = data;
  }

  /// Updates the current throttle state. Called by the UI.
  void updateThrottleState(double intensity) {
    _latestThrottleData = intensity;
  }

  /// Queues a one-time command to be sent with high priority.
  void sendOneTimeCommand(String command) {
    _oneTimeCommand = command;
  }

  /// Internal helper to build and send the final UDP packet.
  void _sendCommandInternal(String command, {dynamic data}) {
    if (_socket == null) return;

    final String message = _buildMessage(command, data);
    final List<int> dataBytes = utf8.encode(message);

    try {
      _socket!.send(dataBytes, _targetAddress!, targetPort);
    } catch (e) {
      developer.log("Failed to send command '$command': $e");
    }
  }

  /// Constructs the final message string with STX/ETX framing.
  String _buildMessage(String command, dynamic data) {
    String payload = command;

    if (command == 'joystick' && data is Map<String, double>) {
      // Format to two decimal places for consistency
      final String x = data['x']?.toStringAsFixed(2) ?? '0.00';
      final String y = data['y']?.toStringAsFixed(2) ?? '0.00';
      payload = '$x$y';
    }

    // Wrap the payload with standard STX (Start of Text) and ETX (End of Text) characters
    return '\x02$payload\x03';
  }

  /// Stops the send loop and closes the socket to release all resources.
  void dispose() {
    developer.log('Disposing PillsConnectionService...');
    stopSendLoop();
    _socket?.close();
    _socket = null;
    if (!_responseController.isClosed) {
      _responseController.close();
    }
  }

  /// Stops the main send loop timer.
  void stopSendLoop() {
    _sendLoopTimer?.cancel();
    _sendLoopTimer = null;
  }
}