import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/dynamic_theme.dart';
import '../screening/scoring_engine.dart';
import '../../core/services/quiz_service.dart';
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

    try{

    final userService = Provider.of<UserService>(context, listen: false);

    final traits = _engine.calculateProfile();
    


      await userService.saveUserProfile(traits);

      if (mounted) {
        Provider.of<DynamicTheme>(context, listen: false).setTraits(traits);

        // Generate description based on traits (Mock logic for now)
        String description = "You have a unique way of seeing the world! ";
        if (traits.isAutistic) description += "You likely value structure and clarity. ";
        if (traits.isADHD) description += "Your mind moves fast and makes amazing connections. ";
        if (traits.isDyslexic) description += "You may prefer auditory learning and visual storytelling. ";
        if (traits.isDyspraxic) description += "You learn best by doing and experiencing. ";

        if (description == "You have a unique way of seeing the world! ") {
          description += "You are a versatile learner who adapts to many situations.";
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
    } catch (e) {
      if (mounted) {
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save profile. Please check your internet.")),
      );

      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Analyzing your learning style..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Question ${_currentIndex + 1}/${_questions.length}"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false, 
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
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
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        ...(question['answers'] as List<Map<String, dynamic>>).map((answer) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.2)),
                                ),
                              ),
                              onPressed: () => _handleAnswer(answer),
                              child: Text(
                                answer['text'],
                                style: const TextStyle(fontSize: 18),
                                textAlign: TextAlign.center,
                              ),
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
