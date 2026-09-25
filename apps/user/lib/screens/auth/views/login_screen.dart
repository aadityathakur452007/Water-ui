import 'package:flutter/material.dart';
import 'package:shop/config/app_config.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/auth/views/password_recovery_screen.dart';
import 'package:shop/services/api_client.dart';
import 'package:shop/services/auth_service.dart';

import 'components/login_form.dart';

/// Unified sign-in: User / Vendor toggle on one interface.
/// Demo mode offers one-tap seed logins; live mode hits the API.
/// Vendor accounts are provisioned (seed/admin) — never self-registered.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _isVendor = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_identifier, _password]) {
      c.addListener(() {
        if (_error != null && mounted) setState(() => _error = null);
      });
    }
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fail(String message) {
    setState(() => _error = message);
    // Dismissible error toast; the inline text below stays for a11y.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await const AuthService().login(
        identifier: _identifier.text,
        password: _password.text,
        role: _isVendor ? 'vendor' : 'user',
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        (user['role']?.toString() ?? 'user') == 'vendor'
            ? vendorHomeScreenRoute
            : entryPointScreenRoute,
        (_) => false,
      );
    } on AppException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not log in. Check connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _demoLogin(bool vendor) async {
    setState(() {
      _busy = true;
      _error = null;
      _isVendor = vendor;
    });
    try {
      await const AuthService().login(
        identifier: vendor
            ? AppConfig.demoVendorEmail
            : AppConfig.demoUserEmail,
        password: vendor
            ? AppConfig.demoVendorPassword
            : AppConfig.demoUserPassword,
        role: vendor ? 'vendor' : 'user',
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        vendor ? vendorHomeScreenRoute : entryPointScreenRoute,
        (_) => false,
      );
    } on AppException catch (e) {
      _fail(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.asset(
              "assets/images/login_dark.png",
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome back!",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: defaultPadding / 2),
                  const Text(
                    "Log in to order pure drinking water delivered to your home.",
                  ),
                  const SizedBox(height: defaultPadding),
                  Center(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                            value: false, label: Text('User sign in')),
                        ButtonSegment(
                            value: true, label: Text('Vendor sign in')),
                      ],
                      selected: {_isVendor},
                      onSelectionChanged: (s) =>
                          setState(() => _isVendor = s.first),
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  LogInForm(
                    formKey: _formKey,
                    identifierController: _identifier,
                    passwordController: _password,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: errorColor),
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      child: const Text("Forgot password"),
                      onPressed: () {
                        // Direct push (not via router) so the typed
                        // identifier pre-fills recovery without a
                        // router-contract change.
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PasswordRecoveryScreen(
                              initialEmail: _identifier.text.trim(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height: size.height > 700
                        ? size.height * 0.1
                        : defaultPadding,
                  ),
                  ElevatedButton(
                    onPressed: _busy ? null : _login,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isVendor ? "Vendor log in" : "Log in"),
                  ),
                  if (AppConfig.demoMode) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed:
                          _busy ? null : () => _demoLogin(false),
                      child: const Text("Try as Demo User"),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _demoLogin(true),
                      child: const Text("Try as Demo Vendor"),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        "Demo mode — no server needed.",
                        style:
                            TextStyle(color: blackColor60, fontSize: 12),
                      ),
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, signUpScreenRoute);
                        },
                        child: const Text("Sign up"),
                      )
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
