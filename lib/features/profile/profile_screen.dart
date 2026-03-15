import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
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
      body: StreamBuilder(
        stream: statsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final level = data?['level'] ?? 1;
          final xp = data?['xp'] ?? 0;
          final badges = (data?['badges'] as List?) ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.primaryColor,
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayName ?? "Learner",
                  style: theme.titleStyle,
                ),
                Text(
                  user?.email ?? "",
                  style: const TextStyle(color: Colors.grey),
                ),
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
                        _buildStatColumn("XP", xp.toString()),
                        _buildStatColumn("Badges", badges.length.toString()),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Theme Customizer
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Appearance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: const Text("Color Palette"),
                        subtitle: Text(theme.currentPalette == PaletteType.muted ? "Muted & Calming" : "Vibrant & Energetic"),
                        trailing: DropdownButton<PaletteType?>(
                          value: theme.currentPalette, // Showing current active one
                          onChanged: (PaletteType? newValue) {
                            theme.setManualPalette(newValue);
                          },
                          items: const [
                            DropdownMenuItem(value: PaletteType.muted, child: Text("Muted")),
                            DropdownMenuItem(value: PaletteType.vibrant, child: Text("Vibrant")),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.auto_fix_high),
                        title: const Text("Auto-detect Palette"),
                        subtitle: const Text("Based on your learning profile"),
                        trailing: Switch(
                          value: theme.currentPalette == (theme.traits.isAutistic || theme.traits.isDyslexic ? PaletteType.muted : PaletteType.vibrant),
                          onChanged: (val) {
                            if (val) theme.setManualPalette(null);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                
                // Badges Section
                if (badges.isNotEmpty) ...[
                   const Align(
                     alignment: Alignment.centerLeft,
                     child: Text("Badges Earned", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   ),
                   const SizedBox(height: 12),
                   SizedBox(
                     height: 100,
                     child: ListView.builder(
                       scrollDirection: Axis.horizontal,
                       itemCount: badges.length,
                       itemBuilder: (context, index) {
                         final badge = badges[index];
                         return Container(
                           width: 80,
                           margin: const EdgeInsets.only(right: 12),
                           decoration: BoxDecoration(
                             color: theme.accentColor.withValues(alpha: 0.1),
                             borderRadius: BorderRadius.circular(12),
                             border: Border.all(color: theme.accentColor),
                           ),
                           child: Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               Icon(Icons.workspace_premium, color: theme.accentColor, size: 40),
                               Text(badge['name'], style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
                             ],
                           ),
                         );
                       },
                     ),
                   ),
                ],

                const SizedBox(height: 48),
                
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                     Navigator.of(context).push(MaterialPageRoute(builder: (context) => const QuizIntroductionScreen()));
                  },
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
            ),
          );
        },
      ),
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
}
