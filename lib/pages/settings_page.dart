import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../theme/beacon_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.trackingEnabled,
    required this.onTrackingChanged,
    required this.userEmail,
    required this.userSettings,
    required this.onUserSettingsChanged,
    required this.onLogout,
    super.key,
  });

  final bool trackingEnabled;
  final ValueChanged<bool> onTrackingChanged;
  final String userEmail;
  final UserSettings userSettings;
  final ValueChanged<UserSettings> onUserSettingsChanged;
  final Future<void> Function() onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _approximateLocation = widget.userSettings.approximateLocation;
  late bool _familySharing = widget.userSettings.familySharing;
  late bool _notifications = widget.userSettings.notifications;

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userSettings != widget.userSettings) {
      setState(() {
        _approximateLocation = widget.userSettings.approximateLocation;
        _familySharing = widget.userSettings.familySharing;
        _notifications = widget.userSettings.notifications;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDeleteHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete movement history?'),
        content: const Text(
          'Saved trips are stored in your Beacon account. Deleting movement history is not available yet, so this action will not remove your trips.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _showMessage(
          'Your saved trips are unchanged. History deletion is not available yet.');
    }
  }

  Future<void> _confirmLogOut() async {
    final shouldLogOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out of Beacon?'),
        content: const Text(
          'You will need to sign in again to open this app on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldLogOut == true) await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: BeaconColors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BeaconColors.ink,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: BeaconColors.lime,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.person_outline, color: BeaconColors.ink),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SIGNED IN AS',
                        style: TextStyle(
                          color: Color(0xFFB8C7BD),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.userEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const _SettingsSectionHeading('Movement'),
          const SizedBox(height: 9),
          _SettingsGroup(
            children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                secondary: const _SettingIcon(Icons.my_location_outlined),
                title: const Text('Track my movement'),
                subtitle: const Text('Start or pause location recording'),
                value: widget.trackingEnabled,
                onChanged: widget.onTrackingChanged,
              ),
              const Divider(height: 1, indent: 62, color: BeaconColors.line),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                secondary: const _SettingIcon(Icons.location_searching),
                title: const Text('Approximate location'),
                subtitle: const Text('Share a broader area instead of a pin'),
                value: _approximateLocation,
                onChanged: (value) {
                  setState(() => _approximateLocation = value);
                  widget.onUserSettingsChanged(
                    UserSettings(
                      trackingEnabled: widget.trackingEnabled,
                      approximateLocation: value,
                      familySharing: _familySharing,
                      notifications: _notifications,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SettingsSectionHeading('Sharing and alerts'),
          const SizedBox(height: 9),
          _SettingsGroup(
            children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                secondary: const _SettingIcon(Icons.family_restroom_outlined),
                title: const Text('Family location sharing'),
                subtitle: const Text('Share with your approved circle'),
                value: _familySharing,
                onChanged: (value) {
                  setState(() => _familySharing = value);
                  widget.onUserSettingsChanged(
                    UserSettings(
                      trackingEnabled: widget.trackingEnabled,
                      approximateLocation: _approximateLocation,
                      familySharing: value,
                      notifications: _notifications,
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 62, color: BeaconColors.line),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                secondary: const _SettingIcon(Icons.notifications_none_rounded),
                title: const Text('Notifications'),
                subtitle: const Text('Movement and place updates'),
                value: _notifications,
                onChanged: (value) {
                  setState(() => _notifications = value);
                  widget.onUserSettingsChanged(
                    UserSettings(
                      trackingEnabled: widget.trackingEnabled,
                      approximateLocation: _approximateLocation,
                      familySharing: _familySharing,
                      notifications: value,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SettingsSectionHeading('Your data'),
          const SizedBox(height: 9),
          _SettingsGroup(
            children: [
              _SettingsAction(
                icon: Icons.ios_share_rounded,
                title: 'Export my data',
                onTap: () =>
                    _showMessage('Data export will be available soon.'),
              ),
              const Divider(height: 1, indent: 58, color: BeaconColors.line),
              _SettingsAction(
                icon: Icons.delete_outline_rounded,
                title: 'Delete movement history',
                destructive: true,
                onTap: _confirmDeleteHistory,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsGroup(
            children: [
              _SettingsAction(
                icon: Icons.logout_rounded,
                title: 'Log out',
                onTap: _confirmLogOut,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionHeading extends StatelessWidget {
  const _SettingsSectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: BeaconColors.ink,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BeaconColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEDB),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, color: BeaconColors.forest, size: 18),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? BeaconColors.coral : BeaconColors.ink;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: _SettingIcon(icon),
      title: Text(title, style: TextStyle(color: color)),
      trailing: Icon(Icons.chevron_right, color: color),
      onTap: onTap,
    );
  }
}
