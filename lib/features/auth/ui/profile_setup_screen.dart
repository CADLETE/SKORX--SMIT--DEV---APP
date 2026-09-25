import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/api/api_exception.dart';
import '../auth_controller.dart';
import '../data/auth_repository.dart';

/// Asked once, after a phone number's first sign-in: the details the old
/// app collected. Gender and date of birth decide which men's, women's and
/// mixed categories a player can enter.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  String? _gender;
  DateTime? _dateOfBirth;
  bool _busy = false;
  String? _error;

  static const _genders = {'male': 'Male', 'female': 'Female', 'other': 'Other'};

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().length >= 2;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 4),
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    if (_busy || !_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).completeProfile(
            ProfileUpdate(
              name: _name.text.trim(),
              city: _city.text.trim().isEmpty ? null : _city.text.trim(),
              gender: _gender,
              dateOfBirth: _dateOfBirth,
            ),
          );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    final dob = _dateOfBirth;

    return Scaffold(
      appBar: AppBar(title: const Text('Set up your profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SkorxSpace.xl),
          children: [
            Text(
              'This is how you appear in scores, draws and rankings.',
              style: TextStyle(color: colors.textMuted),
            ),
            const SizedBox(height: SkorxSpace.xl),
            TextField(
              key: const Key('nameField'),
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Full name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SkorxSpace.lg),
            TextField(
              controller: _city,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.addressCity],
              decoration: const InputDecoration(labelText: 'City (optional)'),
            ),
            const SizedBox(height: SkorxSpace.xl),
            Text('Gender (optional)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: SkorxSpace.sm),
            SegmentedButton<String>(
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: [
                for (final entry in _genders.entries) ButtonSegment(value: entry.key, label: Text(entry.value)),
              ],
              selected: {?_gender},
              onSelectionChanged: _busy ? null : (value) => setState(() => _gender = value.firstOrNull),
            ),
            const SizedBox(height: SkorxSpace.xl),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickDate,
              icon: const Icon(Icons.cake_outlined),
              label: Text(
                dob == null
                    ? 'Date of birth (optional)'
                    : '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: SkorxSpace.lg),
              Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: colors.live))),
            ],
            const SizedBox(height: SkorxSpace.xxl),
            FilledButton(
              key: const Key('saveProfile'),
              onPressed: _busy || !_valid ? null : _save,
              child: _busy
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text("Let's play"),
            ),
          ],
        ),
      ),
    );
  }
}
