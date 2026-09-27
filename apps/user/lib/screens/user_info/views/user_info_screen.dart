import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/services/session_store.dart';

/// Account details from the signed-in session ([SessionStore]).
/// The backend exposes no profile endpoint, so this screen shows
/// exactly what the session holds — nothing invented. Name and phone
/// are editable here and persist on this device via shared_preferences.
class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  Future<Map<String, dynamic>?>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      setState(() => _future = const SessionStore().readUser());

  Future<void> _openEdit(Map<String, dynamic> user) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(
        text: user['name']?.toString() ?? '');
    final phone = TextEditingController(
        text: user['phone']?.toString() ?? '');
    bool saving = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: defaultPadding * 1.5,
            right: defaultPadding * 1.5,
            top: defaultPadding * 1.5,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom +
                defaultPadding * 1.5,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Edit profile",
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleSmall!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: defaultPadding),
                TextFormField(
                  controller: name,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(labelText: "Name"),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? "Name is required"
                      : null,
                ),
                const SizedBox(height: defaultPadding / 2),
                TextFormField(
                  controller: phone,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: "Phone"),
                  validator: (v) {
                    final digits =
                        v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                    if (digits.isEmpty) return "Phone is required";
                    if (digits.length < 7) {
                      return "Enter a valid phone number";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: defaultPadding),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }
                            setSheet(() => saving = true);
                            await const SessionStore().updateUserFields({
                              'name': name.text.trim(),
                              'phone': phone.text.trim(),
                            });
                            if (mounted) Navigator.pop(context);
                            _reload();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("Profile updated.")),
                              );
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Save"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    name.dispose();
    phone.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          FutureBuilder<Map<String, dynamic>?>(
            future: _future,
            builder: (context, snap) {
              final user = snap.data;
              if (user == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: "Edit profile",
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _openEdit(user),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
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
                  OutlinedButton(
                    onPressed: () => _openEdit(user),
                    child: const Text("Edit"),
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
