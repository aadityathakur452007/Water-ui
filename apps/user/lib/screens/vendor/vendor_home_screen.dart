import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/services/auth_service.dart';
import 'package:shop/services/vendor_service.dart';

import 'vendor_dashboard_screen.dart';
import 'vendor_deliveries_screen.dart';
import 'vendor_orders_screen.dart';

/// Vendor home: Dashboard / Orders / Deliveries tabs + logout.
/// Reached only after a vendor-role login (see LoginScreen).
class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  int _index = 0;
  final _service = const VendorService();

  /// Bumped whenever the Dashboard tab is (re)selected: the new key
  /// recreates [VendorDashboardScreen] so KPIs re-fetch on tab revisit.
  int _dashNonce = 0;

  void _goTab(int i) => setState(() {
        _index = i;
        if (i == 0) _dashNonce++;
      });

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await const AuthService().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      logInScreenRoute,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      VendorDashboardScreen(
          key: ValueKey(_dashNonce), service: _service),
      VendorOrdersScreen(
          service: _service, onViewDashboard: () => _goTab(0)),
      VendorDeliveriesScreen(service: _service),
    ];
    const titles = ['Dashboard', 'Orders', 'Deliveries'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: primaryColor,
        type: BottomNavigationBarType.fixed,
        onTap: _goTab,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping), label: 'Orders'),
          BottomNavigationBarItem(
              icon: Icon(Icons.repeat), label: 'Deliveries'),
        ],
      ),
    );
  }
}
