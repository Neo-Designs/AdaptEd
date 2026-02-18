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

  UserTraits({
    this.isAutistic = false,
    this.isADHD = false,
    this.isDyslexic = false,
    this.isDyspraxic = false,
    this.learningProfileName = 'The Adaptive Learner',
  });

  factory UserTraits.standard() => UserTraits();

  Map<String, dynamic> toJson() {
    return {
      'isAutistic': isAutistic,
      'isADHD': isADHD,
      'isDyslexic': isDyslexic,
      'isDyspraxic': isDyspraxic,
      'learningProfileName': learningProfileName,
    };
  }

  factory UserTraits.fromJson(Map<String, dynamic> json) {
    return UserTraits(
      isAutistic: json['isAutistic'] ?? false,
      isADHD: json['isADHD'] ?? false,
      isDyslexic: json['isDyslexic'] ?? false,
      isDyspraxic: json['isDyspraxic'] ?? false,
      learningProfileName: json['learningProfileName'] ?? 'The Adaptive Learner',
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
          learningProfileName == other.learningProfileName;

  @override
  int get hashCode =>
      isAutistic.hashCode ^
      isADHD.hashCode ^
      isDyslexic.hashCode ^
      isDyspraxic.hashCode ^
      learningProfileName.hashCode;
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

  UserTraits calculateProfile() {
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
