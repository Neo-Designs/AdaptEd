import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/theme/dynamic_theme.dart';
import '../../core/services/gamification_service.dart';
import '../../core/services/firestore_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final GamificationService _gamificationService = GamificationService();
  final FirestoreService _firestoreService = FirestoreService();
  Stream<DocumentSnapshot>? _userStatsStream;

  @override
  void initState() {
    super.initState();
    _userStatsStream = _gamificationService.getUserStats();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DynamicTheme>(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text("My Learning Journey"),
        backgroundColor: theme.backgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsCard(theme),
            const SizedBox(height: 24),
            _buildStreakSection(theme),
            const SizedBox(height: 24),
            Text("Recent Quizzes", style: theme.titleStyle.copyWith(fontSize: 20)),
            const SizedBox(height: 12),
            _buildQuizHistory(theme),
            const SizedBox(height: 24),
            Text("Activity Log", style: theme.titleStyle.copyWith(fontSize: 20)),
            const SizedBox(height: 12),
            _buildActivityLog(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(DynamicTheme theme) {
    return StreamBuilder<DocumentSnapshot>(
        stream: _userStatsStream,
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final level = data?['level'] ?? 1;
          final totalXp = data?['total_xp'] ?? 20; // UPDATED to match Point System

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.primaryColor, theme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Level $level", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                Text("$totalXp Total XP Earned", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (totalXp % 500) / 500,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text("${500 - (totalXp % 500)} XP to next level", style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          );
        }
    );
  }

  Widget _buildStreakSection(DynamicTheme theme) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStatsStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        // FIXED: changed from 'consecutive_login_days' to 'streak'
        final streak = data?['streak'] ?? 0;

        return Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: Icon(
              Icons.local_fire_department,
              color: streak > 0 ? Colors.orange : Colors.grey,
              size: 32,
            ),
            title: Text(
              "$streak Day Streak!",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              streak >= 7
                  ? "You've earned the 'Streak Master' badge! 🏆"
                  : streak == 0
                  ? "Log in daily to start your streak! 🔥"
                  : "Keep it up for ${7 - streak} more days to earn a badge!",
            ),
          ),
        );
      },
    );
  }

  // Quiz History and Activity Log remain the same, just ensured they use correct padding
  Widget _buildQuizHistory(DynamicTheme theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getQuizResults(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Text("No quizzes taken yet.");

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  child: Text("${data['score']}", style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                ),
                title: Text("Score: ${data['score']}/${data['total']}"),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(date)),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActivityLog(DynamicTheme theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getActivityLogs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              return ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                title: Text(data['description'] ?? 'Activity'),
                trailing: Text(DateFormat('HH:mm').format(date)),
              );
            },
          ),
        );
      },
    );
  }
}