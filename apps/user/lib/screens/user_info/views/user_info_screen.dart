import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/services/session_store.dart';

/// Account details from the signed-in session ([SessionStore]).
/// The backend exposes no profile endpoint, so this screen shows
/// exactly what the session holds — nothing invented.
class UserInfoScreen extends StatelessWidget {
  const UserInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: const SessionStore().readUser(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: defaultPadding / 2),
                  Text("Loading profile"),
                ],
              ),
            );
          }
          final user = snap.data;
          if (user == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding * 1.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Not signed in",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Log in to see your profile.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: defaultPadding),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          logInScreenRoute,
                          (_) => false,
                        );
                      },
                      child: const Text("Log in"),
                    ),
                  ],
                ),
              ),
            );
          }
          final name = user['name']?.toString() ?? 'User';
          final rows = <MapEntry<String, String>>[
            for (final key in ['email', 'phone'])
              if ((user[key]?.toString() ?? '').isNotEmpty)
                MapEntry(
                  key[0].toUpperCase() + key.substring(1),
                  user[key].toString(),
                ),
          ];
          return ListView(
            padding: const EdgeInsets.all(defaultPadding),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFEAF4FC),
                    child: Text(
                      name.isEmpty ? "?" : name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: defaultPadding),
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: defaultPadding),
              if (rows.isEmpty)
                Text(
                  "No contact details saved for this account.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              for (final row in rows)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.key,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(color: blackColor60),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.value,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Divider(height: defaultPadding * 1.5),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
