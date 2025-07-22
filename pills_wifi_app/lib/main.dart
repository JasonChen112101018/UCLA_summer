import 'package:flutter/material.dart';
import 'ui/controller_screen.dart';
import 'services/pills_connection_service.dart'; // 確保這是你重構後的 UDP 服務檔案

void main() async {
  // 確保 Flutter 小工具綁定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 在 App 啟動前，僅執行一次初始化
  // 這確保了連線服務的生命週期與 App 相同
  try {
    await PillsConnectionService().init();
  } catch (e) {
    debugPrint('❌ UDP connection init failed: $e');
  }

  runApp(const PillsWifiApp());
}

// ===== 將 App 改為 StatefulWidget 以監聽生命週期 =====
class PillsWifiApp extends StatefulWidget {
  const PillsWifiApp({super.key});

  @override
  State<PillsWifiApp> createState() => _PillsWifiAppState();
}

// ===== 混入 WidgetsBindingObserver 來監聽 App 狀態 =====
class _PillsWifiAppState extends State<PillsWifiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 註冊監聽器
    WidgetsBinding.instance.addObserver(this);
    debugPrint('App Lifecycle Observer registered.');
  }

  @override
  void dispose() {
    // 移除監聽器，防止記憶體洩漏
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('App Lifecycle Observer removed.');
    super.dispose();
  }

  /// 這是監聽 App 生命週期的核心方法
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 根據 App 的狀態執行相應操作
    switch (state) {
      case AppLifecycleState.resumed:
        // App 回到前景，可以考慮重新啟動心跳（如果曾在暫停時關閉）
        debugPrint('App is resumed.');
        PillsConnectionService().init(); // 嘗試重新初始化，內部會防止重複執行
        break;
      case AppLifecycleState.inactive:
        // App 處於非活動狀態，例如有來電或切換到多工視窗
        debugPrint('App is inactive.');
        break;
      case AppLifecycleState.paused:
        // App 進入後台，這是釋放資源的最佳時機
        debugPrint('App is paused. Disposing connection service...');
        PillsConnectionService().dispose();
        break;
      case AppLifecycleState.detached:
        // App 被銷毀 (很少能監聽到，但以防萬一)
        debugPrint('App is detached. Disposing connection service...');
        PillsConnectionService().dispose();
        break;
      case AppLifecycleState.hidden:
        // Flutter 3.13 新增的狀態，視為 paused
        debugPrint('App is hidden. Disposing connection service...');
        PillsConnectionService().dispose();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ControllerScreen(),
    );
  }
}