import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GamificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // XP Rules from Documentation
  static const int xpPerLevel = 500;
  static const int xpDailyLogin = 10; // [cite: 18, 20]
  static const int xpIntroQuiz = 30;   // [cite: 17, 20]
  static const int xpRevision = 20;    // [cite: 19, 20]

  // Main event handler to update XP and check for badges
  Future<void> handleEvent(String eventType, {double? quizScore}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      int currentXP = data['total_xp'] ?? 20; // Starts at 20 [cite: 16, 21]
      int sessionCounter = data['tasks_session_counter'] ?? 0; // [cite: 23]
      List<dynamic> currentBadges = data['badges_earned'] ?? []; //

      int xpToAdd = 0;

      // Logic for XP distribution
      switch (eventType) {
        case 'daily_login': xpToAdd = xpDailyLogin; break;
        case 'intro_quiz': xpToAdd = xpIntroQuiz; break;
        case 'revision':
          xpToAdd = xpRevision;
          sessionCounter++; // Increment for Bronze/Silver/Gold [cite: 14]
          break;
      }

      int newXP = currentXP + xpToAdd;
      int newLevel = (newXP / xpPerLevel).floor() + 1; // Level calculation

      // Logic for Badge awarding [cite: 2-10, 14]
      List<String> newEarnedBadges = [];

      // XP Threshold Badges [cite: 2-6]
      if (newXP >= 100 && !currentBadges.contains('Newbie')) newEarnedBadges.add('Newbie');
      if (newXP >= 200 && !currentBadges.contains('Rookie')) newEarnedBadges.add('Rookie');
      if (newXP >= 400 && !currentBadges.contains('Apprentice')) newEarnedBadges.add('Apprentice');
      if (newXP >= 1000 && !currentBadges.contains('Practitioner')) newEarnedBadges.add('Practitioner');
      if (newXP >= 2500 && !currentBadges.contains('Master')) newEarnedBadges.add('Master');

      // Session/Performance Badges [cite: 7-10, 14]
      if (sessionCounter >= 2 && !currentBadges.contains('Bronze')) newEarnedBadges.add('Bronze');
      if (sessionCounter >= 5 && !currentBadges.contains('Silver')) newEarnedBadges.add('Silver');
      if (sessionCounter >= 10 && !currentBadges.contains('Gold')) newEarnedBadges.add('Gold');
      if (quizScore == 100.0 && !currentBadges.contains('All Star')) newEarnedBadges.add('All Star');

      transaction.update(docRef, {
        'total_xp': newXP,
        'level': newLevel,
        'tasks_session_counter': sessionCounter,
        if (newEarnedBadges.isNotEmpty)
          'badges_earned': FieldValue.arrayUnion(newEarnedBadges),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    });
  }

  // Reset counter on logout
  Future<void> resetSession() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'tasks_session_counter': 0,
    });
  }

  Stream<DocumentSnapshot> getUserStats() {
    return _firestore.collection('users').doc(_auth.currentUser?.uid).snapshots();
  }
}
