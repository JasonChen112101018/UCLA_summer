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
      // ===== 邏輯修改開始 =====
      onPanEnd: (details) {
        // 【修改】移除將強度歸零的 setState。
        // setState(() {
        //   _intensity = 0.0;
        // });
        
        // 只通知父元件操作已停止，但保持目前強度值。
        widget.onStop();
      },
      onPanCancel: () {
        // 【修改】同樣移除這裡的 setState。
        // setState(() {
        //   _intensity = 0.0;
        // });

        widget.onStop();
      },
      // ===== 邏輯修改結束 =====
      onPanUpdate: (details) {
        // 這個計算邏輯是正確的，保持不變
        RenderBox renderBox = context.findRenderObject() as RenderBox;
        var localPosition = renderBox.globalToLocal(details.globalPosition);
        double height = renderBox.size.height;
        double newIntensity = 100.0 * (1.0 - localPosition.dy / height);
        newIntensity = newIntensity.clamp(0.0, 100.0);
        setState(() {
          _intensity = newIntensity;
        });
        widget.onMove(_intensity);
      },
      // UI 外觀部分保持不變
      child: Container(
        width: 160,
        height: 500,
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(80),
          border: Border.all(
            color: Colors.lightBlue.withOpacity(0.8),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(80),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double trackHeight = constraints.maxHeight;
              const double indicatorHeight = 40.0;
              final double travelDistance = trackHeight - indicatorHeight;

              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 30,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  Positioned(
                    bottom: (_intensity / 100.0) * travelDistance,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: indicatorHeight,
                      decoration: BoxDecoration(
                        color: Colors.lightBlueAccent,
                        borderRadius: BorderRadius.circular(10.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.lightBlueAccent.withOpacity(0.7),
                            blurRadius: 12,
                            spreadRadius: 3,
                          )
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${_intensity.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(blurRadius: 3, color: Colors.black87)
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}