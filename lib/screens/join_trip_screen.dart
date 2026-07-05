import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/trip_providers.dart';
import '../services/trips_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/glass.dart';

class JoinTripScreen extends ConsumerStatefulWidget {
  const JoinTripScreen({super.key});

  @override
  ConsumerState<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends ConsumerState<JoinTripScreen> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final trip = await ref
          .read(tripStoreProvider)
          .joinWithCode(_codeCtrl.text);
      if (!mounted) return;
      context.go('/trip/${trip.id}/map');
    } on TripJoinException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
              ),
              const SizedBox(height: 28),
              Text('Join a\ngroup trip.',
                      style: Theme.of(context).textTheme.displayLarge)
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.15, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),
              Text(
                'Paste the code your friend sent you. Codes are 6 characters, '
                'like H7K2Q9.',
                style: Theme.of(context).textTheme.bodyMedium,
              ).animate().fadeIn(delay: 120.ms),
              const SizedBox(height: 32),
              GlassContainer(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.key_rounded,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 8,
                        cursorColor: AppColors.accent,
                        onSubmitted: (_) => _submit(),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]')),
                          _UppercaseFormatter(),
                        ],
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                        decoration: InputDecoration(
                          hintText: 'ABC123',
                          counterText: '',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
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
                  label: _busy ? 'Joining…' : 'Join trip',
                  icon: _busy ? null : Icons.arrow_forward_rounded,
                  primary: true,
                  expanded: true,
                  onTap: _busy ? null : _submit,
                ),
              ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.15),
            ],
          ),
        ),
      ),
    );
  }
}

class _UppercaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 100,
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Icon(icon, size: 20, color: AppColors.textPrimary),
    );
  }
}
