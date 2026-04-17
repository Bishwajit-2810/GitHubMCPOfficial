import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showEmail = false;
  bool _isSignUp = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>().state;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.hub_rounded, size: 56, color: Color(0xFF238636)),
              const SizedBox(height: 16),
              Text(
                'GitHub MCP',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 26,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 40),

              if (auth.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.error),
                  ),
                  child: Text(
                    auth.error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13),
                  ),
                ),

              _SocialButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Continue with Google',
                onPressed: auth.isLoading
                    ? null
                    : () => context.read<AuthNotifier>().signInWithGoogle(),
              ),
              const SizedBox(height: 12),

              _SocialButton(
                icon: Icons.code,
                label: 'Continue with GitHub',
                onPressed: auth.isLoading
                    ? null
                    : () => context.read<AuthNotifier>().signInWithGithub(),
              ),
              const SizedBox(height: 20),

              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 20),

              if (!_showEmail)
                OutlinedButton.icon(
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Continue with Email'),
                  onPressed: () => setState(() => _showEmail = true),
                )
              else
                _EmailForm(
                  formKey: _formKey,
                  emailCtrl: _emailCtrl,
                  passCtrl: _passCtrl,
                  obscurePass: _obscurePass,
                  isSignUp: _isSignUp,
                  isLoading: auth.isLoading,
                  onToggleObscure: () =>
                      setState(() => _obscurePass = !_obscurePass),
                  onToggleSignUp: () =>
                      setState(() => _isSignUp = !_isSignUp),
                  onSubmit: () {
                    if (!_formKey.currentState!.validate()) return;
                    final notifier = context.read<AuthNotifier>();
                    if (_isSignUp) {
                      notifier.createEmailAccount(
                          _emailCtrl.text.trim(), _passCtrl.text);
                    } else {
                      notifier.signInWithEmail(
                          _emailCtrl.text.trim(), _passCtrl.text);
                    }
                  },
                ),

              if (auth.isLoading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _SocialButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 22),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

class _EmailForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final bool isSignUp;
  final bool isLoading;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleSignUp;
  final VoidCallback onSubmit;

  const _EmailForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscurePass,
    required this.isSignUp,
    required this.isLoading,
    required this.onToggleObscure,
    required this.onToggleSignUp,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                v == null || !v.contains('@') ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passCtrl,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                    obscurePass ? Icons.visibility : Icons.visibility_off),
                onPressed: onToggleObscure,
              ),
            ),
            obscureText: obscurePass,
            validator: (v) =>
                v == null || v.length < 6 ? 'At least 6 characters' : null,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            child: Text(isSignUp ? 'Create Account' : 'Sign In'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onToggleSignUp,
            child: Text(
              isSignUp
                  ? 'Already have an account? Sign in'
                  : "Don't have an account? Create one",
            ),
          ),
        ],
      ),
    );
  }
}
