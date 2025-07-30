import 'package:flutter/material.dart';

class ThrottleSlider extends StatefulWidget {
  const ThrottleSlider({
    super.key,
    required this.onMove,
    required this.onStop,
  });

  final void Function(double intensity) onMove;
  final void Function() onStop;

  @override
  State<ThrottleSlider> createState() => _ThrottleSliderState();
}

class _ThrottleSliderState extends State<ThrottleSlider> {
  double _intensity = 0.0; // 強度值，範圍 0-100

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanEnd: (details) {
        widget.onStop();
      },
      onPanCancel: () {
        widget.onStop();
      },
      onPanUpdate: (details) {
        // 獲取滑動的垂直位置變化
        RenderBox renderBox = context.findRenderObject() as RenderBox;
        var localPosition = renderBox.globalToLocal(details.globalPosition);
        double height = renderBox.size.height;
        // 計算強度：從底部到頂部為 0 到 100
        double newIntensity = 100.0 * (1.0 - localPosition.dy / height);
        // 限制範圍在 0-100
        newIntensity = newIntensity.clamp(0.0, 100.0);
        setState(() {
          _intensity = newIntensity;
        });
        widget.onMove(_intensity);
      },
      child: Container(
        width: 120,
        height: 400,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Stack(
          children: [
            // 背景槽，顯示拉桿的範圍
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40.0),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            ),
            // 拉桿指示器，根據強度值移動
            Positioned(
              left: 0,
              right: 0,
              bottom: (_intensity / 100.0) * 180.0, // 根據強度計算底部位置
              child: Container(
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 30.0),
                decoration: BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            ),
            // 強度值文字顯示
            Center(
              child: Text(
                '${_intensity.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
