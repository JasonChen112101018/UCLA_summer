import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

class JoystickRight extends StatelessWidget {
  const JoystickRight({
    super.key,
    required this.onMove,
    required this.onStop,
  });

  final void Function(Map<String, double> details) onMove;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    // ✅ 使用 GestureDetector 來偵測手勢的結束
    return GestureDetector(
      // 當使用者手指抬起，拖曳手勢結束時觸發
      onPanEnd: (details) {
        onStop();
      },
      // 當手勢被系統取消時也觸發 onStop，確保歸位
      onPanCancel: () {
        onStop();
      },
      child: Joystick(
        mode: JoystickMode.all,
        // ✅ 使用套件本身提供的 listener 來處理 onMove
        listener: (details) {
          // 在這裡將 StickDragDetails 轉換為我們需要的 Map 格式
          final Map<String, double> moveDetails = {
            'x': details.x,
            'y': details.y,
          };
          // 傳遞轉換後的資料
          onMove(moveDetails);
        },
        // 以下是 UI 外觀，保持不變
        base: Container(
          height: 300,
          width: 300,
          decoration: const BoxDecoration(
            color: Colors.white10,
            shape: BoxShape.circle,
          ),
        ),
        stick: Container(
          height: 40,
          width: 40,
          decoration: const BoxDecoration(
            color: Colors.white70,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}