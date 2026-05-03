import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';

// ── Section card ──────────────────────────────────────────────────────────────

class FormSectionCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const FormSectionCard({
    super.key,
    this.title,
    required this.children,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                title!.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info banner ───────────────────────────────────────────────────────────────

class FormInfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final List<Color> colors;

  const FormInfoBanner({
    super.key,
    required this.text,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors[0].withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors[0].withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors[0]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors[0].withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class FormErrorBanner extends StatelessWidget {
  final String message;

  const FormErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.2);
  }
}

// ── Success card ──────────────────────────────────────────────────────────────

class FormSuccessCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? details;
  final VoidCallback onBack;
  final VoidCallback? onCreateAnother;
  final String createAnotherLabel;
  final List<Color> gradientColors;

  const FormSuccessCard({
    super.key,
    required this.title,
    this.subtitle,
    this.details,
    required this.onBack,
    this.onCreateAnother,
    this.createAnotherLabel = 'Create another',
    this.gradientColors = AppTheme.greenGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 36, color: Colors.white),
          )
              .animate()
              .scale(duration: 400.ms, curve: Curves.elasticOut),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ).animate().fadeIn(delay: 120.ms),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13),
          ).animate().fadeIn(delay: 180.ms),
        ],
        if (details != null && details!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: details!,
            ),
          ).animate().fadeIn(delay: 240.ms),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Back'),
              ),
            ),
            if (onCreateAnother != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onCreateAnother,
                  child: Text(createAnotherLabel),
                ),
              ),
            ],
          ],
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }
}

// ── Detail row (used inside success cards) ────────────────────────────────────

class SuccessDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const SuccessDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gradient submit button ─────────────────────────────────────────────────────

class GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;
  final List<Color> colors;

  const GradientButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isLoading,
    this.onPressed,
    this.colors = AppTheme.greenGradient,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLoading
              ? [AppTheme.surfaceHigh, AppTheme.surfaceHigh]
              : colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: isLoading ? AppTheme.textMuted : Colors.white,
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }
}
