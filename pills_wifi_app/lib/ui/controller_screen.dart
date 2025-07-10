import 'package:flutter/material.dart';
import '../services/pills_connection_service.dart';
import 'widgets/joystick_left.dart';
import 'widgets/joystick_right.dart';

class ControllerScreen extends StatelessWidget {
  const ControllerScreen({super.key});

  void sendControl(String control, dynamic data) {
    PillsConnectionService().sendCommand(control, data);
  }

  Widget buildControlButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      iconSize: 32,
      color: Colors.white,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Top control row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  buildControlButton(Icons.play_arrow, () => sendControl('start', <dynamic, dynamic>{})),
                  buildControlButton(Icons.pause, () => sendControl('pause', <dynamic, dynamic>{})),
                  buildControlButton(Icons.settings, () => sendControl('config', <dynamic, dynamic>{})),
                  const Text('WCE Status', style: TextStyle(color: Colors.white)),
                  buildControlButton(Icons.sync, () => sendControl('sync', <dynamic, dynamic>{})),
                  buildControlButton(Icons.camera_alt, () => sendControl('log', <dynamic, dynamic>{})),
                  buildControlButton(Icons.stop, () => sendControl('stop', <dynamic, dynamic>{})),
                ],
              ),
            ),
            // Dual joysticks
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    JoystickLeft(onMove: (Object? details) => sendControl('left_stick', details)),
                    JoystickRight(onMove: (Object? details) => sendControl('right_stick', details)),
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
