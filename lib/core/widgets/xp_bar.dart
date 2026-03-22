import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/dynamic_theme.dart';

class XpBar extends StatelessWidget {
  final int totalXp;

  const XpBar({super.key, required this.totalXp});

  @override
  Widget build(BuildContext context) {
    final dt = context.watch<DynamicTheme>();

    // Dynamic Rank Goalposts based on your new feature!
    int targetXp = 2500;
    int previousBoundary = 0;
    String nextRank = "Master";

    if (totalXp < 100) {
      targetXp = 100;
      previousBoundary = 0;
      nextRank = "Newbie";
    } else if (totalXp < 200) {
      targetXp = 200;
      previousBoundary = 100;
      nextRank = "Rookie";
    } else if (totalXp < 400) {
      targetXp = 400;
      previousBoundary = 200;
      nextRank = "Apprentice";
    } else if (totalXp < 1000) {
      targetXp = 1000;
      previousBoundary = 400;
      nextRank = "Practitioner";
    } else if (totalXp < 2500) {
      targetXp = 2500;
      previousBoundary = 1000;
      nextRank = "Master";
    } else {
      // If they beat 2500 XP, the bar just stays at 100% full forever
      targetXp = totalXp;
      previousBoundary = 2500;
      nextRank = "Max Rank Achieved!";
    }

    // Calculate the percentage filled from the previous rank to the next
    double progress = 1.0;
    if (targetXp > previousBoundary) {
      progress = (totalXp - previousBoundary) / (targetXp - previousBoundary);
    }
    progress = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dt.showProgressMarkers) ...[
          Text(
            totalXp >= 2500 
                ? '⭐ $nextRank'
                : 'Next Rank ($nextRank): $totalXp / $targetXp XP',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: dt.xpAccentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
          ),
          const SizedBox(height: 6),
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
