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
        title: const Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFE7EEE9),
                borderRadius: BorderRadius.all(Radius.circular(9)),
              ),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.tune_rounded,
                  color: BeaconColors.forest,
                  size: 19,
                ),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Settings',
              style: TextStyle(
                color: BeaconColors.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        backgroundColor: BeaconColors.paper,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
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
                    color: BeaconColors.blue.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: BeaconColors.blue,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ACCOUNT',
                        style: TextStyle(
                          color: BeaconColors.lime,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
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
          const _SettingsSectionHeading(
            'Movement',
            icon: Icons.route_rounded,
            color: BeaconColors.blue,
          ),
          const SizedBox(height: 9),
          _SettingsGroup(
            children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                secondary: const _SettingIcon(
                  Icons.my_location_outlined,
                  color: BeaconColors.blue,
                ),
                title: const Text('Track my movement'),
                subtitle: const Text('Start or pause location recording'),
                value: widget.trackingEnabled,
                activeThumbColor: BeaconColors.lime,
                activeTrackColor: BeaconColors.forest,
                onChanged: widget.onTrackingChanged,
              ),
              const Divider(height: 1, indent: 62, color: BeaconColors.line),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                secondary: const _SettingIcon(
                  Icons.location_searching,
                  color: BeaconColors.forest,
                ),
                title: const Text('Approximate location'),
                subtitle: const Text('Share a broader area instead of a pin'),
                value: _approximateLocation,
                activeThumbColor: BeaconColors.lime,
                activeTrackColor: BeaconColors.forest,
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
          const _SettingsSectionHeading(
            'Sharing and alerts',
            icon: Icons.notifications_active_outlined,
            color: BeaconColors.coral,
          ),
          const SizedBox(height: 9),
          _SettingsGroup(
            children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                secondary: const _SettingIcon(
                  Icons.family_restroom_outlined,
                  color: BeaconColors.blue,
                ),
                title: const Text('Family location sharing'),
                subtitle: const Text('Share with your approved circle'),
                value: _familySharing,
                activeThumbColor: BeaconColors.lime,
                activeTrackColor: BeaconColors.forest,
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
                secondary: const _SettingIcon(
                  Icons.notifications_none_rounded,
                  color: BeaconColors.coral,
                ),
                title: const Text('Notifications'),
                subtitle: const Text('Movement and place updates'),
                value: _notifications,
                activeThumbColor: BeaconColors.lime,
                activeTrackColor: BeaconColors.forest,
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
          const _SettingsSectionHeading(
            'Your data',
            icon: Icons.shield_outlined,
            color: BeaconColors.forest,
          ),
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
  const _SettingsSectionHeading(
    this.title, {
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: BeaconColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
  const _SettingIcon(this.icon, {this.color = BeaconColors.forest});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: color, size: 18),
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
      leading: _SettingIcon(
        icon,
        color: destructive ? BeaconColors.coral : BeaconColors.forest,
      ),
      title: Text(title, style: TextStyle(color: color)),
      trailing: Icon(Icons.chevron_right, color: color),
      onTap: onTap,
    );
  }
}
