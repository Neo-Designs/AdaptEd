import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GamificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int xpPerSummary = 50;
  static const int xpPerCorrectAnswer = 10;
  static const int xpPerLevel = 500;

    Future<void> awardXP(int amount) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data();
      int currentXP = data?['xp'] ?? 0;
      int newXP = currentXP + amount;
      int newLevel = (newXP / xpPerLevel).floor() + 1;

      // ── XP-RANK FEATURE INTEGRATION ─────────────────────────────────────────
      // Read the user's existing badges safely
      List<dynamic> existingBadges = data?['badges'] ?? [];
      bool hasBadge(String id) => existingBadges.any((b) => b is Map && b['id'] == id);
      
      List<Map<String, dynamic>> newlyEarnedRanks = [];
      
      // Helper to cleanly award rank badges
      void checkRank(int threshold, String rankName) {
        if (newXP >= threshold && !hasBadge(rankName)) {
           newlyEarnedRanks.add({
             'id': rankName,
             'name': rankName,
             'earnedAt': DateTime.now().toIso8601String(),
           });
        }
      }

      // The XP Thresholds from the xp-branch
      checkRank(100, 'Newbie');
      checkRank(200, 'Rookie');
      checkRank(400, 'Apprentice');
      checkRank(1000, 'Practitioner');
      checkRank(2500, 'Master');
      // ────────────────────────────────────────────────────────────────────────

      // Prepare the database update payload
      Map<String, dynamic> updates = {
        'xp': newXP,
        'level': newLevel,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // If they just unlocked a new Rank, safely merge it into their badge list
      if (newlyEarnedRanks.isNotEmpty) {
        updates['badges'] = FieldValue.arrayUnion(newlyEarnedRanks);
      }

      // Commit the transaction
      transaction.update(docRef, updates);
    });
  }


  Future<void> awardBadge(String badgeId, String badgeName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    
    await docRef.update({
      'badges': FieldValue.arrayUnion([{
        'id': badgeId,
        'name': badgeName,
        'earnedAt': DateTime.now().toIso8601String(),
      }])
    });
  }

  Stream<DocumentSnapshot> getUserStats() {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    return _firestore.collection('users').doc(user.uid).snapshots();
  }
}
