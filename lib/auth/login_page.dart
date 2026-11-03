import 'package:flutter/material.dart';

import 'auth_service.dart';
import '../theme/beacon_theme.dart';
import '../widgets/beacon_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.onSignIn,
    required this.onGoogleSignIn,
    required this.onCreateAccount,
    required this.onPasswordReset,
    super.key,
  });

  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function() onGoogleSignIn;
  final Future<void> Function(String email, String password) onCreateAccount;
  final Future<void> Function(String email) onPasswordReset;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _isSubmitting = false;
  bool _createAccount = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (_createAccount) {
        await widget.onCreateAccount(email, password);
      } else {
        await widget.onSignIn(email, password);
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not sign in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      await widget.onGoogleSignIn();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Google sign-in is unavailable right now.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    final atIndex = email.indexOf('@');
    if (atIndex < 1 ||
        atIndex != email.lastIndexOf('@') ||
        !email.substring(atIndex + 1).contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (_validateEmail(email) != null) {
      setState(() {
        _errorMessage = 'Enter your email above to reset your password.';
        _statusMessage = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      await widget.onPasswordReset(email);
      if (mounted) {
        setState(() => _statusMessage = 'Password reset email sent.');
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not send the reset email.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _authInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      floatingLabelStyle: const TextStyle(
        color: BeaconColors.ink,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAF6),
      prefixIcon: Icon(prefixIcon, color: BeaconColors.muted),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: BeaconColors.line, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: BeaconColors.line, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: BeaconColors.ink, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: BeaconColors.coral, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: BeaconColors.coral, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeaconColors.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: BeaconColors.ink,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: BeaconColors.lime,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.radar,
                                color: BeaconColors.ink,
                                size: 23,
                              ),
                            ),
                            const SizedBox(width: 11),
                            const Text(
                              'BEACON',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _createAccount
                              ? 'Start with a clearer picture.'
                              : 'Your days, in a new light.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 29,
                            height: 1.08,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _createAccount
                              ? 'Create your private movement journal.'
                              : 'A thoughtful view of where life takes you.',
                          style: const TextStyle(
                            color: Color(0xFFD4DFD8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SurfacePanel(
                    padding: 22,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _createAccount ? 'Create your account' : 'Welcome back',
                            style: const TextStyle(
                              color: BeaconColors.ink,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 19),
                          TextFormField(
                            key: const ValueKey('login-email'),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            style: const TextStyle(color: BeaconColors.ink),
                            decoration: _authInputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icons.mail_outline,
                            ),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const ValueKey('login-password'),
                            controller: _passwordController,
                            obscureText: _hidePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            style: const TextStyle(color: BeaconColors.ink),
                            decoration: _authInputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                tooltip: _hidePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: BeaconColors.muted,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').length < 6) {
                                return 'Use at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: BeaconColors.coral),
                            ),
                          ],
                          if (_statusMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _statusMessage!,
                              style: const TextStyle(color: BeaconColors.forest),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _isSubmitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: BeaconColors.ink,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isSubmitting
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _createAccount ? 'Create account' : 'Sign in',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Row(
                            children: [
                              Expanded(child: Divider(color: BeaconColors.line)),
                              SizedBox(width: 12),
                              Text(
                                'or continue with',
                                style: TextStyle(
                                  color: BeaconColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(child: Divider(color: BeaconColors.line)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _handleGoogleSignIn,
                              icon: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: BeaconColors.lime,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Center(
                                  child: Text(
                                    'G',
                                    style: TextStyle(
                                      color: BeaconColors.ink,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              label: const Text(
                                'Continue with Google',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: BeaconColors.ink,
                                side: const BorderSide(color: BeaconColors.line, width: 1.2),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          if (!_createAccount)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isSubmitting ? null : _sendPasswordReset,
                                child: const Text('Forgot password?'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() {
                                _createAccount = !_createAccount;
                                _errorMessage = null;
                                _statusMessage = null;
                              }),
                      child: Text(
                        _createAccount
                            ? 'Already have an account? Sign in'
                            : 'New to Beacon? Create account',
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEDB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: BeaconColors.forest),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Secured by Firebase Authentication. Your password is never stored by Beacon.',
                            style: TextStyle(
                              color: BeaconColors.forest,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}