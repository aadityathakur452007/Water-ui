import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop/entry_point.dart';
import 'package:shop/main.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/route/router.dart' as router;
import 'package:shop/screens/auth/views/login_screen.dart';
import 'package:shop/screens/onbording/views/onbording_screnn.dart';
import 'package:shop/services/session_store.dart';

/// Boot + entry-args gate: first-run/session routing matrix, defensive
/// entry-point args, onboarding flag set-once, post-auth back-stack.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('bootDestination matrix', () {
    test('first run goes to onboarding even with a token', () {
      expect(
        bootDestination(seenOnboarding: false, token: 'abc'),
        'onboarding',
      );
      expect(
        bootDestination(seenOnboarding: false, token: null),
        'onboarding',
      );
    });

    test('returning user with token goes to entry, never login/onboarding',
        () {
      expect(
        bootDestination(seenOnboarding: true, token: 'abc'),
        'entry',
      );
    });

    test('returning user without token goes to login', () {
      expect(bootDestination(seenOnboarding: true, token: null), 'login');
      expect(bootDestination(seenOnboarding: true, token: ''), 'login');
    });
  });

  group('parseEntryPointArgs', () {
    test('null and empty shapes fall back to defaults, never throw', () {
      for (final bad in <Object?>[
        null,
        <String, dynamic>{},
        '',
        '   ',
        true,
        3.5,
        ['tab'],
      ]) {
        final parsed = parseEntryPointArgs(bad);
        expect(parsed.tab, 0, reason: '$bad');
        expect(parsed.openOrderId, isNull, reason: '$bad');
        expect(parsed.showPlacedToast, isFalse, reason: '$bad');
      }
    });

    test('valid contract map parses fully', () {
      final parsed = parseEntryPointArgs({
        'tab': 1,
        'openOrderId': 'WD-7',
        'showPlacedToast': true,
      });
      expect(parsed.tab, 1);
      expect(parsed.openOrderId, 'WD-7');
      expect(parsed.showPlacedToast, isTrue);
    });

    test('wrong-typed values degrade per-field, never crash', () {
      final parsed = parseEntryPointArgs({
        'tab': '1',
        'openOrderId': 42,
        'showPlacedToast': 'yes',
      });
      expect(parsed.tab, 0);
      expect(parsed.openOrderId, isNull);
      expect(parsed.showPlacedToast, isFalse);
    });

    test('tab clamps to the 4-tab range instead of crashing', () {
      expect(parseEntryPointArgs({'tab': 9}).tab, 3);
      expect(parseEntryPointArgs({'tab': -2}).tab, 0);
      expect(parseEntryPointArgs(2).tab, 2);
    });

    test('legacy orderId aliases to openOrderId; openOrderId wins', () {
      expect(
        parseEntryPointArgs({'orderId': 'WD-1'}).openOrderId,
        'WD-1',
      );
      expect(
        parseEntryPointArgs(
          {'orderId': 'WD-1', 'openOrderId': 'WD-2'},
        ).openOrderId,
        'WD-2',
      );
      expect(parseEntryPointArgs('WD-9').openOrderId, 'WD-9');
      expect(parseEntryPointArgs('WD-9').tab, 1);
    });
  });

  group('onboarding flag', () {
    test('unset by default, set-once and idempotent', () async {
      const sessions = SessionStore();
      expect(await sessions.readSeenOnboarding(), isFalse);
      await sessions.setSeenOnboarding();
      expect(await sessions.readSeenOnboarding(), isTrue);
      await sessions.setSeenOnboarding();
      expect(await sessions.readSeenOnboarding(), isTrue);
    });

    test('sign-out keeps the flag (onboarding never resurfaces)', () async {
      const sessions = SessionStore();
      await sessions.setSeenOnboarding();
      await sessions.saveSession(token: 't', user: {'role': 'user'});
      await sessions.clear();
      expect(await sessions.readToken(), isNull);
      expect(await sessions.readSeenOnboarding(), isTrue);
    });
  });

  group('entry_point route normalization', () {
    test('contract args keep both openOrderId and orderId keys', () {
      final route = router.generateRoute(
        const RouteSettings(
          name: entryPointScreenRoute,
          arguments: {
            'tab': 1,
            'openOrderId': 'WD-1',
            'showPlacedToast': true,
          },
        ),
      );
      final args = route.settings.arguments as Map;
      expect(args['tab'], 1);
      expect(args['openOrderId'], 'WD-1');
      expect(args['orderId'], 'WD-1');
      expect(args['showPlacedToast'], isTrue);
    });

    test('garbage args normalize to defaults without throwing', () {
      final route = router.generateRoute(
        const RouteSettings(
          name: entryPointScreenRoute,
          arguments: {'tab': 'x', 'openOrderId': 42},
        ),
      );
      final args = route.settings.arguments as Map;
      expect(args['tab'], 0);
      expect(args.containsKey('openOrderId'), isFalse);
      expect(args['showPlacedToast'], isFalse);
    });
  });

  group('boot widgets', () {
    testWidgets('first run shows onboarding', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _TestAssetBundle(),
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OnBordingScreen), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('returning user with token lands on entry tabs', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'seen_onboarding': true,
        'auth_token': 'demo-token-user',
      });
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _TestAssetBundle(),
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EntryPoint), findsOneWidget);
      expect(find.byType(OnBordingScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('returning user without token lands on login', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'seen_onboarding': true});
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _TestAssetBundle(),
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OnBordingScreen), findsNothing);
    });

    testWidgets('bad entry args land on Home tab, no crash', (tester) async {
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _TestAssetBundle(),
          child: MaterialApp(
            onGenerateRoute: router.generateRoute,
            onUnknownRoute: router.onUnknownRoute,
            home: Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushNamed(
                    context,
                    entryPointScreenRoute,
                    arguments: const {'tab': 'x', 'openOrderId': 42},
                  );
                });
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EntryPoint), findsOneWidget);
      expect(
        tester
            .widget<BottomNavigationBar>(
              find.byType(BottomNavigationBar),
            )
            .currentIndex,
        0,
      );
    });

    testWidgets('showPlacedToast fires once then is consumed', (tester) async {
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _TestAssetBundle(),
          child: MaterialApp(
            onGenerateRoute: router.generateRoute,
            onUnknownRoute: router.onUnknownRoute,
            home: Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushNamed(
                    context,
                    entryPointScreenRoute,
                    arguments: const {
                      'tab': 0,
                      'showPlacedToast': true,
                    },
                  );
                });
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Order placed successfully'), findsOneWidget);

      // Let the SnackBar expire, then switching tabs must not resurface
      // the toast (one-time, consumed on arrival).
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Order placed successfully'), findsNothing);
      await tester.tap(find.text('Shop'));
      await tester.pumpAndSettle();
      expect(find.text('Order placed successfully'), findsNothing);
    });

    testWidgets('post-auth back-stack: login removed after demo login', (
      tester,
    ) async {
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _TestAssetBundle(),
          child: const MaterialApp(
            onGenerateRoute: router.generateRoute,
            onUnknownRoute: router.onUnknownRoute,
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Try as Demo User'));
      await tester.tap(find.text('Try as Demo User'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryPoint), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      // System back from entry tabs must not resurface login: entry is
      // the route-root (no back button, nothing to pop to).
      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      expect(navigator.canPop(), isFalse);
      expect(await navigator.maybePop(), isFalse);
      await tester.pumpAndSettle();
      expect(find.byType(EntryPoint), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}

/// Serves a 1px PNG for raster keys and a stub SVG for vector keys so
/// screens with Image/SvgPicture assets pump without a real bundle.
class _TestAssetBundle extends CachingAssetBundle {
  static final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );
  static final Uint8List _svg = Uint8List.fromList(
    utf8.encode(
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"></svg>',
    ),
  );

  @override
  Future<ByteData> load(String key) async {
    // Empty manifests so variant resolution succeeds without a real bundle.
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, dynamic>{})!;
    }
    if (key == 'AssetManifest.json' || key == 'FontManifest.json') {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode('{}')));
    }
    return key.endsWith('.svg')
        ? ByteData.sublistView(_svg)
        : ByteData.sublistView(_png);
  }
}
