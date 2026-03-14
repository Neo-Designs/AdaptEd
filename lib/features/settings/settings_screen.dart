import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/dynamic_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            Text("Settings", style: theme.titleStyle.copyWith(fontSize: 24)),
            const SizedBox(height: 24),
            _buildSectionHeader(theme, "Appearance"),
            _buildSwitchTile(
                theme,
                "Dyslexic Font",
                "Easier to read font for dyslexia",
                theme.useDyslexicFont,
                (val) => theme.toggleDyslexicFont()),
            _buildSwitchTile(theme, "Focus Mode", "Reduce distractions",
                theme.focusMode, (val) => theme.toggleFocusMode()),
            _buildSectionHeader(theme, "Account"),
            ListTile(
              leading: Icon(Icons.person, color: theme.primaryColor),
              title: Text("Profile Settings", style: theme.bodyStyle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text("Log Out",
                  style: theme.bodyStyle.copyWith(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                // AuthWrapper handling the stream will likely deal with this,
                // but getting off the current route stack is good practice.
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(DynamicTheme theme, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: theme.bodyStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSwitchTile(DynamicTheme theme, String title, String subtitle,
      bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title,
          style: theme.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: theme.bodyStyle.copyWith(fontSize: 12, color: Colors.grey)),
      value: value,
      activeThumbColor: theme.primaryColor,
      onChanged: onChanged,
    );
  }
}
