import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shop/components/list_tile/divider_list_tile.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/screen_export.dart';
import 'package:shop/services/auth_service.dart';
import 'package:shop/services/session_store.dart';

import 'components/profile_card.dart';
import 'components/profile_menu_item_list_tile.dart';

void _showComingSoon(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      showCloseIcon: true,
      content: Row(
        children: [
          const Icon(Icons.upcoming_outlined,
              color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: CircleAvatar(radius: 28, backgroundColor: blackColor10),
      title: _Bar(width: 120),
      subtitle: _Bar(width: 180),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      height: 12,
      width: width,
      decoration: BoxDecoration(
        color: blackColor10,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: const SessionStore().readUser(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _ProfileSkeleton();
              }
              final user = snap.data;
              return ProfileCard(
                name: user?['name']?.toString() ?? "Guest",
                email: user?['email']?.toString() ??
                    user?['phone']?.toString() ??
                    "Not signed in",
                imageSrc: "https://i.imgur.com/IXnwbLk.png",
                // proLableText: "Sliver",
                // isPro: true, if the user is pro
                press: () {
                  Navigator.pushNamed(context, userInfoScreenRoute);
                },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: defaultPadding, vertical: defaultPadding * 1.5),
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, subscriptionsScreenRoute);
              },
              child: Container(
                padding: const EdgeInsets.all(defaultPadding),
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF4FC),
                  borderRadius: BorderRadius.all(
                      Radius.circular(defaultBorderRadious)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.water_drop,
                        color: primaryColor, size: 28),
                    SizedBox(width: defaultPadding),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Never run dry",
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Set up a regular water delivery",
                            style: TextStyle(
                                color: blackColor60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
            child: Text(
              "Account",
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: defaultPadding / 2),
          ProfileMenuListTile(
            text: "Orders",
            svgSrc: "assets/icons/Order.svg",
            press: () {
              Navigator.pushNamed(context, ordersScreenRoute);
            },
          ),
          ProfileMenuListTile(
            text: "My Regular Deliveries",
            svgSrc: "assets/icons/Calender.svg",
            press: () {
              Navigator.pushNamed(context, subscriptionsScreenRoute);
            },
          ),
          ProfileMenuListTile(
            text: "Addresses",
            svgSrc: "assets/icons/Address.svg",
            press: () {
              Navigator.pushNamed(context, addressesScreenRoute);
            },
          ),
          ProfileMenuListTile(
            text: "Payment Methods",
            svgSrc: "assets/icons/card.svg",
            press: () {
              Navigator.pushNamed(context, paymentMethodsScreenRoute);
            },
          ),
          ProfileMenuListTile(
            text: "Wallet",
            svgSrc: "assets/icons/Wallet.svg",
            press: () {
              Navigator.pushNamed(context, walletScreenRoute);
            },
          ),
          const SizedBox(height: defaultPadding),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: defaultPadding, vertical: defaultPadding / 2),
            child: Text(
              "Personalization",
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          DividerListTileWithTrilingText(
            svgSrc: "assets/icons/Notification.svg",
            title: "Notification",
            trilingText: "Off",
            press: () {
              Navigator.pushNamed(context, notificationsScreenRoute);
            },
          ),
          ProfileMenuListTile(
            text: "Preferences",
            svgSrc: "assets/icons/Preferences.svg",
            press: () {
              Navigator.pushNamed(context, preferencesScreenRoute);
            },
          ),
          const SizedBox(height: defaultPadding),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: defaultPadding, vertical: defaultPadding / 2),
            child: Text(
              "Settings",
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ProfileMenuListTile(
            text: "Language",
            svgSrc: "assets/icons/Language.svg",
            press: () {
              _showComingSoon(context, "More languages coming soon.");
            },
            isShowDivider: false,
          ),
          const SizedBox(height: defaultPadding),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: defaultPadding, vertical: defaultPadding / 2),
            child: Text(
              "Help & Support",
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ProfileMenuListTile(
            text: "Get Help",
            svgSrc: "assets/icons/Help.svg",
            press: () {
              _showComingSoon(context, "Support chat coming soon.");
            },
            isShowDivider: false,
          ),
          const SizedBox(height: defaultPadding),

          // Log Out
          ListTile(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text("Log out?"),
                  content: const Text(
                      "You will need to log in again to order water."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text("Log out"),
                    ),
                  ],
                ),
              );
              if (confirm != true || !context.mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              await const AuthService().logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                logInScreenRoute,
                (_) => false,
              );
              messenger.showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text("Logged out"),
                    ],
                  ),
                ),
              );
            },
            minLeadingWidth: 24,
            leading: SvgPicture.asset(
              "assets/icons/Logout.svg",
              height: 24,
              width: 24,
              colorFilter: const ColorFilter.mode(
                errorColor,
                BlendMode.srcIn,
              ),
            ),
            title: const Text(
              "Log Out",
              style: TextStyle(color: errorColor, fontSize: 14, height: 1),
            ),
          )
        ],
      ),
    );
  }
}
