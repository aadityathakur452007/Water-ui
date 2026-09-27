import 'package:flutter/material.dart';
import 'package:flutter_ui_collection/flutter_ui_collection.dart';
import 'package:shop/entry_point.dart';
import 'package:shop/route/router.dart' as router;
import 'package:shop/screens/auth/views/login_screen.dart';
import 'package:shop/screens/onbording/views/onbording_screnn.dart';
import 'package:shop/services/session_store.dart';
import 'package:shop/theme/app_theme.dart';
import 'package:shop/theme/water_ui_theme.dart';

void main() {
  runApp(const MyApp());
}

// Thanks for using our template. You are using the free version of the template.
// 🔗 Full template: https://theflutterway.gumroad.com/l/fluttershop

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // UiTheme ancestor for every flutter_ui_collection widget (notably
    // VendorDashboardScreen's UiKpiRow/UiBarChart — without this the
    // release build hits `widget!.data` null and blanks the screen).
    return UiTheme(
      data: waterUiThemeData(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Shodasha Mineral Waters',
        theme: AppTheme.lightTheme(context),
        // Dark theme is inclided in the Full template
        themeMode: ThemeMode.light,
        onGenerateRoute: router.generateRoute,
        onUnknownRoute: router.onUnknownRoute,
        home: const _BootGate(),
      ),
    );
  }
}

/// Pure boot decision (unit-tested): first launch → onboarding; otherwise
/// a saved token → entry tabs (never onboarding/login); else login.
String bootDestination({required bool seenOnboarding, required String? token}) {
  if (!seenOnboarding) return 'onboarding';
  if (token != null && token.isNotEmpty) return 'entry';
  return 'login';
}

/// First-run + session gate. Onboarding shows only when the
/// `seen_onboarding` flag is unset; afterwards a saved token goes straight
/// to the entry tabs (route-root, so system back exits instead of
/// resurfacing login/onboarding), else login. A dead token is not
/// validated here — it 401s into the existing auto-logout path on first
/// use. Entry is returned as `home`, so post-auth stacks stay clean.
class _BootGate extends StatefulWidget {
  const _BootGate();

  @override
  State<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<_BootGate> {
  int _attempt = 0;
  late Future<({bool seen, String? token})> _future;

  @override
  void initState() {
    super.initState();
    _future = _decide();
  }

  Future<({bool seen, String? token})> _decide() async {
    const sessions = SessionStore();
    final seen = await sessions.readSeenOnboarding();
    final token = await sessions.readToken();
    return (
      seen: seen,
      token: (token == null || token.isEmpty) ? null : token,
    );
  }

  void _retry() => setState(() {
        _attempt++;
        _future = _decide();
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({bool seen, String? token})>(
      // [_attempt] only retriggers the future via [_retry].
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _splash();
        }
        if (snap.hasError) {
          // Honest offline-at-launch state: retry, never a spinner forever.
          return Scaffold(
            key: ValueKey('boot-error-$_attempt'),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.water_drop_outlined,
                        size: 48, color: Color(0xFF1B7BD6)),
                    const SizedBox(height: 16),
                    Text(
                      'Could not start',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final seen = snap.data?.seen ?? false;
        final token = snap.data?.token;
        switch (bootDestination(seenOnboarding: seen, token: token)) {
          case 'entry':
            return const EntryPoint();
          case 'login':
            return const LoginScreen();
          default:
            return const OnBordingScreen();
        }
      },
    );
  }

  /// Redirecting indicator while the gate decides — logo + loader on
  /// white, no white flash, no gradients.
  Widget _splash() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/shodasha_logo.png',
                height: 96,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.water_drop,
                  size: 64,
                  color: Color(0xFF1B7BD6),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
