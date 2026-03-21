import 'package:adapted/core/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../features/screening/scoring_engine.dart';
import '../utils/logger.dart';

class UserService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserTraits? _currentTraits;
  UserTraits? get currentTraits => _currentTraits;

  String _role = 'learner';
  String get role => _role;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _manualTutorialTrigger = false;
  bool get manualTutorialTrigger => _manualTutorialTrigger;

  UserService() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _loadUserProfile();
      } else {
        // OPTIMIZATION: Clear state when the user logs out to prevent data leaks!
        _currentTraits = null;
        _role = 'learner';
        _isInitialized = false;
        notifyListeners();
      }
    });
  }

  // Tells the tutorial to be started when called
  void startGlobalTutorialSequence() {
    _manualTutorialTrigger = true;
    notifyListeners();
  }

  // Resets triggers safely without causing build loops
  void clearTutorialTrigger() {
    _manualTutorialTrigger = false;
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('traits')) {
          _currentTraits = UserTraits.fromJson(data['traits']);
        }
        _role = data['role'] ?? 'learner';
      }
    } catch (e) {
      AppLogger.error('Failed to load user profile', error: e);
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> saveUserProfile(UserTraits traits) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final data = {
        'traits': traits.toJson(),
        'hasCompletedQuiz': true,
        'email': user.email,
        'displayName': user.displayName,
        'role': _determineRole(user.email),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(user.uid).set(data, SetOptions(merge: true));

      _currentTraits = traits;
      _role = data['role'] as String;
      notifyListeners();
      AppLogger.info('User profile saved successfully', tag: 'UserService');
    } catch (e, stack) {
      AppLogger.error('Failed to save user profile', tag: 'UserService', error: e, stackTrace: stack);
      rethrow;
    }
  }

  String _determineRole(String? email) {
    if (email != null && email.toLowerCase().startsWith('admin')) {
      return 'admin';
    }
    return 'learner';
  }

  Future<bool> hasCompletedQuiz() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.exists && (doc.data()?['hasCompletedQuiz'] ?? false);
    } catch (e) {
      return false;
    }
  }

  Future<void> updateUserProfile({String? displayName, String? email, String? photoURL}) async {
    final user = _auth.currentUser;
    if(user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        if(displayName != null) 'displayName': displayName,
        if(email != null) 'email': email,
        if(photoURL != null) 'photoURL': photoURL,
      }, SetOptions(merge: true));
      AppLogger.info('User profile updated', tag: 'UserService');
    } catch (e, stack) {
      AppLogger.error('Failed to update user profile', tag: 'UserService', error: e, stackTrace: stack);
    }
  }

  Future<void> markTutorialAsComplete() async {
    final user = _auth.currentUser;
    if(user == null || _currentTraits == null) return;

    try {
      _currentTraits = _currentTraits!.copyWith(hasSeenTutorial: true);

      await _firestore.collection('users').doc(user.uid).update({
        'traits': _currentTraits!.toJson(),
      });

      notifyListeners();
      AppLogger.info('Tutorial marked as complete');

    } catch (e) {
      AppLogger.error('Failed to mark tutorial as complete', error: e);
    }
  }
}