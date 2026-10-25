import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/colors/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../widgets/lumora_logo.dart';
import '../widgets/recovery_key_dialog.dart';
import '../widgets/user_avatar.dart';

enum _Mode { choose, signIn, signUp, forgot }

/// Offline account chooser, sign in, sign up and recovery-key password reset.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth, required this.onAuthenticated});
  final AuthService auth;
  final void Function(AuthResult result) onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _recovery = TextEditingController();
  _Mode _mode = _Mode.signUp;
  List<LocalUser> _accounts = const [];
  bool _loaded = false, _busy = false, _hide = true;
  String? _error;
  Timer? _lockTimer;
  int _lockSeconds = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await widget.auth.accounts();
    final last = await widget.auth.lastEmail();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _loaded = true;
      if (accounts.isEmpty) {
        _mode = _Mode.signUp;
      } else if (accounts.length == 1 || last != null && accounts.any((a) => a.email == last)) {
        _email.text = last ?? accounts.first.email;
        _mode = _Mode.signIn;
      } else {
        _mode = _Mode.choose;
      }
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    for (final c in [_name, _email, _password, _confirm, _recovery]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(_Mode m, {String? email}) => setState(() {
        _mode = m;
        _error = null;
        _password.clear();
        _confirm.clear();
        _recovery.clear();
        if (email != null) _email.text = email;
      });

  void _startLock(Duration d) {
    _lockTimer?.cancel();
    _lockSeconds = d.inSeconds + 1;
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        _lockSeconds--;
        if (_lockSeconds <= 0) {
          t.cancel();
          _error = null;
        }
      });
    });
  }

  Future<void> _submit() async {
    if (_busy || _lockSeconds > 0 || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final AuthResult r;
      switch (_mode) {
        case _Mode.signUp:
          r = await widget.auth.signUp(name: _name.text, email: _email.text, password: _password.text);
        case _Mode.forgot:
          r = await widget.auth.resetPassword(
              email: _email.text, recoveryKey: _recovery.text, newPassword: _password.text);
        default:
          r = await widget.auth.signIn(email: _email.text, password: _password.text);
      }
      if (r.recoveryKey != null && mounted) {
        await showRecoveryKey(context, r.recoveryKey!, reset: _mode != _Mode.signUp);
      }
      widget.onAuthenticated(r);
    } on LockedException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
        _startLock(e.remaining);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(labelText: label, prefixIcon: Icon(icon), suffixIcon: suffix);

  Widget _passwordField(String label, {TextInputAction? action}) => TextFormField(
        controller: _password,
        obscureText: _hide,
        textInputAction: action ?? TextInputAction.done,
        onFieldSubmitted: (_) => action == null ? _submit() : null,
        autofillHints: [_mode == _Mode.signIn ? AutofillHints.password : AutofillHints.newPassword],
        decoration: _dec(label, Icons.lock_outline,
            suffix: IconButton(
              tooltip: _hide ? 'Show password' : 'Hide password',
              icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _hide = !_hide),
            )),
        validator: (v) => _mode == _Mode.signIn
            ? ((v ?? '').isEmpty ? 'Enter your password' : null)
            : AuthService.validatePassword(v ?? ''),
      );

  Widget _confirmField() => TextFormField(
        controller: _confirm,
        obscureText: _hide,
        onFieldSubmitted: (_) => _submit(),
        decoration: _dec('Confirm password', Icons.lock_outline),
        validator: (v) => v != _password.text ? 'Passwords do not match' : null,
      );

  Widget _emailField({bool readOnly = false}) => TextFormField(
        controller: _email,
        readOnly: readOnly,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        decoration: _dec('Email', Icons.mail_outline),
        validator: (v) => AuthService.validateEmail(v ?? ''),
      );

  Widget _primary(String label) => FilledButton(
        onPressed: _busy || _lockSeconds > 0 ? null : _submit,
        child: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(_lockSeconds > 0 ? 'Locked — try again in ${_lockSeconds}s' : label),
      );

  Widget _link(String text, VoidCallback onTap) => TextButton(onPressed: onTap, child: Text(text));

  Widget _errorText() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w600)),
        );

  Widget _chooser() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final a in _accounts)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: UserAvatar(a),
              title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(a.email),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _go(_Mode.signIn, email: a.email),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: () => _go(_Mode.signIn, email: ''),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Sign in with another email')),
        _link('Create a new account', () => _go(_Mode.signUp, email: '')),
      ]);

  List<Widget> _formFields() {
    switch (_mode) {
      case _Mode.signUp:
        return [
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: _dec('Name (optional)', Icons.person_outline),
          ),
          const SizedBox(height: 12),
          _emailField(),
          const SizedBox(height: 12),
          _passwordField('Password (6+ characters)', action: TextInputAction.next),
          const SizedBox(height: 12),
          _confirmField(),
          _errorText(),
          const SizedBox(height: 16),
          _primary('Create account'),
          if (_accounts.isNotEmpty) _link('Back to sign in', () => _go(_Mode.choose)),
          if (_accounts.isEmpty) _link('Already have an account? Sign in', () => _go(_Mode.signIn)),
        ];
      case _Mode.forgot:
        return [
          const Text('Enter the recovery key you saved when you created the account.',
              style: TextStyle(color: Palette.muted)),
          const SizedBox(height: 12),
          _emailField(),
          const SizedBox(height: 12),
          TextFormField(
            controller: _recovery,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            decoration: _dec('Recovery key', Icons.key_outlined),
            validator: (v) => normalizeRecoveryKey(v ?? '').length < 20 ? 'Enter your full recovery key' : null,
          ),
          const SizedBox(height: 12),
          _passwordField('New password (6+ characters)', action: TextInputAction.next),
          const SizedBox(height: 12),
          _confirmField(),
          _errorText(),
          const SizedBox(height: 16),
          _primary('Reset password'),
          _link('Back to sign in', () => _go(_Mode.signIn)),
        ];
      default:
        final known = _accounts.where((a) => a.email == AuthService.normalizeEmail(_email.text)).firstOrNull;
        return [
          if (known != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                UserAvatar(known, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(known.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(known.email, style: const TextStyle(color: Palette.muted)),
                ])),
              ]),
            ),
          if (known == null) ...[_emailField(), const SizedBox(height: 12)],
          _passwordField('Password'),
          _errorText(),
          const SizedBox(height: 16),
          _primary('Sign in'),
          _link('Forgot password?', () => _go(_Mode.forgot)),
          if (_accounts.length > 1) _link('Switch account', () => _go(_Mode.choose)),
          _link('Create a new account', () => _go(_Mode.signUp, email: '')),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _Mode.choose => 'Choose an account',
      _Mode.signIn => 'Welcome back',
      _Mode.signUp => 'Create your account',
      _Mode.forgot => 'Reset your password',
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: !_loaded
                      ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
                      : Form(
                          key: _form,
                          child: AutofillGroup(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Center(child: LumoraLogo(size: 64)),
                                  const SizedBox(height: 14),
                                  Text(title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  const Text('Stored and encrypted on this device only.',
                                      textAlign: TextAlign.center, style: TextStyle(color: Palette.muted)),
                                  const SizedBox(height: 18),
                                  if (_mode == _Mode.choose) _chooser() else ..._formFields(),
                                ]),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
