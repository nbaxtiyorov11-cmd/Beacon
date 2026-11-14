import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/beacon_theme.dart';
import '../widgets/beacon_widgets.dart';

enum _NotificationFilter { all, emergency, requests }

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    required this.userId,
    required this.currentUser,
    required this.firestoreService,
    this.initialInvitations = const [],
    this.themePreset = BeaconThemePreset.active,
    super.key,
  });

  final String userId;
  final AuthUser currentUser;
  final FirestoreService firestoreService;
  final List<FamilyInvitation> initialInvitations;
  final BeaconThemePreset themePreset;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final Set<String> _respondingToInvitations = {};
  late final Stream<List<FamilyInvitation>> _invitations;
  late final Stream<List<FamilyContact>> _familyContacts;
  _NotificationFilter _filter = _NotificationFilter.all;
  Timer? _alertExpiryTimer;

  @override
  void initState() {
    super.initState();
    _invitations =
        widget.firestoreService.watchIncomingFamilyInvitations(widget.userId);
    _familyContacts =
        widget.firestoreService.watchFamilyContacts(widget.userId);
    _alertExpiryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _alertExpiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _respondToInvitation(
    FamilyInvitation invitation, {
    required bool accept,
  }) async {
    setState(() => _respondingToInvitations.add(invitation.id));
    try {
      await widget.firestoreService.respondToFamilyInvitation(
        userId: widget.userId,
        invitation: invitation,
        accept: accept,
      );
      if (!mounted) return;
      _showMessage(accept ? 'You are now connected.' : 'Request declined.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not update request: $error');
    } finally {
      if (mounted) {
        setState(() => _respondingToInvitations.remove(invitation.id));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeaconAppTheme.forPreset(widget.themePreset);
    return Container(
      color: theme.backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image(
              image: theme.backgroundImageProvider(),
              fit: BoxFit.cover,
              color: theme.backgroundColor.withValues(alpha: 0.12),
              colorBlendMode: BlendMode.srcOver,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.backgroundColor.withValues(alpha: 0.26),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
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
                        Icons.notifications_active_rounded,
                        color: theme.accentColor,
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALERT CENTER',
                        style: TextStyle(
                          color: theme.accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Notifications',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              centerTitle: false,
              foregroundColor: theme.textColor,
              backgroundColor: theme.surfaceColor.withValues(alpha: 0.9),
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            body: StreamBuilder<List<FamilyContact>>(
              stream: _familyContacts,
              builder: (context, snapshot) {
                final contacts = snapshot.data ?? const <FamilyContact>[];
                final activeAlerts = contacts.where((contact) {
                  return contact.emergencyActive &&
                      (contact.emergencyExpiresAt == null ||
                          contact.emergencyExpiresAt!.isAfter(DateTime.now()));
                }).toList();
                return StreamBuilder<List<FamilyInvitation>>(
                  stream: _invitations,
                  initialData: widget.initialInvitations,
                  builder: (context, invitationSnapshot) {
                    final invitations =
                        invitationSnapshot.data ?? const <FamilyInvitation>[];
                    final visibleAlerts =
                        _filter == _NotificationFilter.requests
                            ? const <FamilyContact>[]
                            : activeAlerts;
                    final visibleInvitations =
                        _filter == _NotificationFilter.emergency
                            ? const <FamilyInvitation>[]
                            : invitations;
                    final hasNotifications = visibleAlerts.isNotEmpty ||
                        visibleInvitations.isNotEmpty;
                    final isLoading = !hasNotifications &&
                        !snapshot.hasError &&
                        !invitationSnapshot.hasError &&
                        (snapshot.connectionState == ConnectionState.waiting ||
                            invitationSnapshot.connectionState ==
                                ConnectionState.waiting);
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                      children: [
                        _NotificationFilterBar(
                          selected: _filter,
                          onChanged: (filter) =>
                              setState(() => _filter = filter),
                          alertCount: activeAlerts.length,
                          requestCount: invitations.length,
                        ),
                        if (snapshot.hasError || invitationSnapshot.hasError)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: SurfacePanel(
                              child: Text(
                                'Some notifications could not be loaded. Check your connection and try again.',
                                style: TextStyle(color: BeaconColors.muted),
                              ),
                            ),
                          ),
                        if (!hasNotifications &&
                            !snapshot.hasError &&
                            !invitationSnapshot.hasError &&
                            isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (!hasNotifications &&
                            !snapshot.hasError &&
                            !invitationSnapshot.hasError &&
                            !isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Column(
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE8EEDB),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(18)),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: BeaconColors.forest,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'You’re all caught up',
                                  style: TextStyle(
                                    color: BeaconColors.ink,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (visibleAlerts.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _NotificationSectionHeading(
                            title: 'Emergency alerts',
                            count: visibleAlerts.length,
                            urgent: true,
                          ),
                          const SizedBox(height: 10),
                          SurfacePanel(
                            child: Column(
                              children: [
                                for (var index = 0;
                                    index < visibleAlerts.length;
                                    index++) ...[
                                  if (index > 0)
                                    const Divider(
                                        height: 1, color: BeaconColors.line),
                                  _EmergencyAlertTile(
                                      contact: visibleAlerts[index]),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (visibleInvitations.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _NotificationSectionHeading(
                            title: 'Family requests',
                            count: visibleInvitations.length,
                          ),
                          const SizedBox(height: 10),
                          SurfacePanel(
                            child: Column(
                              children: [
                                for (var index = 0;
                                    index < visibleInvitations.length;
                                    index++) ...[
                                  if (index > 0)
                                    const Divider(
                                        height: 1, color: BeaconColors.line),
                                  _InvitationTile(
                                    invitation: visibleInvitations[index],
                                    busy: _respondingToInvitations
                                        .contains(visibleInvitations[index].id),
                                    onAccept: () => _respondToInvitation(
                                        visibleInvitations[index],
                                        accept: true),
                                    onDecline: () => _respondToInvitation(
                                        visibleInvitations[index],
                                        accept: false),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationFilterBar extends StatelessWidget {
  const _NotificationFilterBar({
    required this.selected,
    required this.onChanged,
    required this.alertCount,
    required this.requestCount,
  });

  final _NotificationFilter selected;
  final ValueChanged<_NotificationFilter> onChanged;
  final int alertCount;
  final int requestCount;

  @override
  Widget build(BuildContext context) {
    final filters = [
      (
        _NotificationFilter.all,
        'All',
        Icons.inbox_rounded,
        alertCount + requestCount
      ),
      (
        _NotificationFilter.emergency,
        'Emergency',
        Icons.sos_rounded,
        alertCount
      ),
      (
        _NotificationFilter.requests,
        'Requests',
        Icons.person_add_alt_1_rounded,
        requestCount
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BeaconColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final (filter, label, icon, count) in filters)
            Expanded(
              child: Semantics(
                button: true,
                selected: selected == filter,
                label: '$label, $count',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onChanged(filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: selected == filter
                          ? BeaconColors.forest
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 15,
                          color: selected == filter
                              ? BeaconColors.lime
                              : BeaconColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected == filter
                                  ? Colors.white
                                  : BeaconColors.ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '$count',
                            style: TextStyle(
                              color: selected == filter
                                  ? BeaconColors.lime
                                  : BeaconColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationSectionHeading extends StatelessWidget {
  const _NotificationSectionHeading({
    required this.title,
    required this.count,
    this.urgent = false,
  });

  final String title;
  final int count;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: BeaconColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: urgent ? const Color(0xFFFCE2DE) : const Color(0xFFE8EEDB),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: urgent ? BeaconColors.coral : BeaconColors.forest,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmergencyAlertTile extends StatelessWidget {
  const _EmergencyAlertTile({required this.contact});

  final FamilyContact contact;

  @override
  Widget build(BuildContext context) {
    final latitude = contact.emergencyLatitude;
    final longitude = contact.emergencyLongitude;
    final hasLocation = latitude != null && longitude != null;
    final coordinates = hasLocation
        ? '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
        : 'Location is not available';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFFCE2DE),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.sos_rounded, color: BeaconColors.coral),
      ),
      title: Text('${contact.name} needs help',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        coordinates,
        style: const TextStyle(color: BeaconColors.muted, fontSize: 12),
      ),
      trailing: hasLocation
          ? IconButton(
              tooltip: 'Open location in maps',
              onPressed: () => launchUrl(Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
              )),
              icon: const Icon(Icons.map_outlined),
            )
          : null,
    );
  }
}

class _InvitationTile extends StatelessWidget {
  const _InvitationTile({
    required this.invitation,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final FamilyInvitation invitation;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE5EDF7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: BeaconColors.blue,
            ),
          ),
          title: Text(
            invitation.fromName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            invitation.fromEmail.isEmpty
                ? 'Family circle invitation'
                : invitation.fromEmail,
            style: const TextStyle(color: BeaconColors.muted, fontSize: 12),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: busy ? null : onDecline,
              style: TextButton.styleFrom(foregroundColor: BeaconColors.muted),
              child: const Text('Decline'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: busy ? null : onAccept,
              child: Text(busy ? 'Please wait' : 'Accept'),
            ),
          ],
        ),
      ],
    );
  }
}
