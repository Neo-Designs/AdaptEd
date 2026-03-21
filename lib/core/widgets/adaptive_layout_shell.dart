import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../core/theme/dynamic_theme.dart';
import '../../core/services/user_service.dart';

class AdaptiveLayoutShell extends StatefulWidget {
  final Widget child;
  const AdaptiveLayoutShell({super.key, required this.child});

  @override
  State<AdaptiveLayoutShell> createState() => _AdaptiveLayoutShellState();
}

class _AdaptiveLayoutShellState extends State<AdaptiveLayoutShell> {
  bool _isSidebarExpanded = true;
  bool _sidebarTutorialStarted = false;
  final GlobalKey<ShowCaseWidgetState> _showCaseKey = GlobalKey<ShowCaseWidgetState>();

  // Sidebar keys
  final GlobalKey _libraryNavKey = GlobalKey();
  final GlobalKey _analyticsNavKey = GlobalKey();
  final GlobalKey _profileNavKey = GlobalKey();
  final GlobalKey _settingsNavKey = GlobalKey();
  final GlobalKey _faqsNavKey = GlobalKey();
  final GlobalKey _tutorialNavKey = GlobalKey();

  // Drawer-only keys
  final GlobalKey _drawerLibraryNavKey = GlobalKey();
  final GlobalKey _drawerAnalyticsNavKey = GlobalKey();
  final GlobalKey _drawerProfileNavKey = GlobalKey();
  final GlobalKey _drawerSettingsNavKey = GlobalKey();
  final GlobalKey _drawerFaqsNavKey = GlobalKey();
  final GlobalKey _drawerTutorialNavKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final userService = Provider.of<UserService>(context, listen: false);
    userService.addListener(_checkOnboarding);
  }

  @override
  void dispose() {
    final userService = Provider.of<UserService>(context, listen: false);
    userService.removeListener(_checkOnboarding);
    super.dispose();
  }

  void _checkOnboarding() {
    final userService = Provider.of<UserService>(context, listen: false);

    if (userService.isInitialized && userService.currentTraits != null) {
      if (!userService.currentTraits!.hasSeenTutorial) {
        userService.removeListener(_checkOnboarding);

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) _startGlobalTutorial();
        });
      }
    }
  }

  void _startGlobalTutorial() async {
    if (!mounted) return;

    final userService = Provider.of<UserService>(context, listen: false);
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';

    setState(() => _sidebarTutorialStarted = false);

    if (currentRoute != '/dashboard' && currentRoute != '/') {
      userService.startGlobalTutorialSequence();
      Navigator.pushReplacementNamed(context, '/dashboard');
      return;
    }

    userService.startGlobalTutorialSequence();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DynamicTheme>(context);
    final user = FirebaseAuth.instance.currentUser;
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';

    return ShowCaseWidget(
      key: _showCaseKey,
      onStart: (index, key) {},
      onFinish: () async {
        if (!mounted) return;
        final userService = Provider.of<UserService>(context, listen: false);

        if ((currentRoute == '/dashboard' || currentRoute == '/') &&
            !_sidebarTutorialStarted) {
          setState(() => _sidebarTutorialStarted = true);

          await Future.delayed(const Duration(milliseconds: 300));

          if (mounted) {
            if (MediaQuery.of(context).size.width >= 800) {
              _showCaseKey.currentState?.startShowCase([
                _libraryNavKey,
                _analyticsNavKey,
                _profileNavKey,
                _settingsNavKey,
                _faqsNavKey,
                _tutorialNavKey,
              ]);
            } else {
              await userService.markTutorialAsComplete();
              setState(() => _sidebarTutorialStarted = false);
            }
          }
        } else if (_sidebarTutorialStarted) {
          await userService.markTutorialAsComplete();
          setState(() => _sidebarTutorialStarted = false);
        }
      },
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return constraints.maxWidth >= 800
                ? _buildDesktopLayout(context, theme, user, currentRoute)
                : _buildMobileLayout(context, theme, currentRoute);
          },
        );
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, DynamicTheme theme,
      User? user, String currentRoute) {
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

  Widget _buildMobileLayout(
      BuildContext context, DynamicTheme theme, String currentRoute) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        elevation: 0,
        title: Text(_getPageTitle(currentRoute), style: theme.titleStyle),
        actions: [
          IconButton(
            onPressed: () => theme.toggleDyslexicFont(),
            icon: const Icon(Icons.abc),
          ),
          IconButton(
            onPressed: () => theme.toggleFocusMode(),
            icon: Icon(theme.focusMode
                ? Icons.visibility_off
                : Icons.visibility),
          ),
        ],
      ),
      drawer: _buildDrawer(context, theme, currentRoute),
      body: widget.child,
    );
  }

  Widget _buildSidebar(
      BuildContext context, DynamicTheme theme, String currentRoute) {
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
                Text("AdaptEd",
                    style: theme.titleStyle.copyWith(fontSize: 22)),
              ]
            ],
          ),
          const SizedBox(height: 40),
          _buildNavItem(context, theme, Icons.dashboard_outlined,
              "Dashboard", '/dashboard', currentRoute),
          Showcase(
            key: _libraryNavKey,
            title: 'Your Library',
            description:
            'All your uploaded PDFs and AI summaries are saved here for easier review.',
            child: _buildNavItem(context, theme, Icons.library_books_outlined,
                "Library", '/library', currentRoute),
          ),
          Showcase(
            key: _analyticsNavKey,
            title: 'Learning Insights',
            description:
            'Track your study patterns and see how your XP grows over time.',
            child: _buildNavItem(context, theme, Icons.analytics_outlined,
                "Analytics", '/analytics', currentRoute),
          ),
          Showcase(
            key: _profileNavKey,
            title: 'Your Profile',
            description: 'Track your badge collection, XP and levels here!',
            child: _buildNavItem(context, theme, Icons.person_outline,
                "Profile", '/profile', currentRoute),
          ),
          Showcase(
            key: _faqsNavKey,
            title: 'FAQs',
            description:
            'Any doubts you have about AdaptEd could be cleared here!',
            child: _buildNavItem(context, theme, Icons.help_outline,
                "FAQs", '/faqs', currentRoute),
          ),
          Showcase(
            key: _tutorialNavKey,
            title: 'App Tutorial',
            description: 'Replay the tutorial anytime here!',
            child: _buildNavItem(
              context,
              theme,
              Icons.play_circle_outline,
              "App Tutorial",
              '/app_tutorial',
              currentRoute,
              onTapOverride: () {
                setState(() => _sidebarTutorialStarted = false);
                _startGlobalTutorial();
              },
            ),
          ),
          const Spacer(),
          Showcase(
            key: _settingsNavKey,
            title: 'Settings',
            description:
            'Customize and Personalize your AdaptEd experience here!',
            child: _buildNavItem(context, theme, Icons.settings_outlined,
                "Settings", '/settings', currentRoute),
          ),
          IconButton(
            icon: Icon(_isSidebarExpanded
                ? Icons.chevron_left
                : Icons.chevron_right),
            onPressed: () =>
                setState(() => _isSidebarExpanded = !_isSidebarExpanded),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawer(
      BuildContext context, DynamicTheme theme, String currentRoute) {
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
                const Text("AdaptEd",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                if (theme.traits.learningProfileName.isNotEmpty)
                  Text(theme.traits.learningProfileName,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          _buildNavItem(context, theme, Icons.dashboard_outlined,
              "Dashboard", '/dashboard', currentRoute,
              isDrawer: true),
          Showcase(
            key: _drawerLibraryNavKey,
            title: 'Your Library',
            description:
            'All your uploaded PDFs and AI summaries are saved here for easier review.',
            child: _buildNavItem(context, theme, Icons.library_books_outlined,
                "Library", '/library', currentRoute,
                isDrawer: true),
          ),
          Showcase(
            key: _drawerAnalyticsNavKey,
            title: 'Learning Insights',
            description:
            'Track your study patterns and see how your XP grows over time.',
            child: _buildNavItem(context, theme, Icons.analytics_outlined,
                "Analytics", '/analytics', currentRoute,
                isDrawer: true),
          ),
          Showcase(
            key: _drawerProfileNavKey,
            title: 'Your Profile',
            description: 'Track your badge collection, XP and levels here!',
            child: _buildNavItem(context, theme, Icons.person_outline,
                "Profile", '/profile', currentRoute,
                isDrawer: true),
          ),
          Showcase(
            key: _drawerFaqsNavKey,
            title: 'FAQs',
            description:
            'Any doubts you have about AdaptEd could be cleared here!',
            child: _buildNavItem(context, theme, Icons.help_outline,
                "FAQs", '/faqs', currentRoute,
                isDrawer: true),
          ),
          Showcase(
            key: _drawerTutorialNavKey,
            title: 'App Tutorial',
            description:
            'If you ever need to you could get an app tutorial over here!',
            child: _buildNavItem(
              context,
              theme,
              Icons.play_circle_outline,
              "App Tutorial",
              '/app_tutorial',
              currentRoute,
              onTapOverride: () => _startGlobalTutorial(),
            ),
          ),
          const Divider(),
          Showcase(
            key: _drawerSettingsNavKey,
            title: 'Settings',
            description:
            'Customize and Personalize your AdaptEd experience here!',
            child: _buildNavItem(context, theme, Icons.settings_outlined,
                "Settings", '/settings', currentRoute,
                isDrawer: true),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context,
      DynamicTheme theme,
      IconData icon,
      String label,
      String route,
      String currentRoute, {
        bool isDrawer = false,
        VoidCallback? onTapOverride,
      }) {
    final isSelected = currentRoute == route ||
        (route == '/dashboard' && currentRoute == '/');
    final showLabel = _isSidebarExpanded || isDrawer;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? theme.primaryColor : Colors.grey[600],
      ),
      title: showLabel
          ? Text(
        label,
        style: TextStyle(
          fontFamily: theme.bodyStyle.fontFamily,
          color: isSelected ? theme.primaryColor : Colors.grey[800],
          fontWeight:
          isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      )
          : null,
      selected: isSelected,
      onTap: () {
        if (onTapOverride != null) {
          onTapOverride();
          return;
        }
        if (currentRoute != route) {
          if (isDrawer) Navigator.pop(context);
          Navigator.pushReplacementNamed(context, route);
        }
      },
      contentPadding: showLabel
          ? const EdgeInsets.symmetric(horizontal: 16)
          : const EdgeInsets.only(left: 24),
    );
  }

  Widget _buildDesktopAppBar(
      BuildContext context, DynamicTheme theme, User? user) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        border: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.abc, size: 28),
            tooltip: "Toggle Dyslexic Font",
            onPressed: () => theme.toggleDyslexicFont(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
                theme.focusMode ? Icons.visibility_off : Icons.visibility,
                size: 24),
            tooltip: "Toggle Focus Mode",
            onPressed: () => theme.toggleFocusMode(),
          ),
          const SizedBox(width: 16),
          if (user != null)
            CircleAvatar(
              backgroundColor: theme.primaryColor,
              radius: 16,
              child: Text(
                (user.displayName != null && user.displayName!.isNotEmpty)
                    ? user.displayName!.substring(0, 1).toUpperCase()
                    : "U",
                style: const TextStyle(color: Colors.white),
              ),
            ),
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