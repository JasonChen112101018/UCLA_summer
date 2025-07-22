import 'package:flutter/material.dart';
import '../services/pills_connection_service.dart'; // 確保這是你重構後的 UDP 服務檔案
import 'widgets/joystick_left.dart';
import 'widgets/joystick_right.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  // 直接獲取服務的單例實例
  final PillsConnectionService connectionService = PillsConnectionService();

  // 註： initState 和 dispose 保持原樣是正確的，
  // 因為服務的生命週期應該由更上層的 Widget 或 App 本身來管理。

  // 移除了舊的 sendControl 方法

  Widget buildControlButton(IconData icon, String command) {
    return IconButton(
      iconSize: 32,
      color: Colors.white,
      icon: Icon(icon),
      // 按鈕是「一次性」指令，直接調用 sendOneTimeCommand
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
            // Top control row
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
            // Dual joysticks
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    // ===== 左搖桿 =====
                    JoystickLeft(
                      // 當搖桿移動時，持續更新狀態
                      onMove: (Object? details) {
                        // 增加型別檢查，確保安全
                        if (details is Map<String, double>) {
                          connectionService.updateJoystickState(left: details);
                        }
                      },
                      // 【最佳實踐】當使用者放開搖桿時，發送歸零狀態
                      onStop: () {
                        connectionService.updateJoystickState(
                          left: <String, double>{'x': 0.0, 'y': 0.0},
                        );
                      },
                    ),
                    // ===== 右搖桿 =====
                    JoystickRight(
                      // 當搖桿移動時，持續更新狀態
                      onMove: (Object? details) {
                        if (details is Map<String, double>) {
                          connectionService.updateJoystickState(right: details);
                        }
                      },
                      // 【最佳實踐】當使用者放開搖桿時，發送歸零狀態
                      onStop: () {
                        connectionService.updateJoystickState(
                          right: <String, double>{'x': 0.0, 'y': 0.0},
                        );
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