import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/remote/api_exception.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';
import 'settings_section_header.dart';

/// Email/username/password management plus account deletion — the
/// "who you are" and "how to reach you" settings, separate from anything
/// about how the app itself looks or behaves.
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCategoryAccount)),
      body: ListView(
        children: [
          _buildAccountFields(l10n),
          const Divider(),
          SettingsSectionHeader(l10n.sectionTwoFactorAuth),
          _buildTwoFactorSection(l10n),
          const Divider(),
          SettingsSectionHeader(l10n.sectionDangerZone),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
              icon: const Icon(Icons.delete_forever_outlined, size: 18),
              label: Text(l10n.actionDeleteAccount),
              onPressed: () => _confirmDeleteAccount(l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountFields(AppLocalizations l10n) {
    final profileAsync = ref.watch(myProfileProvider);
    return profileAsync.when(
      data: (profile) => Column(
        children: [
          ListTile(
            dense: true,
            title: Text(l10n.fieldEmail),
            subtitle: Text(profile['email'] as String),
            trailing: TextButton(
              onPressed: () => _changeEmail(l10n, profile['email'] as String),
              child: Text(l10n.actionChange),
            ),
          ),
          ListTile(
            dense: true,
            title: Text(l10n.fieldUsername),
            subtitle: Text('@${profile['username']}'),
            trailing: TextButton(
              onPressed: () => _changeUsername(l10n, profile['username'] as String),
              child: Text(l10n.actionChange),
            ),
          ),
          ListTile(
            dense: true,
            title: Text(l10n.fieldPassword),
            subtitle: const Text('••••••••'),
            trailing: TextButton(
              onPressed: () => _changePassword(l10n),
              child: Text(l10n.actionChange),
            ),
          ),
        ],
      ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(l10n.failedToLoadGeneric(error.toString())),
      ),
    );
  }

  Widget _buildTwoFactorSection(AppLocalizations l10n) {
    final profileAsync = ref.watch(myProfileProvider);
    return profileAsync.when(
      data: (profile) {
        final enabled = profile['twoFactorEnabled'] as bool? ?? false;
        return ListTile(
          dense: true,
          title: Text(enabled ? l10n.twoFactorStatusEnabled : l10n.twoFactorStatusDisabled),
          subtitle: enabled ? null : Text(l10n.twoFactorSectionSubtitle),
          trailing: TextButton(
            onPressed: () => enabled ? _disableTwoFactor(l10n) : _enableTwoFactor(l10n),
            child: Text(enabled ? l10n.actionDisable : l10n.actionEnable),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  // Three-step flow: setupTotp() gets a secret+QR to scan, a dialog collects
  // the confirmation code to enableTotp() with, and — only on success — a
  // second dialog shows the one-time backup codes, gated behind an explicit
  // "I've saved these" checkbox since they can never be shown again.
  Future<void> _enableTwoFactor(AppLocalizations l10n) async {
    Map<String, dynamic> setup;
    try {
      setup = await ref.read(authRepositoryProvider).setupTotp();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) return;

    final backupCodes = await _showTotpSetupDialog(
      l10n,
      setup['otpauthUrl'] as String,
      setup['secret'] as String,
    );
    if (backupCodes == null || !mounted) return;

    ref.invalidate(myProfileProvider);
    await _showBackupCodesDialog(l10n, backupCodes);
  }

  Future<List<String>?> _showTotpSetupDialog(
    AppLocalizations l10n,
    String otpauthUrl,
    String secret,
  ) async {
    final codeController = TextEditingController();
    var isSubmitting = false;
    String? error;

    final backupCodes = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.twoFactorSetupDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.twoFactorSetupInstructions),
                const SizedBox(height: 16),
                Center(child: QrImageView(data: otpauthUrl, size: 180)),
                const SizedBox(height: 12),
                Center(
                  child: SelectableText(secret, style: const TextStyle(fontFamily: 'monospace')),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  autofocus: true,
                  enabled: !isSubmitting,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.fieldTwoFactorCode),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() {
                        isSubmitting = true;
                        error = null;
                      });
                      try {
                        final codes = await ref
                            .read(authRepositoryProvider)
                            .enableTotp(codeController.text.trim());
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop(codes);
                      } on ApiException catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          error = e.message;
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.actionSave),
            ),
          ],
        ),
      ),
    );

    codeController.dispose();
    return backupCodes;
  }

  Future<void> _showBackupCodesDialog(AppLocalizations l10n, List<String> codes) async {
    var confirmed = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.twoFactorBackupCodesDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.twoFactorBackupCodesWarning),
                const SizedBox(height: 12),
                SelectableText(
                  codes.join('\n'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(l10n.twoFactorBackupCodesConfirmCheckbox),
                  value: confirmed,
                  onChanged: (value) => setDialogState(() => confirmed = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: confirmed ? () => Navigator.of(dialogContext).pop() : null,
              child: Text(l10n.actionDone),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _disableTwoFactor(AppLocalizations l10n) async {
    final passwordController = TextEditingController();
    final codeController = TextEditingController();
    var isSubmitting = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.twoFactorDisableDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                enabled: !isSubmitting,
                decoration: InputDecoration(labelText: l10n.fieldPassword),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                enabled: !isSubmitting,
                decoration: InputDecoration(labelText: l10n.fieldTwoFactorCode),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() {
                        isSubmitting = true;
                        error = null;
                      });
                      try {
                        await ref.read(authRepositoryProvider).disableTotp(
                              password: passwordController.text,
                              code: codeController.text.trim(),
                            );
                        ref.invalidate(myProfileProvider);
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                      } on ApiException catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          error = e.message;
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.actionDisable),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    codeController.dispose();
  }

  Future<void> _changeUsername(AppLocalizations l10n, String currentUsername) async {
    final usernameController = TextEditingController(text: currentUsername);
    final passwordController = TextEditingController();
    var isSubmitting = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.changeUsernameDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                autofocus: true,
                enabled: !isSubmitting,
                decoration: InputDecoration(labelText: l10n.fieldNewUsername),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                enabled: !isSubmitting,
                decoration: InputDecoration(labelText: l10n.fieldPassword),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() {
                        isSubmitting = true;
                        error = null;
                      });
                      try {
                        await ref.read(authRepositoryProvider).updateUsername(
                              newUsername: usernameController.text.trim(),
                              password: passwordController.text,
                            );
                        ref.invalidate(myProfileProvider);
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(l10n.usernameChangedMessage)));
                        }
                      } on ApiException catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          error = e.message;
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.actionSave),
            ),
          ],
        ),
      ),
    );

    usernameController.dispose();
    passwordController.dispose();
  }

  Future<void> _changePassword(AppLocalizations l10n) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    var isSubmitting = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.changePasswordDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                autofocus: true,
                enabled: !isSubmitting,
                decoration: InputDecoration(labelText: l10n.fieldCurrentPassword),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                enabled: !isSubmitting,
                decoration: InputDecoration(
                  labelText: l10n.fieldNewPassword,
                  helperText: l10n.passwordRequirementsHint,
                  helperMaxLines: 2,
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() {
                        isSubmitting = true;
                        error = null;
                      });
                      try {
                        await ref.read(authRepositoryProvider).changePassword(
                              currentPassword: currentController.text,
                              newPassword: newController.text,
                            );
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(l10n.passwordChangedMessage)));
                        }
                      } on ApiException catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          error = e.message;
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.actionSave),
            ),
          ],
        ),
      ),
    );

    currentController.dispose();
    newController.dispose();
  }

  Future<void> _changeEmail(AppLocalizations l10n, String currentEmail) async {
    final emailController = TextEditingController(text: currentEmail);
    final passwordController = TextEditingController();
    var isSubmitting = false;
    String? error;

    final newEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.changeEmailDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                autofocus: true,
                enabled: !isSubmitting,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.fieldNewEmail),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                enabled: !isSubmitting,
                decoration: InputDecoration(labelText: l10n.fieldPassword),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final trimmed = emailController.text.trim();
                      setDialogState(() {
                        isSubmitting = true;
                        error = null;
                      });
                      try {
                        await ref.read(authRepositoryProvider).requestEmailChange(
                              newEmail: trimmed,
                              password: passwordController.text,
                            );
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop(trimmed);
                      } on ApiException catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          error = e.message;
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.actionSave),
            ),
          ],
        ),
      ),
    );

    emailController.dispose();
    passwordController.dispose();

    if (newEmail == null || !mounted) return;
    await _verifyNewEmail(l10n, newEmail);
  }

  Future<void> _verifyNewEmail(AppLocalizations l10n, String newEmail) async {
    final codeController = TextEditingController();
    var isSubmitting = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.verifyNewEmailDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.verifyNewEmailMessage(newEmail)),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                autofocus: true,
                enabled: !isSubmitting,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.fieldVerificationCode),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => ref.read(authRepositoryProvider).resendVerification(newEmail),
                  child: Text(l10n.verifyEmailResend),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() {
                        isSubmitting = true;
                        error = null;
                      });
                      try {
                        await ref.read(authRepositoryProvider).confirmEmailChange(
                              email: newEmail,
                              code: codeController.text.trim(),
                            );
                        ref.invalidate(myProfileProvider);
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(l10n.emailChangedMessage)));
                        }
                      } on ApiException catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          error = e.message;
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.actionSave),
            ),
          ],
        ),
      ),
    );

    codeController.dispose();
  }

  Future<void> _confirmDeleteAccount(AppLocalizations l10n) async {
    final passwordController = TextEditingController();
    var isSubmitting = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.deleteAccountDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.deleteAccountWarning),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                enabled: !isSubmitting,
                decoration: InputDecoration(labelText: l10n.fieldPassword),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() {
                        isSubmitting = true;
                        error = null;
                      });
                      final result = await ref
                          .read(authControllerProvider.notifier)
                          .deleteAccount(passwordController.text);
                      if (result == null) {
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                      } else {
                        setDialogState(() {
                          isSubmitting = false;
                          error = result;
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.deleteAccountConfirmButton),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
  }
}
