import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/repositories/address_repository.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/services/api_client.dart';
import 'package:shop/services/auth_service.dart';

/// Saved delivery addresses. Live data via [AddressRepository]
/// (`GET /api/addresses`); new addresses via the bottom sheet
/// (`POST /api/addresses`). Demo mode serves the bundled address.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final _repo = const AddressRepository();
  Future<List<Address>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchAddresses();
  }

  void _reload() => setState(() => _future = _repo.fetchAddresses());

  Future<void> _goLogin() async {
    await const AuthService().handleUnauthorized();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        logInScreenRoute,
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Addresses")),
      body: FutureBuilder<List<Address>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: defaultPadding / 2),
                  Text("Loading addresses"),
                ],
              ),
            );
          }
          if (snap.hasError) {
            final err = snap.error;
            final expired = err is AppException &&
                (err.code == 'UNAUTHENTICATED' || err.status == 401);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding * 1.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      expired
                          ? "Session expired."
                          : "Could not load addresses.",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expired
                          ? "Please log in again."
                          : "Check your connection and try again.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: defaultPadding),
                    ElevatedButton(
                      onPressed: expired ? _goLogin : _reload,
                      child: Text(expired ? "Log in" : "Retry"),
                    ),
                  ],
                ),
              ),
            );
          }
          final addresses = snap.data ?? const <Address>[];
          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding * 1.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 48),
                    const SizedBox(height: defaultPadding / 2),
                    Text(
                      "No saved addresses",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Add your first delivery address.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: defaultPadding),
                    ElevatedButton(
                      onPressed: () => _openAddSheet(),
                      child: const Text("Add address"),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(defaultPadding),
            itemCount: addresses.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: defaultPadding / 2),
            itemBuilder: (context, index) {
              final a = addresses[index];
              return Container(
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: const BorderRadius.all(
                      Radius.circular(defaultBorderRadious)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(a.label),
                  subtitle: Text("${a.line}\n${a.city}"),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: ElevatedButton(
            onPressed: () => _openAddSheet(),
            child: const Text("Add address"),
          ),
        ),
      ),
    );
  }

  void _openAddSheet() {
    final formKey = GlobalKey<FormState>();
    final label = TextEditingController();
    final line = TextEditingController();
    final city = TextEditingController();
    bool saving = false;
    showModalBottomSheet(
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
                  "Add address",
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleSmall!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: defaultPadding),
                TextFormField(
                  controller: label,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(labelText: "Label (Home, Work)"),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? "Label is required"
                      : null,
                ),
                const SizedBox(height: defaultPadding / 2),
                TextFormField(
                  controller: line,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(labelText: "Street address"),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? "Street address is required"
                      : null,
                ),
                const SizedBox(height: defaultPadding / 2),
                TextFormField(
                  controller: city,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: "City"),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? "City is required"
                      : null,
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
                            try {
                              await _repo.createAddress(
                                label: label.text,
                                line: line.text,
                                city: city.text,
                              );
                              if (mounted) Navigator.pop(context);
                              _reload();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Address saved.")),
                                );
                              }
                            } on AppException catch (e) {
                              if (e.code == 'UNAUTHENTICATED' ||
                                  e.status == 401) {
                                if (mounted) Navigator.pop(context);
                                await _goLogin();
                                return;
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.message)),
                                );
                              }
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Could not save. Try again.")),
                                );
                              }
                            } finally {
                              setSheet(() => saving = false);
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
                        : const Text("Save address"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      label.dispose();
      line.dispose();
      city.dispose();
    });
  }
}
