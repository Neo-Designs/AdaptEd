import '../../features/screening/scoring_engine.dart';

class QuizService {
  // Returns a list of 100 hardcoded questions for the assessment.
  // Covering Autism, ADHD, Dyslexia, and Dyspraxia.
  static List<Map<String, dynamic>> getQuestions() {
    return [
      // --- AUTISM SPECTRUM TRAITS (1-25) ---
      {
        'question': "1. I often notice small sounds when others do not.",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "2. I usually concentrate more on the small details than the big picture.",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "3. I find it easy to do more than one thing at once.",
        'answers': _getReverseLikertAnswers(Trait.autism), // Reverse scoring
      },
      {
        'question': "4. If there is an interruption, I can switch back to what I was doing very quickly.",
        'answers': _getReverseLikertAnswers(Trait.autism),
      },
      {
        'question': "5. I find it easy to ‘read between the lines’ when someone is talking to me.",
        'answers': _getReverseLikertAnswers(Trait.autism),
      },
    

      // --- ADHD TRAITS (26-50) ---
      {
        'question': "6. I have difficulty sustaining attention in tasks or play activities.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "7. I fail to give close attention to details or make careless mistakes.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "8. I do not seem to listen when spoken to directly (mind seems elsewhere).",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "9. I do not follow through on instructions and fail to finish duties.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "10. I have trouble estimating how long things will take (time blindness).",
        'answers': _getLikertAnswers(Trait.adhd),
      },

      // --- DYSLEXIA TRAITS (51-75) ---
      {
        'question': "11. I read slowly and with much effort.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "12. I often lose my place when reading.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "13. I find it hard to understand what I have read.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "14. I confuse similar-looking words or letters (e.g., b and d).",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "15. I am good at seeing the 'big picture' in concepts.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },

      // --- DYSPRAXIA TRAITS (76-100) ---
      {
        'question': "16. I am often described as clumsy.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "17. I bump into furniture or doorways often.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "18. I have poor balance or coordination.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "19. I struggled to learn to ride a bike or drive.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "20. I often trip over my own feet.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
    ];
  }

  static List<Map<String, dynamic>> _getLikertAnswers(Trait trait) {
    return [
      {'text': 'Definitely Agree', 'trait': trait, 'weight': 5},
      {'text': 'Slightly Agree', 'trait': trait, 'weight': 3},
      {'text': 'Slightly Disagree', 'trait': trait, 'weight': 1},
      {'text': 'Definitely Disagree', 'trait': trait, 'weight': 0},
    ];
  }

  static List<Map<String, dynamic>> _getReverseLikertAnswers(Trait trait) {
    return [
      {'text': 'Definitely Agree', 'trait': trait, 'weight': 0},
      {'text': 'Slightly Agree', 'trait': trait, 'weight': 1},
      {'text': 'Slightly Disagree', 'trait': trait, 'weight': 3},
      {'text': 'Definitely Disagree', 'trait': trait, 'weight': 5},
    ];
  }
}
