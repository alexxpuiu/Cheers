import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/glass.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_busy) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Add a name so friends know who you are.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider).signInAnonymouslyAs(name);
      if (!mounted) return;
      // Clear the spinner *before* navigating. If for any reason GoRouter's
      // redirect keeps us on `/login` (e.g. auth state stream lag), the
      // button must not stay stuck on "Signing in…".
      setState(() => _busy = false);
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendly(e);
        _busy = false;
      });
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('anonymous_provider_disabled') ||
        s.contains('Anonymous sign-ins are disabled')) {
      return 'Anonymous sign-in is disabled in Supabase → Auth → Providers.\n'
          'Turn it on and reload.';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text('Cheers',
                      style: Theme.of(context).textTheme.displayLarge)
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.15, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),
              Text(
                'Plans that feel like a night out.\n'
                'Pick a name — friends will see it on your shared trips.',
                style: Theme.of(context).textTheme.bodyMedium,
              ).animate().fadeIn(delay: 120.ms),
              const SizedBox(height: 32),
              GlassContainer(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        cursorColor: AppColors.accent,
                        onSubmitted: (_) => _continue(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Your name',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: AppColors.catDining,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: GlassButton(
                  label: _busy ? 'Signing in…' : 'Continue',
                  icon: _busy ? null : Icons.arrow_forward_rounded,
                  primary: true,
                  expanded: true,
                  onTap: _busy ? null : _continue,
                ),
              ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.15),
              const SizedBox(height: 12),
              Text(
                'No password, no email. Anonymous session — you can convert '
                'to a real account later.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
