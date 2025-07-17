import 'package:flutter/material.dart';
import '../services/pills_connection_service.dart'; // 確保這是你的 UDP 服務檔案
import 'widgets/joystick_left.dart';
import 'widgets/joystick_right.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  // 直接獲取服務的單例實例，因為它已經在 main.dart 中被初始化
  final PillsConnectionService connectionService = PillsConnectionService();

  @override
  void initState() {
    super.initState();
    // 服務已在 App 啟動時初始化，此處無需任何操作
  }

  void sendControl(String control, dynamic data) {
    // 直接使用服務發送命令
    connectionService.sendCommand(control, data);
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
                  buildControlButton(Icons.play_arrow, () => sendControl('start', null)),
                  buildControlButton(Icons.pause, () => sendControl('pause', null)),
                  buildControlButton(Icons.settings, () => sendControl('config', null)),
                  const Text('WCE Status', style: TextStyle(color: Colors.white)),
                  buildControlButton(Icons.sync, () => sendControl('sync', null)),
                  buildControlButton(Icons.camera_alt, () => sendControl('log', null)),
                  buildControlButton(Icons.stop, () => sendControl('stop', null)),
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

  @override
  void dispose() {
    // 服務的生命週期由 App 管理，此頁面不應關閉它
    super.dispose();
  }
}