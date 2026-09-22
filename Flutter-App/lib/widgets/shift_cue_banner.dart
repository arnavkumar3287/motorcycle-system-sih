import 'package:flutter/material.dart';

class ShiftCueBanner extends StatelessWidget {
  final int shiftAction; // -1: Downshift, 0: Hold, 1: Upshift
  final bool isLugging;

  const ShiftCueBanner({
    super.key,
    required this.shiftAction,
    this.isLugging = false,
  });

  @override
  Widget build(BuildContext context) {
    Color mainColor;
    Color glowColor;
    String label;
    IconData icon;

    if (shiftAction == 1) {
      mainColor = const Color(0xFF00FF66);
      glowColor = const Color(0x6600FF66);
      label = 'SHIFT UP';
      icon = Icons.arrow_upward_rounded;
    } else if (shiftAction == -1) {
      mainColor = const Color(0xFFFF3333);
      glowColor = const Color(0x66FF3333);
      label = isLugging ? 'DOWNSHIFT (LUGGING)' : 'SHIFT DOWN';
      icon = Icons.arrow_downward_rounded;
    } else {
      mainColor = const Color(0xFF00E5FF);
      glowColor = const Color(0x3300E5FF);
      label = 'HOLD GEAR';
      icon = Icons.check_circle_outline_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF14171F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mainColor.withValues(alpha: 0.8), width: 2),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: mainColor, size: 40),
          const SizedBox(width: 16),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: mainColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
