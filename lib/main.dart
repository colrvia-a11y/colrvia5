// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/debug.dart';
import 'package:color_canvas/screens/home_screen.dart';
import 'package:color_canvas/screens/auth_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';

bool isFirebaseInitialized = false;

class MyApp {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    // App Check (swap providers as needed)
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );

    // Crashlytics wiring
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Warm up analytics/perf
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    FirebasePerformance.instance; // lazy start
    isFirebaseInitialized = true;

    runApp(const App());
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    AnalyticsService.instance.logAppOpen();
    return MaterialApp(
      title: 'Colrvia',
      theme: ThemeData(useMaterial3: true),
      navigatorKey: MyApp.navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      builder: (context, child) {
        // Respect text scaling for accessibility
        final media = MediaQuery.of(context);
        final scale = media.textScaler.clamp(maxScaleFactor: 1.3);
        return MediaQuery(data: media.copyWith(textScaler: scale), child: child ?? const SizedBox());
      },
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  Timer? _debugTimer;

  @override
  void initState() {
    super.initState();
    Debug.info(
        'AuthCheckScreen', 'initState', 'Auth check screen initializing');
    _checkAuthState();
    _startDebugTimer();
  }

  void _startDebugTimer() {
    // Print debug summary every 10 seconds to track infinite loop patterns
    _debugTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      Debug.summary();
    });
  }

  @override
  void dispose() {
    _debugTimer?.cancel();
    super.dispose();
  }

  void _checkAuthState() {
    // Give users immediate access to the app
    // They can choose to sign in later from settings
    Debug.postFrameCallback('AuthCheckScreen', '_checkAuthState',
        details: 'Checking auth state');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Debug.info(
          'AuthCheckScreen', '_checkAuthState', 'PostFrameCallback executing');
      if (FirebaseAuth.instance.currentUser != null) {
        Debug.info('AuthCheckScreen', '_checkAuthState',
            'User signed in, navigating to home');
        // User is already signed in, go to home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      } else {
        Debug.info('AuthCheckScreen', '_checkAuthState',
            'User not signed in, navigating to home anyway');
        // User not signed in, but allow app access
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.palette,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ColorCanvas',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
