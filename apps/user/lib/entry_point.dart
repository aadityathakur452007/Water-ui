import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/screen_export.dart';

class EntryPoint extends StatefulWidget {
  /// Post-checkout / deep-link entry.
  ///
  /// Route-argument contract (parsed defensively by [parseEntryPointArgs]):
  /// `{tab: int, openOrderId: String?, showPlacedToast: bool}`.
  /// - [initialTab] selects the bottom-nav index (Orders lives at index 1).
  /// - [openOrderId] is left on the route arguments so [OrdersScreen]'s
  ///   existing auto-open (which reads `ModalRoute` args) can pick it up.
  /// - [showPlacedToast] shows a one-time "Order placed" SnackBar.
  const EntryPoint({
    super.key,
    this.initialTab = 0,
    this.openOrderId,
    this.showPlacedToast = false,
  });

  final int initialTab;
  final String? openOrderId;
  final bool showPlacedToast;

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

/// Defensive parser for the entry-point route arguments. Anything missing
/// or wrong-typed falls back to defaults (tab 0, no order, no toast) and
/// never throws — invalid args must never crash the entry surface.
({int tab, String? openOrderId, bool showPlacedToast}) parseEntryPointArgs(
  Object? args,
) {
  const ({int tab, String? openOrderId, bool showPlacedToast}) none =
      (tab: 0, openOrderId: null, showPlacedToast: false);
  if (args == null) return none;
  if (args is int) {
    return (tab: _clampTab(args), openOrderId: null, showPlacedToast: false);
  }
  if (args is String) {
    // Legacy shape: a bare order id (checkout used to push it directly).
    final id = args.trim();
    if (id.isEmpty) return none;
    return (tab: 1, openOrderId: id, showPlacedToast: false);
  }
  if (args is Map) {
    final rawTab = args['tab'];
    final tab = rawTab is int ? _clampTab(rawTab) : 0;
    String? openOrderId;
    final rawOpen = args['openOrderId'];
    if (rawOpen is String && rawOpen.trim().isNotEmpty) {
      openOrderId = rawOpen.trim();
    } else {
      // Alias the key OrdersScreen's existing auto-open already reads.
      final legacy = args['orderId'];
      if (legacy is String && legacy.trim().isNotEmpty) {
        openOrderId = legacy.trim();
      }
    }
    return (
      tab: tab,
      openOrderId: openOrderId,
      showPlacedToast: args['showPlacedToast'] == true,
    );
  }
  return none;
}

int _clampTab(int tab) => tab < 0 ? 0 : (tab > 3 ? 3 : tab);

class _EntryPointState extends State<EntryPoint> {
  List<Widget> get _pages => const [
        HomeScreen(),
        OrdersScreen(),
        DiscoverScreen(),
        ProfileScreen(),
      ];
  late int _currentIndex;
  bool _routeArgsAdopted = false;
  bool _toastShown = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = _clampTab(widget.initialTab);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fallback for pushes that bypass generateRoute (direct
    // MaterialPageRoute): adopt valid route args the constructor missed.
    // generateRoute already forwards via the constructor, so when both
    // agree this is a no-op.
    if (_routeArgsAdopted) return;
    _routeArgsAdopted = true;
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs == null) {
      _maybeShowPlacedToast();
      return;
    }
    final parsed = parseEntryPointArgs(routeArgs);
    if (widget.initialTab == 0 &&
        widget.openOrderId == null &&
        !widget.showPlacedToast) {
      _currentIndex = parsed.tab;
    }
    _maybeShowPlacedToast(
        show: widget.showPlacedToast || parsed.showPlacedToast);
  }

  void _maybeShowPlacedToast({bool? show}) {
    if (_toastShown) return;
    if (!(show ?? widget.showPlacedToast)) return;
    _toastShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // pinned: true,
        // floating: true,
        // snap: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: const SizedBox(),
        leadingWidth: 0,
        centerTitle: false,
        title: Image.asset(
          "assets/images/shodasha_logo.png",
          height: 28,
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, searchScreenRoute);
            },
            icon: SvgPicture.asset(
              "assets/icons/Search.svg",
              height: 24,
              colorFilter: ColorFilter.mode(
                  Theme.of(context).textTheme.bodyLarge!.color!,
                  BlendMode.srcIn),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, notificationsScreenRoute);
            },
            icon: SvgPicture.asset(
              "assets/icons/Notification.svg",
              height: 24,
              colorFilter: ColorFilter.mode(
                  Theme.of(context).textTheme.bodyLarge!.color!,
                  BlendMode.srcIn),
            ),
          ),
        ],
      ),
      // body: _pages[_currentIndex],
      body: PageTransitionSwitcher(
        duration: defaultDuration,
        transitionBuilder: (child, animation, secondAnimation) {
          return FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondAnimation,
            child: child,
          );
        },
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(top: defaultPadding / 2),
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF101015),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index != _currentIndex) {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF101015),
          type: BottomNavigationBarType.fixed,
          // selectedLabelStyle: TextStyle(color: primaryColor),
          selectedFontSize: 12,
          selectedItemColor: primaryColor,
          unselectedItemColor: blackColor60,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.water_drop_outlined),
              activeIcon: Icon(Icons.water_drop),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: "Orders",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined),
              activeIcon: Icon(Icons.shopping_bag),
              label: "Shop",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: "Account",
            ),
          ],
        ),
      ),
    );
  }
}
