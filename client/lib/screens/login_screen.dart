import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _ForgotPasswordStep { none, requestCode, reset }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _isSubmitting = false;
  bool _keepMeSignedIn = true;
  String? _resendMessage;
  bool _useBackupCode = false;

  _ForgotPasswordStep _forgotPasswordStep = _ForgotPasswordStep.none;
  String? _resetEmail;
  String? _forgotPasswordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _usernameController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final controller = ref.read(authControllerProvider.notifier);
    if (_isRegisterMode) {
      await controller.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        surname: _surnameController.text.trim(),
        timezone: DateTime.now().timeZoneName,
      );
    } else {
      await controller.login(
        _emailController.text.trim(),
        _passwordController.text,
        remember: _keepMeSignedIn,
      );
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    await ref
        .read(authControllerProvider.notifier)
        .verifyEmail(_codeController.text.trim(), remember: _keepMeSignedIn);
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _submitTwoFactor() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    await ref
        .read(authControllerProvider.notifier)
        .verifyTwoFactor(_codeController.text.trim(), remember: _keepMeSignedIn);
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _resendCode() async {
    setState(() => _resendMessage = null);
    await ref.read(authControllerProvider.notifier).resendVerificationCode();
    if (!mounted) return;
    setState(() => _resendMessage = AppLocalizations.of(context)!.verifyEmailResendSent);
  }

  void _startForgotPassword() {
    setState(() {
      _forgotPasswordStep = _ForgotPasswordStep.requestCode;
      _forgotPasswordError = null;
    });
  }

  void _cancelForgotPassword() {
    setState(() {
      _forgotPasswordStep = _ForgotPasswordStep.none;
      _forgotPasswordError = null;
      _resetEmail = null;
      _codeController.clear();
      _newPasswordController.clear();
    });
  }

  Future<void> _submitForgotPasswordRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _forgotPasswordError = null;
    });
    final email = _emailController.text.trim();
    final error = await ref.read(authControllerProvider.notifier).requestPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (error != null) {
        _forgotPasswordError = error;
      } else {
        _resetEmail = email;
        _forgotPasswordStep = _ForgotPasswordStep.reset;
      }
    });
  }

  Future<void> _submitPasswordReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _forgotPasswordError = null;
    });
    final error = await ref.read(authControllerProvider.notifier).resetPassword(
          email: _resetEmail!,
          code: _codeController.text.trim(),
          newPassword: _newPasswordController.text,
          remember: _keepMeSignedIn,
        );
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _forgotPasswordError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    if (authState.status == AuthStatus.needsVerification) {
      return _buildVerificationScaffold(context, authState, l10n);
    }

    if (authState.status == AuthStatus.needsTwoFactor) {
      return _buildTwoFactorScaffold(context, authState, l10n);
    }

    if (_forgotPasswordStep == _ForgotPasswordStep.requestCode) {
      return _buildForgotPasswordRequestScaffold(context, l10n);
    }
    if (_forgotPasswordStep == _ForgotPasswordStep.reset) {
      return _buildPasswordResetScaffold(context, l10n);
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isRegisterMode ? l10n.loginCreateAccount : l10n.loginSignIn,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: l10n.fieldEmail),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        (value == null || !value.contains('@')) ? l10n.validatorEmailInvalid : null,
                  ),
                  if (_isRegisterMode) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: l10n.fieldName),
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? l10n.validatorNameRequired : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _surnameController,
                      decoration: InputDecoration(labelText: l10n.fieldSurnameOptional),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: l10n.fieldUsername,
                        helperText: l10n.usernameHelperText,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.length < 3) return l10n.validatorUsernameTooShort;
                        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
                          return l10n.validatorUsernameFormat;
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: l10n.fieldPassword),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isSubmitting) _submit();
                    },
                    validator: (value) =>
                        (value == null || value.length < 8) ? l10n.validatorPasswordTooShort : null,
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.loginKeepMeSignedIn),
                    subtitle: Text(l10n.loginKeepMeSignedInSubtitle),
                    value: _keepMeSignedIn,
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _keepMeSignedIn = value ?? true),
                  ),
                  if (!_isRegisterMode)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isSubmitting ? null : _startForgotPassword,
                        child: Text(l10n.loginForgotPassword),
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (authState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        authState.errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isRegisterMode ? l10n.loginRegisterButton : l10n.loginLoginButton),
                  ),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() => _isRegisterMode = !_isRegisterMode),
                    child: Text(_isRegisterMode
                        ? l10n.loginToggleToSignIn
                        : l10n.loginToggleToRegister),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationScaffold(
    BuildContext context,
    AuthState authState,
    AppLocalizations l10n,
  ) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.verifyEmailTitle, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                    l10n.verifyEmailSubtitle(authState.pendingVerificationEmail ?? ''),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(labelText: l10n.fieldVerificationCode),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    onFieldSubmitted: (_) {
                      if (!_isSubmitting) _submitVerification();
                    },
                    validator: (value) => (value == null || value.trim().length != 6)
                        ? l10n.validatorCodeInvalid
                        : null,
                  ),
                  if (authState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        authState.errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submitVerification,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.verifyEmailButton),
                  ),
                  TextButton(
                    onPressed: _isSubmitting ? null : _resendCode,
                    child: Text(_resendMessage ?? l10n.verifyEmailResend),
                  ),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => ref.read(authControllerProvider.notifier).cancelVerification(),
                    child: Text(l10n.verifyEmailBackToSignIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoFactorScaffold(
    BuildContext context,
    AuthState authState,
    AppLocalizations l10n,
  ) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.twoFactorLoginTitle, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                    _useBackupCode ? l10n.twoFactorBackupSubtitle : l10n.twoFactorLoginSubtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: _useBackupCode ? l10n.fieldBackupCode : l10n.fieldTwoFactorCode,
                    ),
                    keyboardType: _useBackupCode ? TextInputType.text : TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: _useBackupCode ? 10 : 6,
                    onFieldSubmitted: (_) {
                      if (!_isSubmitting) _submitTwoFactor();
                    },
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      final validLength = _useBackupCode
                          ? trimmed.length >= 6 && trimmed.length <= 10
                          : trimmed.length == 6;
                      return validLength ? null : l10n.validatorTwoFactorCodeInvalid;
                    },
                  ),
                  if (authState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        authState.errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submitTwoFactor,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.verifyEmailButton),
                  ),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() {
                              _useBackupCode = !_useBackupCode;
                              _codeController.clear();
                            }),
                    child: Text(_useBackupCode
                        ? l10n.twoFactorUseAuthenticatorApp
                        : l10n.twoFactorUseBackupCode),
                  ),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => ref.read(authControllerProvider.notifier).cancelTwoFactor(),
                    child: Text(l10n.verifyEmailBackToSignIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordRequestScaffold(BuildContext context, AppLocalizations l10n) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.forgotPasswordTitle, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(l10n.forgotPasswordSubtitle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: l10n.fieldEmail),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isSubmitting) _submitForgotPasswordRequest();
                    },
                    validator: (value) =>
                        (value == null || !value.contains('@')) ? l10n.validatorEmailInvalid : null,
                  ),
                  if (_forgotPasswordError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _forgotPasswordError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submitForgotPasswordRequest,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.forgotPasswordSendButton),
                  ),
                  TextButton(
                    onPressed: _isSubmitting ? null : _cancelForgotPassword,
                    child: Text(l10n.forgotPasswordBackToSignIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordResetScaffold(BuildContext context, AppLocalizations l10n) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.resetPasswordTitle, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                    l10n.resetPasswordSubtitle(_resetEmail ?? ''),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(labelText: l10n.fieldVerificationCode),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    maxLength: 6,
                    validator: (value) => (value == null || value.trim().length != 6)
                        ? l10n.validatorCodeInvalid
                        : null,
                  ),
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(labelText: l10n.fieldNewPassword),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isSubmitting) _submitPasswordReset();
                    },
                    validator: (value) =>
                        (value == null || value.length < 8) ? l10n.validatorPasswordTooShort : null,
                  ),
                  if (_forgotPasswordError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _forgotPasswordError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submitPasswordReset,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.resetPasswordButton),
                  ),
                  TextButton(
                    onPressed: _isSubmitting ? null : _cancelForgotPassword,
                    child: Text(l10n.forgotPasswordBackToSignIn),
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
