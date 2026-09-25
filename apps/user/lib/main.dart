import 'package:flutter/material.dart';
import 'package:flutter_ui_collection/flutter_ui_collection.dart';
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
        title: 'Water Delivery',
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

/// Minimal stale-token boot check: no saved token → straight to login;
/// otherwise the regular onboarding flow. Cheap and honest — it does not
/// validate the token against the server (a dead token 401s into the
/// existing auto-logout path on first use).
class _BootGate extends StatelessWidget {
  const _BootGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: const SessionStore().readToken(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == null || snap.data!.isEmpty) {
          return const LoginScreen();
        }
        return const OnBordingScreen();
      },
    );
  }
}
