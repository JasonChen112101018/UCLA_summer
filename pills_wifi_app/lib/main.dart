import 'package:flutter/material.dart';
import 'ui/controller_screen.dart';
import 'services/pills_connection_service.dart'; // 確保這是你的 UDP 服務檔案

void main() async {
  // 確保 Flutter 小工具綁定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 在 App 啟動前，僅執行一次初始化
  // 這確保了連線服務的生命週期與 App 相同
  try {
    // 確保你使用的是 UDP 版本的 Class 名稱
    await PillsConnectionService().init();
  } catch (e) {
    debugPrint('❌ UDP connection init failed: $e');
  }

  runApp(const PillsWifiApp());
}

class PillsWifiApp extends StatelessWidget {
  const PillsWifiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ControllerScreen(),
    );
  }
}