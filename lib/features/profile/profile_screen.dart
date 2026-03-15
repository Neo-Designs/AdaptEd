import 'package:adapted/core/services/gamification_service.dart';
import 'package:adapted/core/theme/dynamic_theme.dart';
import 'package:adapted/core/widgets/adapted_button.dart';
import 'package:adapted/core/widgets/adapted_card.dart';
import 'package:adapted/core/widgets/xp_bar.dart';
import 'package:adapted/features/quiz/quiz_intro_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DynamicTheme>(context);
    final user = FirebaseAuth.instance.currentUser;
    final statsStream = GamificationService().getUserStats();
    final isVibrant = theme.currentPalette == PaletteType.vibrant;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: StreamBuilder(
        stream: statsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: theme.primaryColor),
            );
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final level = data?['level'] ?? 1;
          final xp = data?['xp'] ?? 0;
          final badges = (data?['badges'] as List?) ?? [];
          final xpProgress = (xp % 500) / 500;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // ── Avatar ────────────────────────────────────────────────
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isVibrant
                            ? LinearGradient(
                                colors: [
                                  theme.primaryColor,
                                  theme.xpAccentColor
                                ],
                              )
                            : null,
                        color: isVibrant
                            ? null
                            : theme.primaryColor.withValues(alpha: 0.2),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: theme.primaryColor,
                        backgroundImage: user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: user?.photoURL == null
                            ? const Icon(Icons.person,
                                size: 50, color: Colors.white)
                            : null,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.xpAccentColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isVibrant
                            ? [
                                BoxShadow(
                                  color: theme.xpAccentColor
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        _getTraitEmoji(theme),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(user?.displayName ?? 'Learner', style: theme.titleStyle),
                Text(
                  user?.email ?? '',
                  style: theme.bodyStyle.copyWith(
                    color: theme.onSurfaceTextColor.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isVibrant
                        ? theme.primaryColor
                        : theme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.primaryColor.withValues(alpha: 0.3),
                    ),
                    boxShadow: isVibrant
                        ? [
                            BoxShadow(
                              color: theme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    theme.traits.learningProfileName,
                    style: theme.bodyStyle.copyWith(
                      color: isVibrant ? Colors.white : theme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Stats Card ────────────────────────────────────────────
                _buildStatsCard(
                    theme, level, xp, badges, xpProgress, isVibrant),
                const SizedBox(height: 24),

                // ── Trait Palette Preview ─────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Your Learning Palette',
                      style: theme.titleStyle.copyWith(fontSize: 18)),
                ),
                const SizedBox(height: 12),
                _buildPaletteCard(theme, isVibrant),
                const SizedBox(height: 24),

                // ── Appearance ────────────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Appearance',
                      style: theme.titleStyle.copyWith(fontSize: 18)),
                ),
                const SizedBox(height: 12),
                _buildAppearanceCard(theme),
                const SizedBox(height: 24),

                // ── Badges ────────────────────────────────────────────────
                if (badges.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Badges Earned',
                        style: theme.titleStyle.copyWith(fontSize: 18)),
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
                            color: theme.xpAccentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.xpAccentColor),
                            boxShadow: isVibrant
                                ? [
                                    BoxShadow(
                                      color: theme.xpAccentColor
                                          .withValues(alpha: 0.2),
                                      blurRadius: 8,
                                    )
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.workspace_premium,
                                  color: theme.xpAccentColor, size: 40),
                              Text(
                                badge['name'],
                                style: theme.bodyStyle.copyWith(fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                const SizedBox(height: 8),

                // ── Action Buttons ────────────────────────────────────────
                AdaptedButton(
                  label: 'Retake Personality Quiz',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const QuizIntroductionScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(double.infinity, theme.buttonMinHeight),
                    side: BorderSide(color: theme.primaryColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: theme.buttonBorderRadius),
                  ),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: Icon(Icons.logout, color: theme.primaryColor),
                  label: Text('Sign Out',
                      style:
                          theme.bodyStyle.copyWith(color: theme.primaryColor)),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Stats Card ─────────────────────────────────────────────────────────────
  Widget _buildStatsCard(DynamicTheme theme, int level, int xp, List badges,
      double xpProgress, bool isVibrant) {
    return Container(
      decoration: BoxDecoration(
        gradient: isVibrant
            ? LinearGradient(
                colors: [
                  theme.primaryColor.withValues(alpha: 0.9),
                  _darken(theme.primaryColor, 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isVibrant ? null : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isVibrant
            ? [
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('Level', level.toString(), theme,
                  vibrant: isVibrant),
              Container(
                  width: 1,
                  height: 40,
                  color: isVibrant
                      ? Colors.white.withValues(alpha: 0.3)
                      : theme.onSurfaceTextColor.withValues(alpha: 0.1)),
              _buildStatColumn('XP', xp.toString(), theme, vibrant: isVibrant),
              Container(
                  width: 1,
                  height: 40,
                  color: isVibrant
                      ? Colors.white.withValues(alpha: 0.3)
                      : theme.onSurfaceTextColor.withValues(alpha: 0.1)),
              _buildStatColumn('Badges', badges.length.toString(), theme,
                  vibrant: isVibrant),
            ],
          ),
          const SizedBox(height: 16),
          XpBar(progress: xpProgress),
        ],
      ),
    );
  }

  // ── Palette Card ───────────────────────────────────────────────────────────
  Widget _buildPaletteCard(DynamicTheme theme, bool isVibrant) {
    return AdaptedCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: isVibrant
                  ? LinearGradient(
                      colors: [theme.primaryColor, theme.xpAccentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isVibrant ? null : theme.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.palette, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getPaletteName(theme),
                  style: theme.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _getPaletteDescription(theme),
                  style: theme.bodyStyle.copyWith(
                    fontSize: 12,
                    color: theme.onSurfaceTextColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _colorDot(theme.primaryColor),
              const SizedBox(width: 4),
              _colorDot(theme.secondaryColor),
              const SizedBox(width: 4),
              _colorDot(theme.xpAccentColor),
            ],
          ),
        ],
      ),
    );
  }

  // ── Appearance Card ────────────────────────────────────────────────────────
  Widget _buildAppearanceCard(DynamicTheme theme) {
    return AdaptedCard(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.palette_outlined, color: theme.primaryColor),
            title: Text('Color Palette', style: theme.bodyStyle),
            subtitle: Text(
              theme.currentPalette == PaletteType.muted
                  ? 'Muted & Calming'
                  : 'Vibrant & Energetic',
              style: theme.bodyStyle.copyWith(
                fontSize: 12,
                color: theme.onSurfaceTextColor.withValues(alpha: 0.5),
              ),
            ),
            trailing: DropdownButton<PaletteType>(
              value: theme.currentPalette,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              onChanged: (PaletteType? newValue) {
                if (newValue != null) {
                  context.read<DynamicTheme>().setManualPalette(newValue);
                }
              },
              items: [
                DropdownMenuItem(
                  value: PaletteType.muted,
                  child: Text('Muted',
                      style: theme.bodyStyle.copyWith(fontSize: 14)),
                ),
                DropdownMenuItem(
                  value: PaletteType.vibrant,
                  child: Text('Vibrant',
                      style: theme.bodyStyle.copyWith(fontSize: 14)),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: theme.onSurfaceTextColor.withValues(alpha: 0.1)),
          ListTile(
            leading: Icon(Icons.auto_fix_high, color: theme.primaryColor),
            title: Text('Auto-detect Palette', style: theme.bodyStyle),
            subtitle: Text(
              'Based on your learning profile',
              style: theme.bodyStyle.copyWith(
                fontSize: 12,
                color: theme.onSurfaceTextColor.withValues(alpha: 0.5),
              ),
            ),
            trailing: Switch(
              value: theme.isAutoDetectPalette,
              onChanged: (val) {
                context.read<DynamicTheme>().setManualPalette(
                      val ? null : theme.currentPalette,
                    );
              },
            ),
          ),
          Divider(
              height: 1,
              color: theme.onSurfaceTextColor.withValues(alpha: 0.1)),
          ListTile(
            leading:
                Icon(Icons.font_download_outlined, color: theme.primaryColor),
            title: Text('Dyslexia-Friendly Font', style: theme.bodyStyle),
            subtitle: Text(
              'Uses Lexend with wider spacing',
              style: theme.bodyStyle.copyWith(
                fontSize: 12,
                color: theme.onSurfaceTextColor.withValues(alpha: 0.5),
              ),
            ),
            trailing: Switch(
              value: theme.useDyslexicFont,
              onChanged: (_) {
                context.read<DynamicTheme>().toggleDyslexicFont();
              },
            ),
          ),
          Divider(
              height: 1,
              color: theme.onSurfaceTextColor.withValues(alpha: 0.1)),
          ListTile(
            leading: Icon(
              theme.focusMode ? Icons.visibility_off : Icons.visibility,
              color: theme.primaryColor,
            ),
            title: Text('Focus Mode', style: theme.bodyStyle),
            subtitle: Text(
              'Reduces distractions',
              style: theme.bodyStyle.copyWith(
                fontSize: 12,
                color: theme.onSurfaceTextColor.withValues(alpha: 0.5),
              ),
            ),
            trailing: Switch(
              value: theme.focusMode,
              onChanged: (_) {
                context.read<DynamicTheme>().toggleFocusMode();
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  Widget _colorDot(Color color) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  String _getTraitEmoji(DynamicTheme theme) {
    if (theme.traits.isADHD) return '⚡';
    if (theme.traits.isAutistic) return '🌿';
    if (theme.traits.isDyslexic) return '📖';
    if (theme.traits.isDyspraxic) return '🎯';
    return '✨';
  }

  String _getPaletteName(DynamicTheme theme) {
    if (theme.traits.isAutistic && theme.traits.isADHD) {
      return 'Calm Focus Blend';
    }
    if (theme.traits.isAutistic) return 'Calm Sage';
    if (theme.traits.isDyslexic) return 'Warm Beige';
    if (theme.traits.isADHD) return 'Electric Focus';
    if (theme.traits.isDyspraxic) return 'Bold Action';
    return 'Adaptive';
  }

  String _getPaletteDescription(DynamicTheme theme) {
    if (theme.traits.isAutistic && theme.traits.isADHD) {
      return 'Sage greens with electric blue accents';
    }
    if (theme.traits.isAutistic) {
      return 'Soft greens · no harsh contrast · minimal borders';
    }
    if (theme.traits.isDyslexic) {
      return 'Warm creams · readable terracotta · wide spacing';
    }
    if (theme.traits.isADHD) {
      return 'Electric blue · hot pink XP · high energy';
    }
    if (theme.traits.isDyspraxic) {
      return 'Bold purple · vivid orange · large tap targets';
    }
    return 'Adapts to your learning profile';
  }

  Widget _buildStatColumn(String label, String value, DynamicTheme theme,
      {bool vibrant = false}) {
    return Column(
      children: [
        Text(
          value,
          style: theme.titleStyle.copyWith(
            fontSize: 28,
            color: vibrant ? Colors.white : theme.onSurfaceTextColor,
          ),
        ),
        Text(
          label,
          style: theme.bodyStyle.copyWith(
            color: vibrant
                ? Colors.white.withValues(alpha: 0.7)
                : theme.onSurfaceTextColor.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
