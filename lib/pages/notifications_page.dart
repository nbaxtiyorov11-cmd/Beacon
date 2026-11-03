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
    super.key,
  });

  final String userId;
  final AuthUser currentUser;
  final FirestoreService firestoreService;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: false,
        foregroundColor: BeaconColors.ink,
        backgroundColor: BeaconColors.paper,
        elevation: 0,
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
            builder: (context, invitationSnapshot) {
              final invitations =
                  invitationSnapshot.data ?? const <FamilyInvitation>[];
              final visibleAlerts = _filter == _NotificationFilter.requests
                  ? const <FamilyContact>[]
                  : activeAlerts;
              final visibleInvitations =
                  _filter == _NotificationFilter.emergency
                      ? const <FamilyInvitation>[]
                      : invitations;
              final hasNotifications =
                  visibleAlerts.isNotEmpty || visibleInvitations.isNotEmpty;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  SegmentedButton<_NotificationFilter>(
                    segments: const [
                      ButtonSegment(
                        value: _NotificationFilter.all,
                        label: Text('All'),
                      ),
                      ButtonSegment(
                        value: _NotificationFilter.emergency,
                        label: Text('Emergency'),
                      ),
                      ButtonSegment(
                        value: _NotificationFilter.requests,
                        label: Text('Requests'),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (selection) =>
                        setState(() => _filter = selection.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStatePropertyAll(
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
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
                      !invitationSnapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 52),
                      child: Column(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8EEDB),
                              borderRadius: BorderRadius.all(Radius.circular(18)),
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
                            _EmergencyAlertTile(contact: visibleAlerts[index]),
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
