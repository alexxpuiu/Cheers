import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/mock_pois.dart';
import '../models/trip.dart';
import '../providers/trip_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/glass.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _nameCtrl = TextEditingController(text: 'Long weekend');
  final _cityCtrl = TextEditingController(text: MockPois.demoCity);
  TripMode _mode = TripMode.solo;
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day + 7);
    _end = _start.add(const Duration(days: 3));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _start, end: _end),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              onPrimary: AppColors.bgDeep,
              surface: Color(0xFF231038),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1B0E30),
          ),
          child: child!,
        );
      },
    );
    if (range != null) setState(() {
      _start = range.start;
      _end = range.end;
    });
  }

  void _create() {
    final trip = ref.read(tripStoreProvider).create(
          name: _nameCtrl.text.trim().isEmpty ? 'New trip' : _nameCtrl.text.trim(),
          city: _cityCtrl.text.trim().isEmpty ? MockPois.demoCity : _cityCtrl.text.trim(),
          mode: _mode,
          start: _start,
          end: _end,
        );
    context.go('/trip/${trip.id}/map');
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE, MMM d');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const Spacer(),
                  Text('Step 1 of 1',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 28),
              Text('Start a\nnew trip.',
                      style: Theme.of(context).textTheme.displayLarge)
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.15, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),
              Text(
                'Give it a name, pick a city, choose the vibe.',
                style: Theme.of(context).textTheme.bodyMedium,
              ).animate().fadeIn(delay: 120.ms),
              const SizedBox(height: 28),
              _Field(
                label: 'Trip name',
                controller: _nameCtrl,
                icon: Icons.edit_rounded,
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
              const SizedBox(height: 14),
              _Field(
                label: 'City',
                controller: _cityCtrl,
                icon: Icons.place_rounded,
              ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.1),
              const SizedBox(height: 14),
              GlassContainer(
                onTap: _pickDates,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dates',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              )),
                          const SizedBox(height: 2),
                          Text(
                            '${dateFmt.format(_start)}  →  ${dateFmt.format(_end)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                  ],
                ),
              ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.1),
              const SizedBox(height: 24),
              Text('Who\'s going?',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ModeCard(
                      icon: Icons.person_rounded,
                      title: 'Solo',
                      subtitle: 'Just for you.',
                      selected: _mode == TripMode.solo,
                      onTap: () => setState(() => _mode = TripMode.solo),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeCard(
                      icon: Icons.groups_2_rounded,
                      title: 'Group',
                      subtitle: 'Plan with friends.',
                      selected: _mode == TripMode.group,
                      onTap: () => setState(() => _mode = TripMode.group),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 380.ms).slideY(begin: 0.1),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: GlassButton(
                  label: 'Create trip',
                  icon: Icons.arrow_forward_rounded,
                  primary: true,
                  expanded: true,
                  onTap: _create,
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.15),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(
      {required this.label, required this.controller, required this.icon});
  final String label;
  final TextEditingController controller;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              cursorColor: AppColors.accent,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                floatingLabelStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: GlassContainer(
        radius: 22,
        onTap: onTap,
        opacity: selected ? 0.22 : 0.10,
        borderOpacity: selected ? 0.6 : 0.25,
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x66FFB86B),
                  Color(0x33FF6B8A),
                ],
              )
            : null,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 24,
                color: selected ? AppColors.accent : AppColors.textPrimary),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
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
