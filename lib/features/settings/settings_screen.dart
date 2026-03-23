import 'package:adapted/core/theme/dynamic_theme.dart';
import 'package:adapted/core/widgets/adapted_card.dart';
import 'package:adapted/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
            Text('Settings', style: theme.titleStyle.copyWith(fontSize: 24)),
            const SizedBox(height: 24),

            // ── Appearance ──────────────────────────────────────────────────
            _buildSectionHeader(theme, 'Appearance'),
            AdaptedCard(
              child: Column(
                children: [
                  _buildSwitchTile(
                    theme,
                    'Focus Mode',
                    'Reduce distractions and visual noise',
                    theme.focusMode,
                    (_) => context.read<DynamicTheme>().toggleFocusMode(),
                  ),
                  _divider(theme),
                  _buildSwitchTile(
                    theme,
                    'High Contrast',
                    'Maximum text/background contrast',
                    theme.highContrast,
                    (_) => context.read<DynamicTheme>().toggleHighContrast(),
                  ),
                  _divider(theme),
                  _buildSwitchTile(
                    theme,
                    'Reading Ruler',
                    'Horizontal guide line for dyslexic users',
                    theme.readingRuler,
                    (_) => context.read<DynamicTheme>().toggleReadingRuler(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Font Size ───────────────────────────────────────────────────
            _buildSectionHeader(theme, 'Font Size'),
            AdaptedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('A', style: theme.bodyStyle.copyWith(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: theme.fontSizeScale,
                          min: 0.8,
                          max: 1.4,
                          divisions: 6,
                          activeColor: theme.primaryColor,
                          inactiveColor:
                              theme.primaryColor.withValues(alpha: 0.2),
                          onChanged: (val) {
                            context.read<DynamicTheme>().setFontSizeScale(val);
                          },
                        ),
                      ),
                      Text('A', style: theme.bodyStyle.copyWith(fontSize: 22)),
                    ],
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getFontSizeLabel(theme.fontSizeScale),
                        style: theme.bodyStyle.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'The quick brown fox jumps over the lazy dog.',
                      style: theme.bodyStyle,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Display ─────────────────────────────────────────────────────
            _buildSectionHeader(theme, 'Display'),
            AdaptedCard(
              child: _buildSwitchTile(
                theme,
                'Dark Mode',
                'Switch between light and dark appearance',
                theme.isDarkMode,
                (_) => context.read<DynamicTheme>().toggleDarkMode(),
              ),
            ),

            const SizedBox(height: 24),
            // ── Log Out Button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white),
                label: Text('Log Out', style: theme.buttonTextStyle),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.isDarkMode ? Colors.red[500] : Colors.red[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                                  onPressed: () async {
                  FocusManager.instance.primaryFocus?.unfocus();

                  // 1. Show a quick visual spinner so the user knows it's thinking
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.red)),
                  );

                  // 2. FORCEFULLY terminate all active database streams BEFORE the token dies!
                  // This entirely prevents the PERMISSION_DENIED barrage from crashing Android.
                  await FirebaseFirestore.instance.terminate();
                  await FirebaseFirestore.instance.clearPersistence();

                  // 3. Now it is 100% safe to revoke the token.
                  await FirebaseAuth.instance.signOut();
                  
                  // 4. Pop the spinner safely so the SignInScreen displays.
                  if (context.mounted) Navigator.of(context).pop();
                },


              ),
            ),
            const SizedBox(height: 32),

            

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _getFontSizeLabel(double scale) {
    if (scale <= 0.8) return 'Extra Small';
    if (scale <= 0.9) return 'Small';
    if (scale <= 1.0) return 'Normal';
    if (scale <= 1.1) return 'Medium';
    if (scale <= 1.2) return 'Large';
    if (scale <= 1.3) return 'Extra Large';
    return 'Huge';
  }

  Widget _divider(DynamicTheme theme) => Divider(
        height: 1,
        color: theme.onSurfaceTextColor.withValues(alpha: 0.08),
      );

  Widget _buildSectionHeader(DynamicTheme theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: theme.bodyStyle.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: theme.onSurfaceTextColor.withValues(alpha: 0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    DynamicTheme theme,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(title,
          style: theme.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: theme.bodyStyle.copyWith(
            fontSize: 12,
            color: theme.onSurfaceTextColor.withValues(alpha: 0.5),
          )),
      value: value,
      onChanged: onChanged,
    );
  }
}
