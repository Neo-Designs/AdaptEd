import 'package:adapted/core/theme/dynamic_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdaptiveLayoutShell extends StatefulWidget {
  final Widget child;
  const AdaptiveLayoutShell({super.key, required this.child});

  @override
  State<AdaptiveLayoutShell> createState() => _AdaptiveLayoutShellState();
}

class _AdaptiveLayoutShellState extends State<AdaptiveLayoutShell> {
  bool _isSidebarExpanded = true;

  final List<Map<String, dynamic>> _navItems = [
    {
      'icon': Icons.dashboard_outlined,
      'activeIcon': Icons.dashboard,
      'label': 'Dashboard',
      'route': '/dashboard'
    },
    {
      'icon': Icons.library_books_outlined,
      'activeIcon': Icons.library_books,
      'label': 'Library',
      'route': '/library'
    },
    {
      'icon': Icons.analytics_outlined,
      'activeIcon': Icons.analytics,
      'label': 'Analytics',
      'route': '/analytics'
    },
    {
      'icon': Icons.person_outline,
      'activeIcon': Icons.person,
      'label': 'Profile',
      'route': '/profile'
    },
    {
      'icon': Icons.help_outline,
      'activeIcon': Icons.help,
      'label': 'FAQs',
      'route': '/faqs'
    },
  ];

