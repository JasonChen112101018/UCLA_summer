import 'dart:async';
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

  // Holds the latest data from the MCU to display on the UI.
  McuData _latestMcuData = McuData();
  // Manages the stream subscription.
  StreamSubscription? _mcuDataSubscription;

  @override
  void initState() {
    super.initState();
    // Subscribe to the response stream when the page loads.
    _mcuDataSubscription = connectionService.responseStream.listen((data) {
      if (mounted) {
        setState(() {
          _latestMcuData = data;
        });
      }
    });
  }

  @override
  void dispose() {
    // Cancel the subscription when the page is destroyed to prevent memory leaks.
    _mcuDataSubscription?.cancel();
    super.dispose();
  }

  // Helper widget for displaying a single piece of info.
  Widget _buildInfoDisplay(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Helper widget for building control buttons.
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
            // Simplified top button row.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  buildControlButton(Icons.play_arrow, 'start'),
                  const Text('MCU Status', style: TextStyle(color: Colors.white, fontSize: 16)),
                  buildControlButton(Icons.stop, 'stop'),
                ],
              ),
            ),

            // New MCU data display section.
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 24.0,
                runSpacing: 16.0,
                alignment: WrapAlignment.center,
                children: [
                  _buildInfoDisplay('Duty Cycle', _latestMcuData.dutyCycle.toStringAsFixed(2), Colors.greenAccent),
                  _buildInfoDisplay('Accel X', _latestMcuData.accelX.toStringAsFixed(2), Colors.amber),
                  _buildInfoDisplay('Accel Y', _latestMcuData.accelY.toStringAsFixed(2), Colors.amber),
                  _buildInfoDisplay('Accel Z', _latestMcuData.accelZ.toStringAsFixed(2), Colors.amber),
                ],
              ),
            ),

            // Main controls area.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    ThrottleSlider(
                      onMove: (intensity) {
                        connectionService.updateThrottlePercentage(intensity);
                      },
                      onStop: () {
                        // Do nothing to keep the value on release.
                      },
                    ),
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