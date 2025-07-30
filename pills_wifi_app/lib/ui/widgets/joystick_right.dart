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
    return GestureDetector(
      onPanEnd: (details) {
        onStop();
      },
      onPanCancel: () {
        onStop();
      },
      child: Joystick(
        mode: JoystickMode.all,
        listener: (details) {
          final Map<String, double> moveDetails = {
            'x': details.y * -1,
            'y': details.x * -1, // 反轉 Y 軸以符合 UI 的方向
          };
          onMove(moveDetails);
        },
        // ===== UI 外觀修改 =====
        base: Container(
          // 增加基礎尺寸
          height: 450,
          width: 450,
          decoration: BoxDecoration(
            // 使用半透明的藍灰色作為底色
            // ignore: deprecated_member_use
            color: Colors.blueGrey.withOpacity(0.3),
            shape: BoxShape.circle,
            // 增加藍色外框線，讓邊界更清楚
            border: Border.all(
              // ignore: deprecated_member_use
              color: Colors.lightBlue.withOpacity(0.8),
              width: 2,
            ),
          ),
        ),
        stick: Container(
          // 同步增加搖桿頭的尺寸
          height: 60,
          width: 60,
          decoration: const BoxDecoration(
            // 使用更明亮的藍色作為搖桿頭顏色
            color: Colors.lightBlueAccent,
            shape: BoxShape.circle,
            boxShadow: [ // 增加陰影使其更有立體感
              BoxShadow(
                color: Colors.black45,
                blurRadius: 8,
                offset: Offset(2, 2),
              )
            ]
          ),
        ),
      ),
    );
  }
}