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

// Screens - Only importing existing files
import 'features/admin/admin_dashboard_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/quiz/quiz_intro_screen.dart';
import 'features/quiz/quiz_screen.dart';
import 'features/library/library_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/faq/faq_screen.dart';
// import 'features/chat/quick_chat_screen.dart'; // Optional if needed

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Global Error Handling
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
        ChangeNotifierProvider(create: (_) => DynamicTheme()),
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
    return Consumer<DynamicTheme>(
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'AdaptEd',
          // FIX: Use theme.themeData correctly
          theme: theme.themeData, 
          debugShowCheckedModeBanner: false,
          
          initialRoute: '/',
          
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: settings, 
              builder: (context) => AuthWrapper(route: settings.name),
            );
          },
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. Unauthenticated -> Login Screen (Placeholder/FirebaseUI)
        if (!snapshot.hasData) {
          return const LoginScreen(); 
        }

        // 3. Authenticated -> Wait for User Profile Initialization
        if (!userService.isInitialized) {
           return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Sync theme with user traits
        if (userService.currentTraits != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<DynamicTheme>(context, listen: false)
                .setTraits(userService.currentTraits!);
          });
        }

        // 4. Role-based Routing
        if (role == 'admin') {
           if (route == '/admin') {
             return const AdminDashboardScreen(); 
           }
           // Admins default to admin dashboard
           if (route == '/' || route == '/dashboard') {
             return const AdminDashboardScreen();
           }
        }

        // 5. Learner Logic
        if (userService.currentTraits == null) {
          return const QuizIntroductionScreen();
        }

        // 6. Navigation
        return AdaptiveLayoutShell(
          child: _getPageForRoute(route),
        );
      },
    );
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
      // Add other routes as needed
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
           // User Service will handle data fetching on next stream update
        }),
      ],
    );
  }
}

