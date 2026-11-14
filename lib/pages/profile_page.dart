import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../theme/beacon_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.user,
    required this.authService,
    required this.onOpenSettings,
    this.themePreset = BeaconThemePreset.active,
    super.key,
  });

  final AuthUser user;
  final AuthService authService;
  final ValueChanged<BuildContext> onOpenSettings;
  final BeaconThemePreset themePreset;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late String? _displayName = widget.user.displayName;
  late bool _emailVerified = widget.user.emailVerified;
  bool _isWorking = false;

  String get _profileName => _displayName?.trim().isNotEmpty == true
      ? _displayName!.trim()
      : 'Beacon member';

  String get _initial => _profileName == 'Beacon member'
      ? (widget.user.email.isEmpty ? 'B' : widget.user.email[0].toUpperCase())
      : _profileName[0].toUpperCase();

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editDisplayName() async {
    var editedName = _displayName ?? '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit display name'),
        content: TextField(
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          onChanged: (value) => editedName = value,
          decoration: const InputDecoration(
            labelText: 'Display name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, editedName.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;
    await _runAccountAction(() async {
      await widget.authService.updateDisplayName(name.trim());
      if (mounted) setState(() => _displayName = name.trim());
      _showMessage('Display name updated.');
    });
  }

  Future<void> _sendVerificationEmail() async {
    await _runAccountAction(() async {
      await widget.authService.sendEmailVerification();
      _showMessage('Verification email sent to ${widget.user.email}.');
    });
  }

  Future<void> _refreshVerificationStatus() async {
    await _runAccountAction(() async {
      final user = await widget.authService.reloadCurrentUser();
      if (mounted && user != null) {
        setState(() {
          _displayName = user.displayName;
          _emailVerified = user.emailVerified;
        });
      }
      _showMessage(
        user?.emailVerified == true
            ? 'Your email is verified.'
            : 'Email is not verified yet. Check your inbox.',
      );
    });
  }

  Future<void> _sendPasswordReset() async {
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset your password?'),
        content: Text('We will send a reset link to ${widget.user.email}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send email'),
          ),
        ],
      ),
    );
    if (shouldSend != true) return;

    await _runAccountAction(() async {
      await widget.authService.sendPasswordReset(widget.user.email);
      _showMessage('Password reset email sent.');
    });
  }

  Future<void> _signOut() async {
    await _runAccountAction(() async {
      await widget.authService.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _runAccountAction(Future<void> Function() action) async {
    setState(() => _isWorking = true);
    try {
      await action();
    } on AuthFailure catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePreset =
        Theme.of(context).extension<BeaconThemeTokens>()?.preset ??
            widget.themePreset;
    final theme = BeaconAppTheme.forPreset(activePreset);
    final verificationLabel = _emailVerified ? 'Verified' : 'Not verified';
    final verificationColor =
        _emailVerified ? theme.accentColor : BeaconColors.coral;

    return Container(
      color: theme.backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image(
              image: theme.backgroundImageProvider(),
              fit: BoxFit.cover,
              color: theme.backgroundColor.withValues(alpha: 0.14),
              colorBlendMode: BlendMode.srcOver,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.backgroundColor.withValues(alpha: 0.2),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: theme.surfaceColor.withValues(alpha: 0.88),
              foregroundColor: theme.textColor,
              scrolledUnderElevation: 0,
              title: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: const BorderRadius.all(Radius.circular(9)),
                    ),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.person_rounded,
                        color: theme.accentColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Profile',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Settings',
                  onPressed:
                      _isWorking ? null : () => widget.onOpenSettings(context),
                  style: IconButton.styleFrom(
                    foregroundColor: theme.accentColor,
                    backgroundColor: theme.cardColor.withValues(alpha: 0.88),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.cardColor.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: theme.secondaryColor,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _initial,
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profileName,
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.user.email,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.mutedTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: verificationColor.withValues(
                                        alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _emailVerified
                                            ? Icons.verified_rounded
                                            : Icons.pending_outlined,
                                        color: verificationColor,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        verificationLabel,
                                        style: TextStyle(
                                          color: theme.textColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _ProfileActionButton(
                        theme: theme,
                        label: 'Edit profile',
                        icon: Icons.edit_outlined,
                        primary: true,
                        onPressed: _isWorking ? null : _editDisplayName,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileMetric(
                        theme: theme,
                        label: 'Status',
                        value: verificationLabel,
                        color: verificationColor,
                        icon: _emailVerified
                            ? Icons.verified_rounded
                            : Icons.pending_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfileMetric(
                        theme: theme,
                        label: 'Privacy',
                        value: 'Protected',
                        color: theme.accentColor,
                        icon: Icons.shield_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfileMetric(
                        theme: theme,
                        label: 'Access',
                        value: 'Secure',
                        color: theme.primaryColor,
                        icon: Icons.lock_outline_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _ProfileSectionHeading(
                  'Account',
                  icon: Icons.person_outline_rounded,
                  theme: theme,
                ),
                const SizedBox(height: 10),
                _ProfilePanel(
                  theme: theme,
                  children: [
                    _ProfileDetail(
                      theme: theme,
                      icon: Icons.person_outline,
                      label: 'Display name',
                      value: _profileName,
                    ),
                    Divider(height: 22, color: theme.borderColor),
                    _ProfileDetail(
                      theme: theme,
                      icon: Icons.mail_outline,
                      label: 'Email address',
                      value: widget.user.email,
                      trailing: _emailVerified
                          ? Icon(Icons.verified, color: theme.accentColor)
                          : const Icon(Icons.error_outline,
                              color: BeaconColors.coral),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _ProfileSectionHeading(
                  'Security',
                  icon: Icons.shield_outlined,
                  theme: theme,
                ),
                const SizedBox(height: 10),
                _ProfilePanel(
                  theme: theme,
                  children: [
                    _ProfileActionTile(
                      theme: theme,
                      icon: Icons.password_rounded,
                      title: 'Reset password',
                      subtitle: 'Send a password reset link to your email',
                      onTap: _isWorking ? null : _sendPasswordReset,
                    ),
                    if (!_emailVerified)
                      Divider(height: 1, color: theme.borderColor),
                    if (!_emailVerified)
                      _ProfileActionTile(
                        theme: theme,
                        icon: Icons.mark_email_unread_outlined,
                        title: 'Verify email',
                        subtitle: 'Send a fresh verification email',
                        onTap: _isWorking ? null : _sendVerificationEmail,
                      ),
                    Divider(height: 1, color: theme.borderColor),
                    _ProfileActionTile(
                      theme: theme,
                      icon: Icons.refresh_rounded,
                      title: 'Refresh verification status',
                      subtitle: 'Check if your account state has updated',
                      onTap: _isWorking ? null : _refreshVerificationStatus,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _ProfileSectionHeading(
                  'Account access',
                  icon: Icons.login_rounded,
                  theme: theme,
                ),
                const SizedBox(height: 10),
                _ProfilePanel(
                  theme: theme,
                  children: [
                    _ProfileActionTile(
                      theme: theme,
                      icon: Icons.logout_rounded,
                      title: 'Log out',
                      subtitle: 'Sign out of Beacon on this device',
                      onTap: _isWorking ? null : _signOut,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'SECURED BY FIREBASE AUTH',
                    style: TextStyle(
                      color: theme.mutedTextColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.theme,
    required this.label,
    required this.icon,
    required this.primary,
    required this.onPressed,
  });

  final BeaconAppTheme theme;
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: primary
          ? FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: theme.secondaryColor,
                foregroundColor: theme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              icon: Icon(icon, size: 17),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.primaryColor,
                side: BorderSide(color: theme.borderColor),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              icon: Icon(icon, size: 17),
              label: Text(label),
            ),
    );
  }
}

class _ProfileSectionHeading extends StatelessWidget {
  const _ProfileSectionHeading(
    this.title, {
    required this.icon,
    required this.theme,
  });

  final String title;
  final IconData icon;
  final BeaconAppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.tagColor,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: theme.accentColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: theme.textColor,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.theme,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final BeaconAppTheme theme;
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: theme.tagColor,
        border: Border.all(color: theme.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: theme.mutedTextColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.theme, required this.children});

  final BeaconAppTheme theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: Border.all(color: theme.borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final BeaconAppTheme theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: theme.tagColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.accentColor, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: theme.textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(subtitle,
          style: TextStyle(color: theme.mutedTextColor, fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: theme.mutedTextColor),
      onTap: onTap,
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.theme,
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final BeaconAppTheme theme;
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: theme.accentColor, size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: theme.mutedTextColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
