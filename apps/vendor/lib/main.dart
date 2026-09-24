import 'package:flutter/material.dart';
import 'package:flutter_ui_collection/flutter_ui_collection.dart';

import 'core/api_client.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/dashboard_service.dart';
import 'features/orders/orders_screen.dart';
import 'features/orders/orders_service.dart';
import 'features/subscriptions/subscriptions_screen.dart';
import 'features/subscriptions/subscriptions_service.dart';

void main() {
  runApp(const VendorApp());
}

class VendorApp extends StatefulWidget {
  const VendorApp({super.key});

  @override
  State<VendorApp> createState() => _VendorAppState();
}

class _VendorAppState extends State<VendorApp> {
  final _session = Session();
  late final ApiClient _api;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _session.load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return UiTheme(
      data: VendorTheme.ui(),
      child: MaterialApp(
        title: 'Water Vendor',
        theme: VendorTheme.material(),
        home: !_ready
            ? const Scaffold(
                body: Center(child: CircularProgressIndicator()))
            : _session.isSignedIn
                ? VendorHome(
                    api: _api,
                    session: _session,
                    onSignedOut: _refresh,
                  )
                : LoginScreen(
                    auth: AuthService(_api, _session),
                    onSignedIn: _refresh,
                  ),
      ),
    );
  }
}

class VendorHome extends StatefulWidget {
  const VendorHome(
      {super.key,
      required this.api,
      required this.session,
      required this.onSignedOut});

  final ApiClient api;
  final Session session;
  final VoidCallback onSignedOut;

  @override
  State<VendorHome> createState() => _VendorHomeState();
}

class _VendorHomeState extends State<VendorHome> {
  int _tab = 0;

  Future<void> _logout() async {
    await widget.session.clear();
    widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Dashboard', 'Orders', 'Subscriptions'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          DashboardScreen(
              service: DashboardService(widget.api, widget.session)),
          OrdersScreen(
              service: OrdersService(widget.api, widget.session),
              onLogout: _logout),
          SubscriptionsScreen(
              service: SubscriptionsService(widget.api, widget.session)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.repeat), label: 'Subscriptions'),
        ],
      ),
    );
  }
}
