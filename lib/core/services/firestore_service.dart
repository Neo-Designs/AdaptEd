import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'gamification_service.dart';

import 'ai_service.dart'; // Import AIService
import '../../features/screening/scoring_engine.dart'; // Import UserTraits

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GamificationService _gamificationService = GamificationService();
  final AIService _aiService = AIService(); // Instantiate AIService

  // --- Collection References ---
  CollectionReference get _users => _firestore.collection('users');
  CollectionReference get _learningMaterials => _firestore.collection('learning_materials');
  CollectionReference get _quizzes => _firestore.collection('quizzes');
  CollectionReference get _chats => _firestore.collection('chats');
  CollectionReference get _activityLogs => _firestore.collection('activity_logs');
  
  // Specific Demo Doc ID requested by User
  final String _demoDocId = 'P0J3a90aQdfuJ66pLydw3htf7bH3';

  User? get currentUser => _auth.currentUser;

  // --- 1. PDF Metadata & Summary Logic ---
  Future<String> uploadPdfToStorage(Uint8List bytes, String fileName, String userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'uploads/$userId/${timestamp}_$fileName';
    final ref = _storage.ref().child(path);
    
    final metadata = SettableMetadata(contentType: 'application/pdf');
    await ref.putData(bytes, metadata);
    return await ref.getDownloadURL();
  }

  Future<String> saveLearningMaterial({
    required String title,
    required String summary,
    required String fullText,
    required String fileUrl,
    required UserTraits userTraits, 
  }) async {
    if (currentUser == null) throw Exception("User not logged in");

    // Save with adaptation metadata based on traits
    final docRef = _learningMaterials.doc();
    await docRef.set({
      'id': docRef.id,
      'userId': currentUser!.uid,
      'title': title,
      'summary': summary,
      'fullText': fullText, 
      'fileUrl': fileUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'adaptationMetadata': {
         'generatedFor': userTraits.learningProfileName,
         'isDyslexicFriendly': userTraits.isDyslexic,
         'isConcise': userTraits.isADHD,
      }
    });

    await _logActivity('uploaded_material', 'Uploaded $title');
    return docRef.id;
  }

  // --- 2. Adaptive Quiz Engine ---
  
  // A. Fetch Quiz with Auto-Generation
  Future<List<Map<String, dynamic>>> getQuizForMaterial(String materialId) async {
    // 1. Check if quiz exists
    final snapshot = await _quizzes.where('materialId', isEqualTo: materialId).limit(1).get();
    
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data() as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['questions'] ?? []);
    }
    
    // 2. If not, Fetch Material Content first
    final materialDoc = await _learningMaterials.doc(materialId).get();
    if (!materialDoc.exists) {
      return [];
    }

    // 3. Generate Quiz via AI
    final data = materialDoc.data() as Map<String, dynamic>;
    String contentToQuiz = data['summary'] ?? ""; // prioritize summary
    if (contentToQuiz.length < 50) {
       contentToQuiz = data['fullText'] ?? ""; 
    }

    if (contentToQuiz.isNotEmpty) {
      final List<Map<String, dynamic>> questions = await _aiService.generateQuiz(contentToQuiz);
      if (questions.isNotEmpty) {
        // 4. Save Generated Quiz
        await saveQuiz(materialId, questions);
        return questions;
      }
    }
    
    return []; 
  }

  // B. Save Generated Quiz
  Future<void> saveQuiz(String materialId, List<Map<String, dynamic>> questions) async {
     final docRef = _quizzes.doc();
     await docRef.set({
       'id': docRef.id,
       'materialId': materialId,
       'questions': questions,
       'createdAt': FieldValue.serverTimestamp(),
       'difficulty': 'adaptive', 
     });
  }

  // C. Submit Quiz Result & Adaptive XP Logic
  // Formula: (Correct Answers * Difficulty) + Bonus (Streak >= 3)
  Future<Map<String, dynamic>> submitQuizResult({
    required String quizId,
    required int correctAnswers,
    required int totalQuestions,
    required int difficultyLevel, // 1 (Easy) to 5 (Hard)
    required int longestStreak,
  }) async {
    if (currentUser == null) throw Exception("User not logged in");

    // Adaptive Calculation
    int baseXP = (correctAnswers * 10 * difficultyLevel); 
    int bonusXP = (longestStreak >= 3) ? 50 : 0; 
    int totalXP = baseXP + bonusXP;

    // Sync to Current User & Demo Profile (P0J3a90aQdfuJ66pLydw3htf7bH3)
    await _gamificationService.awardXP(totalXP);
    await _syncToDemoProfile(totalXP);

    // Save Result
    await _users.doc(currentUser!.uid).collection('quiz_results').add({
      'quizId': quizId,
      'score': correctAnswers,
      'total': totalQuestions,
      'difficulty': difficultyLevel,
      'xpEarned': totalXP,
      'streak': longestStreak,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _logActivity('completed_quiz', 'Completed quiz ($correctAnswers/$totalQuestions correct)');

    return {
      'xpEarned': totalXP,
      'completed': true,
    };
  }
  
  // --- 3. Chat Persistence ---
  Stream<QuerySnapshot> getChatMessages() {
    if (currentUser == null) return const Stream.empty();
    
    return _chats
        .doc(currentUser!.uid)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> saveChatMessage(String role, String text) async {
    if (currentUser == null) return;
    
    await _chats.doc(currentUser!.uid).collection('messages').add({
      'role': role,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- 4. Activity Logs & Streams ---
  
  Stream<QuerySnapshot> getLearningMaterials() {
    if (currentUser == null) return const Stream.empty();
    return _learningMaterials
        .where('userId', isEqualTo: currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getQuizResults() {
    if (currentUser == null) return const Stream.empty();
    return _users
        .doc(currentUser!.uid)
        .collection('quiz_results')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots();
  }
  
  Stream<QuerySnapshot> getActivityLogs() {
    if (currentUser == null) return const Stream.empty();
    return _activityLogs
        .where('userId', isEqualTo: currentUser!.uid)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<void> logActivity(String type, String description) async {
    await _logActivity(type, description);
  }

  Future<void> _logActivity(String type, String description) async {
    if (currentUser == null) return;
    await _activityLogs.add({
      'userId': currentUser!.uid,
      'type': type,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  
  // --- XP Sync to Specific Doc ID ---
  Future<void> _syncToDemoProfile(int xpToAdd) async {
      try {
        final demoDocRef = _users.doc(_demoDocId);
        final snapshot = await demoDocRef.get();
        
        if (snapshot.exists) {
           final data = snapshot.data() as Map<String, dynamic>;
           int currentXP = data['xp'] ?? 0;
           int newXP = currentXP + xpToAdd;
           int newLevel = (newXP / 500).floor() + 1;

           await demoDocRef.update({
              'xp': newXP,
              'level': newLevel,
              'lastUpdated': FieldValue.serverTimestamp()
           });
        } else {
           // Create if missing (Adaptive fallback)
           await demoDocRef.set({
              'xp': xpToAdd,
              'level': 1,
              'role': 'learner',
              'label': 'Deep Diver & Sprinter', // Default label
              'lastUpdated': FieldValue.serverTimestamp()
           });
        }
      } catch (e) {
        // Fallback or log if demo user access restricted, usually shouldn't block main flow
        print("Demo sync failed: $e");
      }
  }
}
