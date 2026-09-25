import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets.dart';
import '../auth_controller.dart';

/// Phone sign-in, the same two steps as the existing player app: mobile
/// number, then the 6-digit code sent on WhatsApp. No passwords, no role
/// picker; everyone signs in as themselves.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _mobile = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _mobile.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  String get _digits => _mobile.text.replaceAll(RegExp(r'\D'), '');
  bool get _mobileValid => RegExp(r'^[6-9]\d{9}$').hasMatch(_digits);

  Future<void> _sendCode() async {
    // Ignore a second tap while the first request is in flight.
    if (_busy || !_mobileValid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sent = await ref.read(authControllerProvider.notifier).sendOtp(_digits);
      if (!mounted) return;
      // The code field is built with autofocus, so the keyboard opens on it.
      setState(() => _codeSent = true);
      _startResendTimer(sent.resendAfter.inSeconds);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || _code.text.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On success the router moves on to profile setup or the app.
      await ref.read(authControllerProvider.notifier).verifyOtp(_digits, _code.text);
      TextInput.finishAutofillContext();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
        _code.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startResendTimer(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendIn <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn--);
    });
  }

  void _changeNumber() {
    _timer?.cancel();
    setState(() {
      _codeSent = false;
      _code.clear();
      _error = null;
      _resendIn = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SkorxSpace.xl),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: SkorxSpace.xxl),
                const Align(alignment: Alignment.centerLeft, child: SkorxLogo(height: 56)),
                const SizedBox(height: SkorxSpace.xs),
                Text('Score. Play. Organize.', style: text.titleMedium?.copyWith(color: colors.textMuted)),
                const SizedBox(height: SkorxSpace.xxl * 2),
                Text(_codeSent ? 'Enter the code' : 'Sign in with your mobile', style: text.headlineMedium),
                const SizedBox(height: SkorxSpace.sm),
                Text(
                  _codeSent
                      // Non-breaking space keeps "+91" and the number on one line.
                      ? 'We sent a 6-digit code on WhatsApp to +91 $_digits.'
                      : 'We will send a 6-digit code on WhatsApp.',
                  style: text.bodyLarge?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: SkorxSpace.xl),
                if (!_codeSent)
                  TextField(
                    key: const Key('mobileField'),
                    controller: _mobile,
                    enabled: !_busy,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumberNational],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1),
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      prefixText: '+91  ',
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _sendCode(),
                  )
                else
                  TextField(
                    key: const Key('codeField'),
                    controller: _code,
                    focusNode: _codeFocus,
                    // Read-only rather than disabled while busy: a disabled
                    // field cannot hold focus, so the keyboard would close.
                    readOnly: _busy,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 12,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    // No placeholder: the centred cursor sat on top of it.
                    decoration: const InputDecoration(labelText: '6-digit code'),
                    onChanged: (value) {
                      setState(() => _error = null);
                      if (value.length == 6) _verify();
                    },
                  ),
                if (_error != null) ...[
                  const SizedBox(height: SkorxSpace.md),
                  Semantics(
                    liveRegion: true,
                    child: Text(_error!, key: const Key('signInError'), style: TextStyle(color: colors.live)),
                  ),
                ],
                const SizedBox(height: SkorxSpace.xl),
                FilledButton(
                  key: const Key('signInPrimary'),
                  onPressed: _busy
                      ? null
                      : _codeSent
                          ? (_code.text.length == 6 ? _verify : null)
                          : (_mobileValid ? _sendCode : null),
                  child: _busy
                      ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text(_codeSent ? 'Verify' : 'Continue'),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: SkorxSpace.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(onPressed: _busy ? null : _changeNumber, child: const Text('Change number')),
                      TextButton(
                        onPressed: _busy || _resendIn > 0 ? null : _sendCode,
                        child: Text(_resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend code'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
