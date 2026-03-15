import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/dynamic_theme.dart';

class AdaptiveLayoutShell extends StatefulWidget {
  final Widget child;
  const AdaptiveLayoutShell({super.key, required this.child});

  @override
  State<AdaptiveLayoutShell> createState() => _AdaptiveLayoutShellState();
}

class _AdaptiveLayoutShellState extends State<AdaptiveLayoutShell> {
  bool _isSidebarExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DynamicTheme>(context);
    final user = FirebaseAuth.instance.currentUser;
    // Get current route name safely
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop / Tablet Landscape Layout
        if (constraints.maxWidth >= 800) {
          return Scaffold(
            backgroundColor: theme.backgroundColor,
            body: Row(
              children: [
                _buildSidebar(context, theme, currentRoute),
                Expanded(
                  child: Column(
                    children: [
                       _buildDesktopAppBar(context, theme, user),
                       Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile / Tablet Portrait Layout
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: theme.backgroundColor,
            elevation: 0,
            iconTheme: IconThemeData(color: Theme.of(context).textTheme.bodyMedium?.color),
            title: Text(_getPageTitle(currentRoute), style: theme.titleStyle),
            actions: [
              IconButton(onPressed: () => theme.toggleDyslexicFont(), icon: const Icon(Icons.abc)),
              IconButton(onPressed: () => theme.toggleFocusMode(), icon: Icon(theme.focusMode ? Icons.visibility_off : Icons.visibility)),
            ],
          ),
          drawer: _buildDrawer(context, theme, currentRoute),
          body: widget.child,
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, DynamicTheme theme, String currentRoute) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isSidebarExpanded ? 250 : 70,
      color: theme.cardColor,
      child: Column(
        children: [
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: theme.primaryColor, size: 28),
              if (_isSidebarExpanded) ...[
                const SizedBox(width: 10),
                Text("AdaptEd", style: theme.titleStyle.copyWith(fontSize: 22)),
              ]
            ],
          ),
          const SizedBox(height: 40),
          _buildNavItem(context, theme, Icons.dashboard_outlined, "Dashboard", '/dashboard', currentRoute),
          _buildNavItem(context, theme, Icons.library_books_outlined, "Library", '/library', currentRoute),
          _buildNavItem(context, theme, Icons.analytics_outlined, "Analytics", '/analytics', currentRoute),
          _buildNavItem(context, theme, Icons.person_outline, "Profile", '/profile', currentRoute),
          _buildNavItem(context, theme, Icons.help_outline, "FAQs", '/faqs', currentRoute),
          _buildNavItem(context, theme, Icons.play_circle_outline, "App Tutorial" , '/app tutorial', currentRoute),
          const Spacer(),
          _buildNavItem(context, theme, Icons.settings_outlined, "Settings", '/settings', currentRoute),
          IconButton(
            icon: Icon(_isSidebarExpanded ? Icons.chevron_left : Icons.chevron_right),
            onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildDrawer(BuildContext context, DynamicTheme theme, String currentRoute) {
    return Drawer(
      backgroundColor: theme.backgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: theme.primaryColor),
            child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                 const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
                 const SizedBox(height: 10),
                 const Text("AdaptEd", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                 if (theme.traits.learningProfileName.isNotEmpty)
                    Text(theme.traits.learningProfileName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
               ],
            ),
          ),
          _buildNavItem(context, theme, Icons.dashboard_outlined, "Dashboard", '/dashboard', currentRoute, isDrawer: true),
          _buildNavItem(context, theme, Icons.library_books_outlined, "Library", '/library', currentRoute, isDrawer: true),
          _buildNavItem(context, theme, Icons.analytics_outlined, "Analytics", '/analytics', currentRoute, isDrawer: true),
          _buildNavItem(context, theme, Icons.person_outline, "Profile", '/profile', currentRoute, isDrawer: true),
          _buildNavItem(context, theme, Icons.help_outline, "FAQs", '/faqs', currentRoute, isDrawer: true),
          _buildNavItem(context, theme, Icons.play_circle_outline, "App Tutorial" , '/app tutorial', currentRoute, isDrawer: true),
          const Divider(),
          _buildNavItem(context, theme, Icons.settings_outlined, "Settings", '/settings', currentRoute, isDrawer: true),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, DynamicTheme theme, IconData icon, String label, String route, String currentRoute, {bool isDrawer = false}) {
    // Basic route matching
    final isSelected = currentRoute == route || (route == '/dashboard' && currentRoute == '/');
    final showLabel = _isSidebarExpanded || isDrawer;

    return ListTile(
      leading: Icon(
        icon, 
        color: isSelected ? theme.primaryColor : Colors.grey[600],
      ),
      title: showLabel ? Text(
        label, 
        style: TextStyle(
          fontFamily: theme.bodyStyle.fontFamily,
          color: isSelected ? theme.primaryColor : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ) : null,
      selected: isSelected,
      onTap: () {
        if (currentRoute != route) {
          if (isDrawer) {
            Navigator.pop(context); // Close drawer
          }
          Navigator.pushReplacementNamed(context, route);
        }
      },
      contentPadding: showLabel ? const EdgeInsets.symmetric(horizontal: 16) : const EdgeInsets.only(left: 24),
    );
  }

  Widget _buildDesktopAppBar(BuildContext context, DynamicTheme theme, User? user) {
     return Container(
       height: 60,
       padding: const EdgeInsets.symmetric(horizontal: 24),
       decoration: BoxDecoration(
          color: theme.backgroundColor,
          border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1)))
       ),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.end,
         children: [
            IconButton(
               icon: const Icon(Icons.abc, size: 28), 
               tooltip: "Toggle Dyslexic Font",
               onPressed: () => theme.toggleDyslexicFont()
            ),
            const SizedBox(width: 8),
            IconButton(
               icon: Icon(theme.focusMode ? Icons.visibility_off : Icons.visibility, size: 24), 
               tooltip: "Toggle Focus Mode",
               onPressed: () => theme.toggleFocusMode()
            ),
            const SizedBox(width: 16),
            if (user != null)
               CircleAvatar(
                 backgroundColor: theme.primaryColor,
                 radius: 16,
                 child: Text(user.displayName?.substring(0,1).toUpperCase() ?? "U", style: const TextStyle(color: Colors.white)),
               )
         ],
       ),
     );
  }

  String _getPageTitle(String route) {
    if (route == '/' || route == '/dashboard') return 'Dashboard';
    if (route == '/library') return 'Library';
    if (route == '/analytics') return 'Analytics';
    if (route == '/profile') return 'Profile';
    if (route == '/settings') return 'Settings';
    if (route == '/faqs') return 'FAQs';
    if (route == '/admin') return 'Admin Portal';
    return 'AdaptEd';
  }
}
