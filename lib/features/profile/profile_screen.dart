import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/dynamic_theme.dart';
import '../../core/services/gamification_service.dart';
import '../quiz/quiz_intro_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DynamicTheme>(context);
    final user = FirebaseAuth.instance.currentUser;
    final statsStream = GamificationService().getUserStats();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text("Your Profile"),
        backgroundColor: theme.backgroundColor,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: statsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;

          // UPDATED: Using keys consistent with GamificationService & Badges doc
          final level = data?['level'] ?? 1;
          final totalXp = data?['total_xp'] ?? 20; // Starts at 20
          final badgesEarned = (data?['badges_earned'] as List?) ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildHeader(user, theme),
                const SizedBox(height: 32),

                // Stats Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn("Level", level.toString()),
                        _buildStatColumn("Total XP", totalXp.toString()),
                        _buildStatColumn("Badges", badgesEarned.length.toString()),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _buildAppearanceSettings(theme),
                const SizedBox(height: 24),

                // UPDATED: Badges Grid Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("My Badge Collection", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                badgesEarned.isEmpty
                    ? const Text("Start learning to earn your first badge!", style: TextStyle(color: Colors.grey))
                    : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: badgesEarned.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (context, index) {
                    return _buildBadgeTile(badgesEarned[index], theme);
                  },
                ),

                const SizedBox(height: 48),
                _buildActionButtons(context, theme),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI Helper Components ---

  Widget _buildBadgeTile(String name, DynamicTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primaryColor.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.workspace_premium, color: _getBadgeColor(name), size: 50),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Color _getBadgeColor(String name) {
    if (name == 'Gold') return Colors.amber;
    if (name == 'Silver') return Colors.blueGrey;
    if (name == 'Bronze') return Colors.orangeAccent;
    return Colors.purpleAccent; // Default color for rank badges (Newbie, Master, etc.)
  }

  Widget _buildHeader(User? user, DynamicTheme theme) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: theme.primaryColor,
          backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
          child: user?.photoURL == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
        ),
        const SizedBox(height: 16),
        Text(user?.displayName ?? "Learner", style: theme.titleStyle),
        Text(user?.email ?? "", style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildAppearanceSettings(DynamicTheme theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text("Color Palette"),
            trailing: DropdownButton<PaletteType?>(
              value: theme.currentPalette,
              onChanged: (val) => theme.setManualPalette(val),
              items: const [
                DropdownMenuItem(value: PaletteType.muted, child: Text("Muted")),
                DropdownMenuItem(value: PaletteType.vibrant, child: Text("Vibrant")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, DynamicTheme theme) {
    return Column(
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const QuizIntroductionScreen())),
          icon: const Icon(Icons.refresh),
          label: const Text("Retake Personality Quiz"),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text("Sign Out"),
        ),
      ],
    );
  }
}