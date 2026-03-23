import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' hide ProfileScreen;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/services/ai_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/user_service.dart';
import 'core/theme/dynamic_theme.dart';
import 'core/utils/logger.dart';
import 'core/widgets/adaptive_layout_shell.dart';
import 'core/widgets/error_boundary.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/faq/faq_screen.dart';
import 'features/library/library_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/quiz/quiz_intro_screen.dart';
import 'features/quiz/quiz_screen.dart';
import 'features/settings/settings_screen.dart';
import 'firebase_options.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupGlobalErrorHandling();

  try {
    await dotenv.load(fileName: '.env');
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
        ChangeNotifierProvider(create: (_) => DynamicTheme()),
        ChangeNotifierProvider(create: (_) => UserService()),
        Provider(create: (_) {
          final service = AIService();
          service.initializePrompts();
          return service;
        }),
        Provider(create: (_) => FirestoreService()),
      ],
      child: const ErrorBoundary(
        child: AdaptEdApp(),
      ),
    ),
  );
}

class AdaptEdApp extends StatefulWidget {
  const AdaptEdApp({super.key});

  // This powerful static method allows us to explicitly restart the entire app state
  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_AdaptEdAppState>()?.restartApp();
  }

  @override
  State<AdaptEdApp> createState() => _AdaptEdAppState();
}

class _AdaptEdAppState extends State<AdaptEdApp> {
  // A UniqueKey attached to MaterialApp forces the framework to destroy and rebuild everything if it changes
  Key _key = UniqueKey();

  void restartApp() {
    setState(() {
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DynamicTheme>();

    return MaterialApp(
      key: _key, // <-- This guarantees a complete memory flush on logout!
      title: 'AdaptEd',
      theme: theme.themeData,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => AuthWrapper(
            route: settings.name,
            arguments: settings.arguments,
          ),
        );
      },
    );
  }
}


class AuthWrapper extends StatelessWidget {
  final String? route;
  final Object? arguments;
  const AuthWrapper({super.key, this.route, this.arguments});

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

        // 4. Sync traits → DynamicTheme
        _syncTraitsToTheme(context, userService);

        // 5. THIS IS THE NEW ADMIN ROUTING OVERRIDE!
        if (role == 'admin') {
          if (route == '/' || route == '/dashboard' || route == '/admin') {
            return const AdminDashboardScreen();
          }
        }
        // 6. First-time learner → Quiz
        if (userService.currentTraits == null) {
          return const QuizIntroductionScreen();
        }
        // 7. Main app shell (For standard learners)
        return AdaptiveLayoutShell(
          child: _getPageForRoute(route, arguments),
        );
      },
    );
  }

  // addPostFrameCallback ensures we don't call setState during build.
  void _syncTraitsToTheme(BuildContext context, UserService userService) {
    if (userService.currentTraits == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DynamicTheme>(context, listen: false)
          .setTraits(userService.currentTraits!);
    });
  }

  Widget _getPageForRoute(String? route, Object? arguments) {
    switch (route) {
      case '/dashboard':
      case '/':
        return DashboardScreen(
            initialArguments: arguments as Map<String, dynamic>?);
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

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HeroMode(
      enabled: false, // <-- THIS IS THE MAGIC FIX. Kills the animation deadlock!
      child: SignInScreen(
        providers: [EmailAuthProvider()],
        actions: [
          AuthStateChangeAction<SignedIn>((context, state) {
            // UserService handles data fetching on next stream update
          }),
        ],
      ),
    );
  }
}

