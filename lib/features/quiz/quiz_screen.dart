import 'package:adapted/core/services/quiz_service.dart';
import 'package:adapted/core/services/user_service.dart';
import 'package:adapted/core/theme/dynamic_theme.dart';
import 'package:adapted/core/widgets/adapted_button.dart';
import 'package:adapted/features/screening/scoring_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'quiz_result_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final PageController _pageController = PageController();
  final ScoringEngine _engine = ScoringEngine();
  int _currentIndex = 0;
  bool _isAnalyzing = false;

  final List<Map<String, dynamic>> _questions = QuizService.getQuestions();

  void _handleAnswer(Map<String, dynamic> answer) async {
    _engine.answerQuestion(answer['trait'] as Trait, answer['weight'] as int);

    if (_currentIndex < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentIndex++;
      });
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() async {
    setState(() {
      _isAnalyzing = true;
    });

        final traits = _engine.calculateProfile();
    
    // Retrieve the global UserService instance from the Provider tree.
    // listen: false gives us access to call methods without triggering a rebuild here.
    final globalUserService = Provider.of<UserService>(context, listen: false);
    
    await globalUserService.saveUserProfile(traits);

    if (mounted) {
      Provider.of<DynamicTheme>(context, listen: false).setTraits(traits);

      String description = "You have a unique way of seeing the world! ";
      if (traits.isAutistic) {
        description += "You likely value structure and clarity. ";
      }
      if (traits.isADHD) {
        description += "Your mind moves fast and makes amazing connections. ";
      }
      if (traits.isDyslexic) {
        description +=
            "You may prefer auditory learning and visual storytelling. ";
      }
      if (traits.isDyspraxic) {
        description += "You learn best by doing and experiencing. ";
      }
      if (description == "You have a unique way of seeing the world! ") {
        description +=
            "You are a versatile learner who adapts to many situations.";
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => QuizResultScreen(
            profileName: traits.learningProfileName,
            description: description,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ← Get theme so quiz screen reacts to traits
    final dt = context.watch<DynamicTheme>();

    if (_isAnalyzing) {
      return Scaffold(
        backgroundColor: dt.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: dt.primaryColor),
              const SizedBox(height: 16),
              Text(
                "Analyzing your learning style...",
                style: dt.bodyStyle,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: dt.backgroundColor, // ← trait-aware background
      appBar: AppBar(
        title: Text(
          "Question ${_currentIndex + 1}/${_questions.length}",
          style: dt.titleStyle,
        ),
        elevation: 0,
        backgroundColor: dt.backgroundColor,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ← XP-style progress bar using theme colors
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(dt.primaryColor),
              minHeight: 6,
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final question = _questions[index];
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          question['question'],
                          style: dt.titleStyle.copyWith(height: 1.3),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        // ← AdaptedButton replaces ElevatedButton
                        ...(question['answers'] as List<Map<String, dynamic>>)
                            .map((answer) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: AdaptedButton(
                              label: answer['text'],
                              onPressed: () => _handleAnswer(answer),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
