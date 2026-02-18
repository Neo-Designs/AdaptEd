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

      int currentXP = snapshot.data()?['xp'] ?? 0;
      int newXP = currentXP + amount;
      int newLevel = (newXP / xpPerLevel).floor() + 1;

      transaction.update(docRef, {
        'xp': newXP,
        'level': newLevel,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
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
