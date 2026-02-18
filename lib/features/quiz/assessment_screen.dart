import 'package:flutter/material.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/gamification_service.dart';

class AssessmentScreen extends StatefulWidget {
  final String? content; // New: Pass content to generate quiz from
  const AssessmentScreen({super.key, this.content});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final AIService _aiService = AIService();
  final GamificationService _gamificationService = GamificationService();
  
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  int _score = 0;
  bool _submitted = false;
  Map<int, int> _answers = {};

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  void _loadQuiz() async {
    if (widget.content == null || widget.content!.isEmpty) {
      // Fallback or use mock if no content
      setState(() {
        _questions = [
          {
            'question': "What was the main topic of the last summary you studied?",
            'options': ["Option A", "Option B", "Option C", "Option D"],
            'correctIndex': 0,
          },
        ];
        _isLoading = false;
      });
      return;
    }

    try {
      final quiz = await _aiService.generateQuiz(widget.content!);
      if (mounted) {
        setState(() {
          _questions = quiz;
          _isLoading = false;
        });
      }
    } catch (e) {
       if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to generate quiz: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Knowledge Assessment")),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    "Revision Quiz", 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Test your knowledge of the adapted material.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final q = _questions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Q${index + 1}: ${q['question']}",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ...List.generate((q['options'] as List).length, (optIndex) {
                                return RadioListTile<int>(
                                  title: Text(q['options'][optIndex]),
                                  value: optIndex,
                                  groupValue: _answers[index],
                                  onChanged: _submitted ? null : (val) {
                                    setState(() {
                                      _answers[index] = val!;
                                    });
                                  },
                                );
                              }),
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
                              if (_questions[qIndex]['correctIndex'] == aIndex) {
                                correctCount++;
                              }
                            });

                            setState(() {
                              _submitted = true;
                              _score = correctCount;
                            });

                            // Award XP: 10 per correct answer
                            await _gamificationService.awardXP(correctCount * GamificationService.xpPerCorrectAnswer);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("You scored $_score/${_questions.length}! You earned ${_score * 10} XP!")),
                              );
                            }
                          },
                    child: Text(_submitted ? "Return to Dashboard" : "Submit Answers"),
                  ),
                ],
              ),
            ),
    );
  }
}
