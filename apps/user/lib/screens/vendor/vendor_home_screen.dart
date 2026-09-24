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

  Future<void> _logout() async {
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
      VendorDashboardScreen(service: _service),
      VendorOrdersScreen(service: _service),
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
        onTap: (i) => setState(() => _index = i),
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
