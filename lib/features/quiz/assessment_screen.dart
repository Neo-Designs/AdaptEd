import 'package:adapted/core/services/firestore_service.dart';
import 'package:adapted/core/theme/dynamic_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/ai_service.dart';
import '../../core/services/gamification_service.dart';

class AssessmentScreen extends StatefulWidget {
  final String? content;
  final String difficulty;
  const AssessmentScreen({super.key, this.content, this.difficulty = 'MEDIUM'});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final AIService _aiService = AIService();
  final GamificationService _gamificationService = GamificationService();
    final FirestoreService _firestoreService = FirestoreService(); // <-- ADD THIS LINE


  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  int _score = 0;
  bool _submitted = false;
  final Map<int, int> _answers = {};

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  void _loadQuiz() async {
    if (widget.content == null || widget.content!.isEmpty) {
      setState(() {
        _questions = [
          {
            'question':
                'What was the main topic of the last summary you studied?',
            'options': ['Option A', 'Option B', 'Option C', 'Option D'],
            'correctIndex': 0,
          },
        ];
        _isLoading = false;
      });
      return;
    }

    try {
final quiz = await _aiService.generateMultipleChoiceQuiz(widget.content!, difficulty: widget.difficulty);      if (mounted) {
        setState(() {
          _questions = quiz;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to generate quiz: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DynamicTheme>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge Assessment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Revision Quiz',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Test your knowledge of the adapted material.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final q = _questions[index];
                       final options = q['options'] as List<dynamic>? ?? []; 
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Q${index + 1}: ${q['question']}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ...List.generate(options.length, (oIndex) {
                                //check if this option is correct
                                final bool isCorrect = oIndex == q['correctIndex'];
                                //check if the user selected this answer
                                final bool isSelected = _answers[index] == oIndex;

                                //text color after submission
                                Color? textColor;
                                if (_submitted) {
                                  if (isCorrect) {
                                    textColor = theme.successColor; // Highlight correct answer
                                  } else if (isSelected && !isCorrect) {
                                    textColor = theme.errorColor; // Highlight wrong selection
                                  }
                                }
                                return RadioListTile<int>(
                                  title: Text(options[oIndex].toString(),
                                  style: TextStyle(color: textColor,
                                  fontWeight:  _submitted && (isCorrect || isSelected) ?
                                   FontWeight.bold : FontWeight.normal
                                   ),
                                  ),
                                  
                                  value: oIndex,
                                  groupValue: _answers[index],
                                  onChanged: _submitted ? null : (val) {
                                    setState(() {
                                      _answers[index] = val!;
                                    });
                                  },
                                    secondary: _submitted 
                                                ? (isCorrect 
                                                ? Icon(Icons.check_circle, color: theme.successColor) // <-- NO const
                                                    : isSelected 
                                                          ? Icon(Icons.cancel, color: theme.errorColor)     // <-- NO const
                                                          : null) 
                                                  : null,

                                );
                              })
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submitted
                        ? () => Navigator.pop(context)
                        : () async {
                            int correctCount = 0;
                            _answers.forEach((qIndex, aIndex) {
                              if (_questions[qIndex]['correctIndex'] ==
                                  aIndex) {
                                correctCount++;
                              }
                            });

                            setState(() {
                              _submitted = true;
                              _score = correctCount;
                            });

                                                      
                            int diffLevel = 2; // Default MEDIUM
                            if (widget.difficulty == 'HARD') diffLevel = 3;
                            if (widget.difficulty == 'EASY') diffLevel = 1;

                            
                            await _firestoreService.submitQuizResult(
                              quizId: DateTime.now().millisecondsSinceEpoch.toString(),
                              correctAnswers: correctCount,
                              totalQuestions: _questions.length,
                              difficultyLevel: diffLevel, 
                              longestStreak: 0,
                            );


                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'You scored $_score/${_questions.length}! You earned ${_score * 10} XP!')),
                            );
                          },
                    child: Text(
                        _submitted ? 'Return to Dashboard' : 'Submit Answers'),
                  ),
                ],
              ),
            ),
    );
  }
}
