import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart' hide ProfileScreen;

import 'firebase_options.dart';
import 'core/theme/dynamic_theme.dart';
import 'core/services/user_service.dart';
import 'core/services/ai_service.dart';
import 'core/services/firestore_service.dart';
import 'core/widgets/error_boundary.dart';
import 'core/widgets/adaptive_layout_shell.dart';
import 'core/utils/logger.dart';

// Screens
import 'features/dashboard/dashboard_screen.dart';
import 'features/quiz/quiz_intro_screen.dart';
import 'features/quiz/quiz_screen.dart';
import 'features/library/library_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/faq/faq_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupGlobalErrorHandling();

  try {
    await dotenv.load(fileName: ".env");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info('App initialization successful');
  } catch (e, stack) {
    AppLogger.error('App initialization failed', error: e, stackTrace: stack);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => DynamicTheme()), // ← already correct ✅
        ChangeNotifierProvider(create: (_) => UserService()),
        Provider(create: (_) => AIService()),
        Provider(create: (_) => FirestoreService()),
      ],
      child: const ErrorBoundary(
        child: AdaptEdApp(),
      ),
    ),
  );
}

class AdaptEdApp extends StatelessWidget {
  const AdaptEdApp({super.key});

  @override
  Widget build(BuildContext context) {
    // context.watch() triggers a full rebuild when traits change
    // This is the only change from your original — watch instead of Consumer
    final theme = context.watch<DynamicTheme>();

    return MaterialApp(
      title: 'AdaptEd',
      theme: theme.themeData, // ← single source of truth ✅
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => AuthWrapper(route: settings.name),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final String? route;
  const AuthWrapper({super.key, this.route});

  @override
  Widget build(BuildContext context) {
    final userService = Provider.of<UserService>(context);
    final role = userService.role;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // 2. Unauthenticated → Login
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 3. Wait for profile to load
        if (!userService.isInitialized) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // 4. Sync traits → DynamicTheme  ← KEY CHANGE: moved into a helper
        _syncTraitsToTheme(context, userService);

        // 5. Role-based routing
        if (role == 'admin') {
          if (route == '/' || route == '/dashboard' || route == '/admin') {
            return const AdminDashboardScreen();
          }
        }

        // 6. First-time learner → Quiz
        if (userService.currentTraits == null) {
          return const QuizIntroductionScreen();
        }

        // 7. Main app shell
        return AdaptiveLayoutShell(
          child: _getPageForRoute(route),
        );
      },
    );
  }

  // Extracted into a clean helper so the builder stays readable.
  // addPostFrameCallback ensures we don't call setState during build.
  void _syncTraitsToTheme(BuildContext context, UserService userService) {
    if (userService.currentTraits == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // listen: false is correct here — we're writing, not watching
      Provider.of<DynamicTheme>(context, listen: false)
          .setTraits(userService.currentTraits!);
    });
  }

  Widget _getPageForRoute(String? route) {
    switch (route) {
      case '/dashboard':
      case '/':
        return const DashboardScreen();
      case '/library':
        return const LibraryScreen();
      case '/analytics':
        return const AnalyticsScreen();
      case '/profile':
        return const ProfileScreen();
      case '/settings':
        return const SettingsScreen();
      case '/faqs':
        return const FAQScreen();
      case '/quiz':
        return const QuizScreen();
      default:
        return const DashboardScreen();
    }
  }
}

// --- PLACEHOLDERS ---

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SignInScreen(
      providers: [EmailAuthProvider()],
      actions: [
        AuthStateChangeAction<SignedIn>((context, state) {
          // UserService handles data fetching on next stream update
        }),
      ],
    );
  }
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: const Center(child: Text("Admin Features Coming Soon")),
    );
  }
}
