import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/dynamic_theme.dart';

class XpBar extends StatelessWidget {
  final double progress; // 0.0 – 1.0

  const XpBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final dt = context.watch<DynamicTheme>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dt.showProgressMarkers) ...[
          Text(
            'XP  ${(progress * 100).toInt()} / 100',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: dt.xpAccentColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
          ),
        ),
      ],
    );
  }
}
