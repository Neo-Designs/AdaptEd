import 'package:adapted/core/theme/dynamic_theme.dart';
import 'package:adapted/core/widgets/adapted_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'quiz_screen.dart';

class QuizIntroductionScreen extends StatelessWidget {
  const QuizIntroductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dt = context.watch<DynamicTheme>();

    return Scaffold(
      backgroundColor: dt.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ← Icon color reacts to traits
              Icon(Icons.psychology, size: 80, color: dt.primaryColor),
              const SizedBox(height: 32),
              Text(
                "We'd love to learn about how you learn!",
                style: dt.titleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "Help us by finishing this quick quiz and we'll adapt the experience just for you!",
                style: dt.bodyStyle.copyWith(
                    color: dt.onSurfaceTextColor.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // ← AdaptedButton replaces ElevatedButton
              AdaptedButton(
                label: 'Start Quiz',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const QuizScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
