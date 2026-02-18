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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Your Progress", style: theme.titleStyle.copyWith(fontSize: 24)),
            const SizedBox(height: 16),
            _buildStatsCard(theme),
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
          final xp = data?['xp'] ?? 0;
          
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.primaryColor, theme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Level $level",
                  style: theme.titleStyle.copyWith(color: Colors.white, fontSize: 32),
                ),
                const SizedBox(height: 8),
                Text(
                  "$xp XP Earned",
                  style: theme.bodyStyle.copyWith(color: Colors.white.withOpacity(0.9), fontSize: 18),
                ),
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  value: (xp % 500) / 500, 
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 8),
                 Text(
                  "${500 - (xp % 500)} XP to next level",
                  style: theme.bodyStyle.copyWith(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          );
        }
      );
  }
  
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
                  backgroundColor: theme.secondaryColor,
                  child: Text("${data['score']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                ),
                title: Text("Quiz Score: ${data['score']}/${data['total']}"),
                subtitle: Text("Difficulty: ${data['difficulty']} • +${data['xpEarned']} XP"),
                trailing: Text(DateFormat('MM/dd').format(date)),
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
        if (snapshot.data!.docs.isEmpty) return const Text("No recent activity.");

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            
            return ListTile(
              dense: true,
              leading: Icon(Icons.history, size: 16, color: Colors.grey[600]),
              title: Text(data['description'] ?? 'Activity'),
              trailing: Text(DateFormat('HH:mm').format(date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            );
          },
        );
      },
    );
  }
}
