import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GamificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int xpPerLevel = 500;
  static const int xpDailyLogin = 10;
  static const int xpIntroQuiz = 30;
  static const int xpRevision = 20;

  // Changed return type to Future<List<String>> so UI can react to badge awards
  Future<List<String>> handleEvent(String eventType, {double? quizScore}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final docRef = _firestore.collection('users').doc(user.uid);
    List<String> newEarnedBadges = [];

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      int currentXP = data['total_xp'] ?? 20;
      int revisionCounter = data['total_revision_counter'] ?? 0;
      List<dynamic> currentBadges = data['badges_earned'] ?? [];
      int currentStreak = data['streak'] ?? 0;

      int xpToAdd = 0;
      bool updateLoginDate = false;

      if (eventType == 'daily_login') {
        Timestamp? lastLoginTs = data['last_login_date'];
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);

        if (lastLoginTs == null) {
          currentStreak = 1;
          xpToAdd = xpDailyLogin;
          updateLoginDate = true;
        } else {
          DateTime lastLoginDate = lastLoginTs.toDate();
          DateTime lastLoginDay = DateTime(
            lastLoginDate.year,
            lastLoginDate.month,
            lastLoginDate.day,
          );

          int dayDifference = today.difference(lastLoginDay).inDays;

          if (dayDifference == 1) {
            currentStreak += 1;
            xpToAdd = xpDailyLogin;
            updateLoginDate = true;
          } else if (dayDifference > 1) {
            currentStreak = 1;
            xpToAdd = xpDailyLogin;
            updateLoginDate = true;
          } else if (dayDifference == 0) {
            xpToAdd = 0;
          }
        }
      } else if (eventType == 'intro_quiz') {
        xpToAdd = xpIntroQuiz;
      } else if (eventType == 'revision') {
        xpToAdd = xpRevision;
        revisionCounter++;
      }

      int newXP = currentXP + xpToAdd;
      int newLevel = (newXP / xpPerLevel).floor() + 1;

      // XP threshold badges
      if (newXP >= 100 && !currentBadges.contains('Newbie'))
        newEarnedBadges.add('Newbie');
      if (newXP >= 200 && !currentBadges.contains('Rookie'))
        newEarnedBadges.add('Rookie');
      if (newXP >= 400 && !currentBadges.contains('Apprentice'))
        newEarnedBadges.add('Apprentice');
      if (newXP >= 1000 && !currentBadges.contains('Practitioner'))
        newEarnedBadges.add('Practitioner');
      if (newXP >= 2500 && !currentBadges.contains('Master'))
        newEarnedBadges.add('Master');

      // Revision counter badges
      if (revisionCounter >= 2 && !currentBadges.contains('Bronze'))
        newEarnedBadges.add('Bronze');
      if (revisionCounter >= 5 && !currentBadges.contains('Silver'))
        newEarnedBadges.add('Silver');
      if (revisionCounter >= 10 && !currentBadges.contains('Gold'))
        newEarnedBadges.add('Gold');

      // Quiz performance badge
      if (quizScore == 100.0 && !currentBadges.contains('All Star'))
        newEarnedBadges.add('All Star');

      // Streak badge
      if (currentStreak >= 7 && !currentBadges.contains('Streak Master'))
        newEarnedBadges.add('Streak Master');

      Map<String, dynamic> updates = {
        'total_xp': newXP,
        'level': newLevel,
        'total_revision_counter': revisionCounter,
        'streak': currentStreak,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (updateLoginDate) {
        updates['last_login_date'] = Timestamp.fromDate(DateTime.now());
      }

      if (newEarnedBadges.isNotEmpty) {
        updates['badges_earned'] = FieldValue.arrayUnion(newEarnedBadges);
      }

      transaction.update(docRef, updates);
    });

    return newEarnedBadges;
  }

  Stream<DocumentSnapshot> getUserStats() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(_auth.currentUser?.uid)
        .snapshots();
  }
}