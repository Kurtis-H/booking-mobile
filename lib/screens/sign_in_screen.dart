import 'package:material_ui/material_ui.dart';

import '../session.dart';
import '../theme.dart';

/// Returns true (via Navigator.pop) when sign-in succeeds.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _key = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _attempt(String value) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.of(context).signIn(value);
      if (mounted) Navigator.of(context).pop(true);
    } on SignInException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sign in')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.confirmation_number_outlined, size: 40, color: Palette.accent),
            const SizedBox(height: 12),
            Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text(
              'Sign in with your API key to buy seats and see your orders.',
              style: TextStyle(color: Palette.muted),
            ),
            const SizedBox(height: 20),
            Semantics(
              identifier: 'api-key-field',
              child: TextField(
                key: const ValueKey('api-key-field'),
                controller: _key,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'API key',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
                onSubmitted: _busy ? null : _attempt,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : () => _attempt(_key.text),
              child: Text(_busy ? 'Signing in…' : 'Sign in'),
            ),
            if (Session.demoKey case final demoKey?) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Palette.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'This is a demo of the booking API. You can sign in as a test buyer.'),
                    TextButton(
                      onPressed: _busy ? null : () => _attempt(demoKey),
                      child: const Text('Use the demo account'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
}
