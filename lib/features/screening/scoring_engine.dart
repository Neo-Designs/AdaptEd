import 'package:flutter/foundation.dart';

enum Trait {
  autism,
  adhd,
  dyslexia,
  dyspraxia,
}

class UserTraits {
  final bool isAutistic;
  final bool isADHD;
  final bool isDyslexic;
  final bool isDyspraxic;
  final String learningProfileName;
  final bool hasSeenTutorial;

  UserTraits({
    this.isAutistic = false,
    this.isADHD = false,
    this.isDyslexic = false,
    this.isDyspraxic = false,
    this.learningProfileName = 'The Adaptive Learner',
    this.hasSeenTutorial = false,
  });

  UserTraits copyWith({
    bool? isAutistic,
    bool? isADHD,
    bool? isDyslexic,
    bool? isDyspraxic,
    String? learningProfileName,
    bool? hasSeenTutorial,
}) {
    return UserTraits(
      isAutistic: isAutistic ?? this.isAutistic,
      isADHD: isADHD ?? this.isADHD,
      isDyslexic: isDyslexic ?? this.isDyslexic,
      isDyspraxic: isDyspraxic ?? this.isDyspraxic,
      learningProfileName: learningProfileName ?? this.learningProfileName,
      hasSeenTutorial: hasSeenTutorial ?? this.hasSeenTutorial,
    );
  }

  factory UserTraits.standard() => UserTraits();

  Map<String, dynamic> toJson() {
    return {
      'isAutistic': isAutistic,
      'isADHD': isADHD,
      'isDyslexic': isDyslexic,
      'isDyspraxic': isDyspraxic,
      'learningProfileName': learningProfileName,
      'hasSeenTutorial': hasSeenTutorial,
    };
  }

  factory UserTraits.fromJson(Map<String, dynamic> json) {
    return UserTraits(
      isAutistic: json['isAutistic'] ?? false,
      isADHD: json['isADHD'] ?? false,
      isDyslexic: json['isDyslexic'] ?? false,
      isDyspraxic: json['isDyspraxic'] ?? false,
      hasSeenTutorial: json['hasSeenTutorial'] ?? false,
      learningProfileName: json['learningProfileName'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserTraits &&
          runtimeType == other.runtimeType &&
          isAutistic == other.isAutistic &&
          isADHD == other.isADHD &&
          isDyslexic == other.isDyslexic &&
          isDyspraxic == other.isDyspraxic &&
          learningProfileName == other.learningProfileName &&
          hasSeenTutorial == other.hasSeenTutorial;

  @override
  int get hashCode =>
      isAutistic.hashCode ^
      isADHD.hashCode ^
      isDyslexic.hashCode ^
      isDyspraxic.hashCode ^
      learningProfileName.hashCode ^
       hasSeenTutorial.hashCode;
}

class ScoringEngine {
  // Simplified buckets for the demo. Real implementation would track per-question.
  final Map<Trait, int> _scores = {
    Trait.autism: 0,
    Trait.adhd: 0,
    Trait.dyslexia: 0,
    Trait.dyspraxia: 0,
  };

  // Thresholds for activating a trait
  static const int _threshold = 15; // Arbitrary score threshold

  void answerQuestion(Trait relatedTrait, int weight) {
    _scores[relatedTrait] = (_scores[relatedTrait] ?? 0) + weight;
  }

  UserTraits calculateProfile({bool tutorialStatus = false}) {
    final bool isAutistic = (_scores[Trait.autism] ?? 0) >= _threshold;
    final bool isADHD = (_scores[Trait.adhd] ?? 0) >= _threshold;
    final bool isDyslexic = (_scores[Trait.dyslexia] ?? 0) >= _threshold;
    final bool isDyspraxic = (_scores[Trait.dyspraxia] ?? 0) >= _threshold;

    String profileName = _determineProfileName(isAutistic, isADHD, isDyslexic, isDyspraxic);

    return UserTraits(
      isAutistic: isAutistic,
      isADHD: isADHD,
      isDyslexic: isDyslexic,
      isDyspraxic: isDyspraxic,
      learningProfileName: profileName,
      hasSeenTutorial: tutorialStatus,
    );
  }

  String _determineProfileName(bool au, bool ad, bool dy, bool dp) {
    if (au && ad) return 'The Deep Diver & Sprinter';
    if (au) return 'The Structured Voyager';
    if (ad) return 'The Rapid Explorer';
    if (dy) return 'The Auditory Architect';
    if (dp) return 'The Kinesthetic Builder';
    return 'The versatile Learner';
  }

  // Mock method to simulate a full quiz completion for testing
  void mockCompleteQuiz({required UserTraits targetTraits}) {
    // Reset
    _scores.updateAll((key, value) => 0);
    
    // Set scores above threshold based on requested traits
    if (targetTraits.isAutistic) _scores[Trait.autism] = _threshold + 5;
    if (targetTraits.isADHD) _scores[Trait.adhd] = _threshold + 5;
    if (targetTraits.isDyslexic) _scores[Trait.dyslexia] = _threshold + 5;
    if (targetTraits.isDyspraxic) _scores[Trait.dyspraxia] = _threshold + 5;
  }
}
