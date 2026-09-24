import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shop/screens/auth/views/components/sign_up_form.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/services/api_client.dart';
import 'package:shop/services/session_store.dart';

import '../../../constants.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      setState(() => _error = 'Please accept the Terms to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ApiClient();
      final res = await api.post('/api/auth/register', body: {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
      });
      final map = Map<String, dynamic>.from(res as Map);
      final token = map['token']?.toString() ?? '';
      final user = map['user'] is Map
          ? Map<String, dynamic>.from(map['user'] as Map)
          : <String, dynamic>{};
      if (token.isEmpty) throw const AppException('UNKNOWN', 'No token');
      await const SessionStore().saveSession(token: token, user: user);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        entryPointScreenRoute,
        (_) => false,
      );
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not sign up. Check connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.asset(
              "assets/images/signUp_dark.png",
              height: MediaQuery.of(context).size.height * 0.35,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Let’s get you hydrated!",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: defaultPadding / 2),
                  const Text(
                    "Enter your details to order 20L cans and bottles near you.",
                  ),
                  const SizedBox(height: defaultPadding),
                  SignUpForm(
                    formKey: _formKey,
                    nameController: _name,
                    phoneController: _phone,
                    emailController: _email,
                    passwordController: _password,
                  ),
                  const SizedBox(height: defaultPadding),
                  Row(
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: (value) =>
                            setState(() => _agreed = value ?? false),
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: "I agree with the",
                            children: [
                              TextSpan(
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.pushNamed(
                                        context, termsOfServicesScreenRoute);
                                  },
                                text: " Terms of service ",
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const TextSpan(
                                text: "& privacy policy.",
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: errorColor),
                    ),
                  ],
                  const SizedBox(height: defaultPadding * 2),
                  ElevatedButton(
                    onPressed: _busy ? null : _signUp,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Continue"),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Do you have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, logInScreenRoute);
                        },
                        child: const Text("Log in"),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      "Vendor? Accounts are created by your distributor — use Vendor sign in to log in.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: blackColor60, fontSize: 12),
                    ),
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
