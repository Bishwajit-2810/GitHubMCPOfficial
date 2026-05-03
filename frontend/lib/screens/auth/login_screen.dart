import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/responsive.dart';

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
    final p = Responsive.pagePadding(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: p, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo + animation
                  _buildHero(context),
                  const SizedBox(height: 40),

                  // Error banner
                  if (auth.error != null)
                    _ErrorBanner(message: auth.error!),

                  // Google sign-in
                  _SocialButton(
                    icon: Icons.g_mobiledata_rounded,
                    label: 'Continue with Google',
                    onPressed: auth.isLoading
                        ? null
                        : () => context.read<AuthNotifier>().signInWithGoogle(),
                  )
                      .animate()
                      .fadeIn(delay: 350.ms, duration: 300.ms)
                      .slideY(begin: 0.3),
                  const SizedBox(height: 20),

                  // Divider
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('or',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    const Expanded(child: Divider()),
                  ])
                      .animate()
                      .fadeIn(delay: 400.ms),
                  const SizedBox(height: 20),

                  // Email form
                  if (!_showEmail)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: const Text('Continue with Email'),
                      onPressed: () => setState(() => _showEmail = true),
                    )
                        .animate()
                        .fadeIn(delay: 450.ms, duration: 300.ms)
                        .slideY(begin: 0.3)
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
                    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.2),

                  if (auth.isLoading) ...[
                    const SizedBox(height: 24),
                    const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppTheme.accent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Column(
      children: [
        // Lottie loading animation used as hero visual
        _LottieHero().animate().fadeIn(duration: 600.ms),
        const SizedBox(height: 20),
        Text(
          'GitHub MCP',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
        )
            .animate()
            .fadeIn(delay: 150.ms, duration: 400.ms)
            .slideY(begin: 0.2),
        const SizedBox(height: 6),
        Text(
          'Manage repos, projects and codebases with AI',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        )
            .animate()
            .fadeIn(delay: 220.ms, duration: 400.ms),
      ],
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppTheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.2);
  }
}

// ── Social button ─────────────────────────────────────────────────────────────

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
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(
          color: onPressed == null ? AppTheme.textMuted : AppTheme.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

// ── Email form ────────────────────────────────────────────────────────────────

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
              prefixIcon: Icon(Icons.email_outlined, size: 18),
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
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                    size: 18),
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

// ── Lottie hero ───────────────────────────────────────────────────────────────

class _LottieHero extends StatelessWidget {
  const _LottieHero();

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'assets/lottie/loading.json',
      width: 80,
      height: 80,
      fit: BoxFit.contain,
      errorBuilder: (ctx, err, st) => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppTheme.greenGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.hub_rounded, size: 32, color: Colors.white),
      ),
    );
  }
}
