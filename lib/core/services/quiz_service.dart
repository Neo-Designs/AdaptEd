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
      {
        'question': "6. I know how to tell if someone listening to me is getting bored.",
        'answers': _getReverseLikertAnswers(Trait.autism),
      },
      {
        'question': "7. When I’m reading, I find it easy to work out the characters’ intentions.",
        'answers': _getReverseLikertAnswers(Trait.autism),
      },
      {
        'question': "8. I like to collect information about categories of things (e.g. types of cars, birds, trains, plants).",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "9. I find it easy to work out what someone is thinking or feeling just by looking at their face.",
        'answers': _getReverseLikertAnswers(Trait.autism),
      },
      {
        'question': "10. I find it difficult to work out people’s intentions.",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "11. I prefer to do things the same way over and over again.",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "12. I frequently get strongly absorbed in one thing.",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "13. I can tell if someone is masking their true emotions.",
        'answers': _getReverseLikertAnswers(Trait.autism),
      },
      {
        'question': "14. I am not very good at remembering phone numbers.",
        'answers': _getLikertAnswers(Trait.autism), // Context dependent, but often rote memory is specific
      },
      {
        'question': "15. I usually notice car number plates or similar strings of information.",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "16. I find social situations confusing.",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "17. I find it hard to make new friends.",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "18. I would rather go to a library than a party.",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "19. I find myself drawn more to things than people.",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "20. I tend to have very strong interests which I get upset if I can't pursue.",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "21. I enjoy social chit-chat.",
        'answers': _getReverseLikertAnswers(Trait.autism),
      },
      {
        'question': "22. When I talk, it isn't always easy for others to get a word in edgeways.",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "23. I am fascinated by dates.",
        'answers': _getLikertAnswers(Trait.autism),
      },
      {
        'question': "24. I find it easy to imagine characters in a book.",
        'answers': _getReverseLikertAnswers(Trait.autism),
      },
      {
        'question': "25. I find it difficult to execute tasks that require imagination.",
        'answers': _getLikertAnswers(Trait.autism),
      },

      // --- ADHD TRAITS (26-50) ---
      {
        'question': "26. I have difficulty sustaining attention in tasks or play activities.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "27. I fail to give close attention to details or make careless mistakes.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "28. I do not seem to listen when spoken to directly (mind seems elsewhere).",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "29. I do not follow through on instructions and fail to finish duties.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "30. I have difficulty organizing tasks and activities.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "31. I avoid, dislike, or am reluctant to engage in tasks requiring sustained mental effort.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "32. I lose things necessary for tasks or activities (e.g., tools, wallets, keys).",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "33. I am easily distracted by extraneous stimuli.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "34. I am forgetful in daily activities.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "35. I fidget with hands or feet or squirm in seat.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "36. I leave my seat in classroom or in other situations in which remaining seated is expected.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "37. I run about or climb excessively in situations in which it is inappropriate.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "38. I have difficulty playing or engaging in leisure activities quietly.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "39. I am 'on the go' or often act as if 'driven by a motor'.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "40. I talk excessively.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "41. I blurt out answers before questions have been completed.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "42. I have difficulty awaiting my turn.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "43. I interrupt or intrude on others (e.g., butt into conversations or games).",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "44. I make decisions impulsively.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "45. I have a short fuse or temper outbursts.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "46. I have mood swings.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "47. I feel restless inside.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "48. I struggle to get started on tasks (procrastination).",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "49. I hyperfocus on things I enjoy for hours.",
        'answers': _getLikertAnswers(Trait.adhd),
      },
      {
        'question': "50. I have trouble estimating how long things will take (time blindness).",
        'answers': _getLikertAnswers(Trait.adhd),
      },

      // --- DYSLEXIA TRAITS (51-75) ---
      {
        'question': "51. I read slowly and with much effort.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "52. I often lose my place when reading.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "53. I find it hard to understand what I have read.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "54. I confuse similar-looking words or letters (e.g., b and d).",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "55. I have difficulty with spelling.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "56. I find it hard to take notes while listening.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "57. I prefer practical or visual learning to reading books.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "58. I struggle to remember sequences of instructions.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "59. I have difficulty pronouncing long words.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "60. I reverse numbers or letters when writing.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "61. I find it easier to explain things verbally than in writing.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "62. I struggled with learning to read in school.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "63. I confuse left and right often.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "64. I find maps or timetables confusing.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "65. I often forget names of people or places.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "66. I have good creative or visual problem-solving skills.",
        'answers': _getLikertAnswers(Trait.dyslexia), // Positive trait often associated
      },
      {
        'question': "67. I omit words when reading aloud.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "68. I get headaches or eye strain when reading.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "69. I avoid reading aloud in public.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "70. I find it hard to learn foreign languages.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "71. I rely on spell-check heavily.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "72. I find that letters seem to move or blur on the page.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "73. I have difficulty organizing written work.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "74. I have strong intuition.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },
      {
        'question': "75. I am good at seeing the 'big picture' in concepts.",
        'answers': _getLikertAnswers(Trait.dyslexia),
      },

      // --- DYSPRAXIA TRAITS (76-100) ---
      {
        'question': "76. I am often described as clumsy.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "77. I bump into furniture or doorways often.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "78. I have poor balance or coordination.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "79. I struggled to learn to ride a bike or drive.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "80. I have messy handwriting.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "81. I find it hard to use tools like scissors or cutlery.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "82. I spill drinks or drop items frequently.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "83. I have difficulty with organization and planning (executive function).",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "84. I find it hard to judge distances or speed.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "85. I have poor posture or muscle tone.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "86. I struggle with team sports involving balls.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "87. I am sensitive to loud noises or bright lights (sensory).",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "88. I have trouble remembering instructions.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "89. I lose items like keys or wallets often.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "90. I find it hard to sit still.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "91. I have difficulty with personal grooming (buttons, laces).",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "92. I talk loudly or fast without realizing.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "93. I find it hard to concentrate in noisy environments.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "94. I get tired easily due to the effort of coordination.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "95. I have a good long-term memory for events but poor short-term.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "96. I avoid activities that require physical skill.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "97. I have trouble with time management.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "98. I find social cues hard to read sometimes.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "99. I prefer typing to handwriting.",
        'answers': _getLikertAnswers(Trait.dyspraxia),
      },
      {
        'question': "100. I often trip over my own feet.",
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