  final List<Map<String, dynamic>> _bottomNavItems = [
    {
      'icon': Icons.dashboard_outlined,
      'label': 'Dashboard',
      'route': '/dashboard'
    },
    {
      'icon': Icons.library_books_outlined,
      'label': 'Library',
      'route': '/library'
    },
    {
      'icon': Icons.analytics_outlined,
      'label': 'Analytics',
      'route': '/analytics'
    },
    {'icon': Icons.person_outline, 'label': 'Profile', 'route': '/profile'},
    {
      'icon': Icons.settings_outlined,
      'label': 'Settings',
      'route': '/settings'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DynamicTheme>();
    final user = FirebaseAuth.instance.currentUser;
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    final isVibrant = theme.currentPalette == PaletteType.vibrant;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          return Scaffold(
            backgroundColor: theme.backgroundColor,
            body: Row(
              children: [
                _buildSidebar(context, theme, currentRoute, isVibrant),
                Expanded(
                  child: Column(
                    children: [
                      _buildDesktopAppBar(context, theme, user, isVibrant),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            // ← FIXED: always backgroundColor, no fill in any mode
            backgroundColor: theme.backgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0, // ← prevents blue tint on scroll
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: theme.onSurfaceTextColor),
            title: Text(
              _getPageTitle(currentRoute),
              style: theme.titleStyle, // ← always uses theme text color
            ),
            actions: [
              IconButton(
                onPressed: () =>
                    context.read<DynamicTheme>().toggleDyslexicFont(),
                icon: Icon(Icons.abc, color: theme.primaryColor),
              ),
              IconButton(
                onPressed: () => context.read<DynamicTheme>().toggleFocusMode(),
                icon: Icon(
                  theme.focusMode ? Icons.visibility_off : Icons.visibility,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
          bottomNavigationBar:
              _buildBottomNav(context, theme, currentRoute, isVibrant),
          drawer: _buildDrawer(context, theme, currentRoute, isVibrant),
          body: widget.child,
        );
      },
    );
  }

  // ── Sidebar (Desktop) ─────────────────────────────────────────────────────
  Widget _buildSidebar(BuildContext context, DynamicTheme theme,
      String currentRoute, bool isVibrant) {
    final sidebarBg =
        isVibrant ? _darken(theme.primaryColor, 0.3) : theme.backgroundColor;
    final sidebarBorder = isVibrant
        ? Colors.transparent
        : theme.primaryColor.withValues(alpha: 0.15);
    final logoColor = isVibrant ? Colors.white : theme.primaryColor;
    final logoTextColor = isVibrant ? Colors.white : theme.onSurfaceTextColor;
    final subtitleColor =
        isVibrant ? Colors.white.withValues(alpha: 0.6) : theme.primaryColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: _isSidebarExpanded ? 240 : 70,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: sidebarBorder, width: 1)),
        boxShadow: isVibrant
            ? [
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(4, 0),
                )
              ]
            : [],
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: _isSidebarExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, color: logoColor, size: 28),
                if (_isSidebarExpanded) ...[
                  const SizedBox(width: 10),
                  Text("AdaptEd",
                      style: theme.titleStyle.copyWith(
                        fontSize: 20,
                        color: logoTextColor,
                      )),
                ],
              ],
            ),
          ),
          if (_isSidebarExpanded && theme.traits.learningProfileName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                theme.traits.learningProfileName,
                style: theme.bodyStyle
                    .copyWith(fontSize: 11, color: subtitleColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (isVibrant && _isSidebarExpanded) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.primaryColor, theme.xpAccentColor],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ..._navItems.map((item) => _buildNavItem(
                context,
                theme,
                item['icon'] as IconData,
                item['activeIcon'] as IconData,
                item['label'] as String,
                item['route'] as String,
                currentRoute,
                isVibrant: isVibrant,
              )),
          const Spacer(),
          _buildNavItem(context, theme, Icons.settings_outlined, Icons.settings,
              "Settings", '/settings', currentRoute,
              isVibrant: isVibrant),
          Divider(
            height: 1,
            color: isVibrant
                ? Colors.white.withValues(alpha: 0.1)
                : theme.onSurfaceTextColor.withValues(alpha: 0.1),
          ),
          ListTile(
            leading: Icon(
              _isSidebarExpanded ? Icons.chevron_left : Icons.chevron_right,
              color: isVibrant ? Colors.white70 : theme.primaryColor,
            ),
            title: _isSidebarExpanded
                ? Text("Collapse",
                    style: theme.bodyStyle.copyWith(
                      fontSize: 13,
                      color:
                          isVibrant ? Colors.white70 : theme.onSurfaceTextColor,
                    ))
                : null,
            onTap: () =>
                setState(() => _isSidebarExpanded = !_isSidebarExpanded),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Bottom Nav (Mobile) ───────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context, DynamicTheme theme,
      String currentRoute, bool isVibrant) {
    int currentIndex = _bottomNavItems.indexWhere(
      (item) =>
          item['route'] == currentRoute ||
          (item['route'] == '/dashboard' && currentRoute == '/'),
    );
    if (currentIndex == -1) currentIndex = 0;

    return NavigationBar(
      backgroundColor:
          isVibrant ? _darken(theme.primaryColor, 0.3) : theme.cardColor,
      indicatorColor: isVibrant
          ? theme.xpAccentColor.withValues(alpha: 0.3)
          : theme.primaryColor.withValues(alpha: 0.15),
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        final route = _bottomNavItems[index]['route'] as String;
        if (currentRoute != route) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
      destinations: _bottomNavItems.map((item) {
        return NavigationDestination(
          icon: Icon(item['icon'] as IconData,
              color: isVibrant ? Colors.white54 : Colors.grey[600]),
          selectedIcon: Icon(item['icon'] as IconData,
              color: isVibrant ? Colors.white : theme.primaryColor),
          label: item['label'] as String,
        );
      }).toList(),
    );
  }

  // ── Drawer (Mobile) ───────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context, DynamicTheme theme,
      String currentRoute, bool isVibrant) {
    return Drawer(
      backgroundColor:
          isVibrant ? _darken(theme.primaryColor, 0.3) : theme.backgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.primaryColor,
              gradient: isVibrant
                  ? LinearGradient(
                      colors: [theme.primaryColor, theme.xpAccentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
                const SizedBox(height: 10),
                const Text("AdaptEd",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                if (theme.traits.learningProfileName.isNotEmpty)
                  Text(theme.traits.learningProfileName,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ..._navItems.map((item) => _buildNavItem(
                context,
                theme,
                item['icon'] as IconData,
                item['activeIcon'] as IconData,
                item['label'] as String,
                item['route'] as String,
                currentRoute,
                isDrawer: true,
                isVibrant: isVibrant,
              )),
          Divider(color: isVibrant ? Colors.white24 : null),
          _buildNavItem(context, theme, Icons.settings_outlined, Icons.settings,
              "Settings", '/settings', currentRoute,
              isDrawer: true, isVibrant: isVibrant),
        ],
      ),
    );
  }

  // ── Nav Item ──────────────────────────────────────────────────────────────
  Widget _buildNavItem(
    BuildContext context,
    DynamicTheme theme,
    IconData icon,
    IconData activeIcon,
    String label,
    String route,
    String currentRoute, {
    bool isDrawer = false,
    bool isVibrant = false,
  }) {
    final isSelected =
        currentRoute == route || (route == '/dashboard' && currentRoute == '/');
    final showLabel = _isSidebarExpanded || isDrawer;

    final selectedBg = isVibrant
        ? Colors.white.withValues(alpha: 0.15)
        : theme.primaryColor.withValues(alpha: 0.12);
    final selectedIconColor = isVibrant ? Colors.white : theme.primaryColor;
    final unselectedIconColor = isVibrant
        ? Colors.white.withValues(alpha: 0.5)
        : theme.onSurfaceTextColor.withValues(alpha: 0.5);
    final selectedTextColor = isVibrant ? Colors.white : theme.primaryColor;
    final unselectedTextColor = isVibrant
        ? Colors.white.withValues(alpha: 0.7)
        : theme.onSurfaceTextColor.withValues(alpha: 0.7);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected && isVibrant
            ? Border(left: BorderSide(color: theme.xpAccentColor, width: 3))
            : null,
      ),
      child: ListTile(
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? selectedIconColor : unselectedIconColor,
          size: 22,
        ),
        title: showLabel
            ? Text(label,
                style: theme.bodyStyle.copyWith(
                  color: isSelected ? selectedTextColor : unselectedTextColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ))
            : null,
        selected: isSelected,
        onTap: () {
          if (isDrawer) Navigator.pop(context);
          if (currentRoute != route) {
            Navigator.pushReplacementNamed(context, route);
          }
        },
        contentPadding: showLabel
            ? const EdgeInsets.symmetric(horizontal: 12)
            : const EdgeInsets.only(left: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Desktop AppBar ────────────────────────────────────────────────────────
  Widget _buildDesktopAppBar(
      BuildContext context, DynamicTheme theme, User? user, bool isVibrant) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      // ← FIXED: no border, no fill — completely transparent strip
      decoration: BoxDecoration(
        color: theme.backgroundColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => context.read<DynamicTheme>().toggleDarkMode(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    theme.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    size: 16,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    theme.isDarkMode ? "Dark" : "Light",
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (user != null)
            Tooltip(
              message: "Go to Profile",
              child: GestureDetector(
                onTap: () =>
                    Navigator.pushReplacementNamed(context, '/profile'),
                child: CircleAvatar(
                  backgroundColor: theme.primaryColor,
                  radius: 18,
                  child: Text(
                    user.displayName?.substring(0, 1).toUpperCase() ?? "U",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  String _getPageTitle(String route) {
    switch (route) {
      case '/':
      case '/dashboard':
        return 'Dashboard';
      case '/library':
        return 'Library';
      case '/analytics':
        return 'Analytics';
      case '/profile':
        return 'Profile';
      case '/settings':
        return 'Settings';
      case '/faqs':
        return 'FAQs';
      case '/admin':
        return 'Admin Portal';
      default:
        return 'AdaptEd';
    }
  }
}
