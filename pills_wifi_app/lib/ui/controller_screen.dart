import 'package:flutter/material.dart';
import '../services/pills_connection_service.dart';
import 'widgets/throttle_slider.dart';
import 'widgets/joystick_right.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  final PillsConnectionService connectionService = PillsConnectionService();

  Widget buildControlButton(IconData icon, String command) {
    return IconButton(
      iconSize: 32,
      color: Colors.white,
      icon: Icon(icon),
      onPressed: () => connectionService.sendOneTimeCommand(command),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Top control row (remains the same)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  buildControlButton(Icons.play_arrow, 'start'),
                  buildControlButton(Icons.pause, 'pause'),
                  buildControlButton(Icons.settings, 'config'),
                  const Text('WCE Status', style: TextStyle(color: Colors.white)),
                  buildControlButton(Icons.sync, 'sync'),
                  buildControlButton(Icons.camera_alt, 'log'),
                  buildControlButton(Icons.stop, 'stop'),
                ],
              ),
            ),
            // Dual controls area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    // ===== 左邊：油門拉桿 =====
                    ThrottleSlider(
                      onMove: (intensity) {
                        connectionService.updateThrottlePercentage(intensity);
                      },
                      onStop: () {
                        // Do nothing. Keep the throttle value as is.
                      },
                      // =========================
                    ),
                    // ===== 右邊：搖桿 =====
                    JoystickRight(
                      onMove: (Map<String, double> details) {
                        connectionService.updateJoystickState(details);
                      },
                      onStop: () {
                        connectionService.updateJoystickState({'x': 0.0, 'y': 0.0});
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}