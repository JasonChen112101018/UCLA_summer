import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

class JoystickRight extends StatelessWidget {

  const JoystickRight({super.key, required this.onMove});
  final void Function(StickDragDetails) onMove;

  @override
  Widget build(BuildContext context) {
    return Joystick(
      mode: JoystickMode.all,
      listener: onMove,
      base: Container(
        height: 120,
        width: 120,
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
    );
  }
}