import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/dynamic_theme.dart';
import 'quiz_screen.dart';

class QuizIntroductionScreen extends StatelessWidget {
  const QuizIntroductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DynamicTheme>(context);
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology, size: 80, color: theme.primaryColor),
              const SizedBox(height: 32),
              Text(
                "We'd love to learn about how you learn!",
                style: theme.titleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "Help us by finishing this quick quiz and we'll adapt the experience just for you!",
                style: theme.bodyStyle.copyWith(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 48, 
                    vertical: theme.buttonMinSize / 3,
                  ),
                  minimumSize: Size(200, theme.buttonMinSize),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const QuizScreen()),
                  );
                },
                child: Text(
                  "Start Quiz",
                  style: theme.buttonTextStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
