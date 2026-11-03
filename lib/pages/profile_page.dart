import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../theme/beacon_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.user,
    required this.authService,
    required this.onOpenSettings,
    super.key,
  });

  final AuthUser user;
  final AuthService authService;
  final VoidCallback onOpenSettings;

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

  Future<void> _deleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon:
            const Icon(Icons.warning_amber_rounded, color: BeaconColors.coral),
        title: const Text('Delete your account?'),
        content: const Text(
          'This deletes your Firebase sign-in account. Your Firestore profile, saved trips, family connections, and chats are not automatically erased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep account'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BeaconColors.coral),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    await _runAccountAction(() async {
      await widget.authService.deleteAccount();
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
    final verificationLabel = _emailVerified ? 'Verified' : 'Not verified';
    final verificationColor =
        _emailVerified ? BeaconColors.forest : BeaconColors.coral;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _isWorking ? null : widget.onOpenSettings,
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
              color: BeaconColors.ink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 31,
                      backgroundColor: BeaconColors.lime,
                      foregroundColor: BeaconColors.ink,
                      child: Text(
                        _initial,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.user.email,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB8C7BD),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileActionButton(
                        label: 'Edit name',
                        icon: Icons.edit_outlined,
                        onPressed: _isWorking ? null : _editDisplayName,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfileActionButton(
                        label: 'Settings',
                        icon: Icons.tune_rounded,
                        onPressed: _isWorking ? null : widget.onOpenSettings,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _ProfileMetric(
                  label: 'Status',
                  value: verificationLabel,
                  color: verificationColor,
                  icon: _emailVerified
                      ? Icons.verified_rounded
                      : Icons.pending_outlined,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _ProfileMetric(
                  label: 'Privacy',
                  value: 'Protected',
                  color: BeaconColors.forest,
                  icon: Icons.shield_outlined,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _ProfileMetric(
                  label: 'Access',
                  value: 'Secure',
                  color: BeaconColors.blue,
                  icon: Icons.lock_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Account',
            style: TextStyle(
              color: BeaconColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _ProfilePanel(
            children: [
              _ProfileDetail(
                icon: Icons.person_outline,
                label: 'Display name',
                value: _profileName,
              ),
              const Divider(height: 22, color: BeaconColors.line),
              _ProfileDetail(
                icon: Icons.mail_outline,
                label: 'Email address',
                value: widget.user.email,
                trailing: _emailVerified
                    ? const Icon(Icons.verified, color: BeaconColors.forest)
                    : const Icon(Icons.error_outline,
                        color: BeaconColors.coral),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Security',
            style: TextStyle(
              color: BeaconColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _ProfilePanel(
            children: [
              _ProfileActionTile(
                icon: Icons.password_rounded,
                title: 'Reset password',
                subtitle: 'Send a password reset link to your email',
                onTap: _isWorking ? null : _sendPasswordReset,
              ),
              if (!_emailVerified)
                const Divider(height: 1, color: BeaconColors.line),
              if (!_emailVerified)
                _ProfileActionTile(
                  icon: Icons.mark_email_unread_outlined,
                  title: 'Verify email',
                  subtitle: 'Send a fresh verification email',
                  onTap: _isWorking ? null : _sendVerificationEmail,
                ),
              const Divider(height: 1, color: BeaconColors.line),
              _ProfileActionTile(
                icon: Icons.refresh_rounded,
                title: 'Refresh verification status',
                subtitle: 'Check if your account state has updated',
                onTap: _isWorking ? null : _refreshVerificationStatus,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Account access',
            style: TextStyle(
              color: BeaconColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _ProfilePanel(
            children: [
              _ProfileActionTile(
                icon: Icons.logout_rounded,
                title: 'Log out',
                subtitle: 'Sign out of Beacon on this device',
                onTap: _isWorking ? null : _signOut,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Danger zone',
            style: TextStyle(
              color: BeaconColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EB),
              border: Border.all(color: const Color(0xFFF3D3C9)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: const Color(0xFFFFF0EB),
              borderRadius: BorderRadius.circular(8),
              child: ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: BeaconColors.coral),
                title: const Text(
                  'Delete account',
                  style: TextStyle(
                    color: BeaconColors.coral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle:
                    const Text('Permanently remove your Firebase account'),
                trailing:
                    const Icon(Icons.chevron_right, color: BeaconColors.coral),
                onTap: _isWorking ? null : _deleteAccount,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'SECURED BY FIREBASE AUTH',
              style: TextStyle(
                color: BeaconColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: BeaconColors.lime,
          foregroundColor: BeaconColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        icon: Icon(icon, size: 17),
        label: Text(label),
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BeaconColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              color: BeaconColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: BeaconColors.muted,
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
  const _ProfilePanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BeaconColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

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
          color: const Color(0xFFE8EEDB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: BeaconColors.ink, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: BeaconColors.muted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: BeaconColors.muted),
      onTap: onTap,
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: BeaconColors.muted, size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: BeaconColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: BeaconColors.ink,
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
