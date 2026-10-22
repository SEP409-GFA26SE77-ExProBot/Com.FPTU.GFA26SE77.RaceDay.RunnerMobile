import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class BrandLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool showText;

  const BrandLogo({
    super.key,
    this.iconSize = 20,
    this.fontSize = 18,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize * 1.6,
          height: iconSize * 1.6,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryLight,
          ),
          child: Center(
            child: Icon(
              Icons.directions_run_rounded,
              size: iconSize,
              color: AppColors.primary,
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Race',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: 'Day',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
