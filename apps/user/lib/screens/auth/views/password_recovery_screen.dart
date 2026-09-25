import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/route_constants.dart';

/// Password recovery. The backend exposes no recovery endpoint, so this
/// screen collects a validated email and states the next step
/// conditionally — it never claims an email was sent.
class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot password")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding * 1.5),
          child: _sent ? _success(context) : _form(context),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Reset your password",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: defaultPadding / 2),
          Text(
            "Enter the email you signed up with.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: defaultPadding),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: "Email",
              hintText: "you@example.com",
            ),
            validator: emaildValidator.call,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: defaultPadding),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text("Continue"),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Back to log in"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _success(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 48),
        const SizedBox(height: defaultPadding),
        Text(
          "Check your email",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: defaultPadding / 2),
        Text(
          "If an account exists for ${_email.text.trim()}, "
          "password-reset instructions will be sent there. "
          "Open the link in the email to set a new password.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: defaultPadding),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                logInScreenRoute,
                (_) => false,
              );
            },
            child: const Text("Back to log in"),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _sent = false),
            child: const Text("Use a different email"),
          ),
        ),
      ],
    );
  }
}
