import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import 'chat_room_page.dart';
import 'member_profile_page.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/trip_service.dart';
import '../theme/beacon_theme.dart';
import '../widgets/beacon_widgets.dart';

class FamilyPage extends StatefulWidget {
  const FamilyPage({
    required this.userId,
    required this.currentUser,
    required this.firestoreService,
    this.locationService,
    this.familySharing = false,
    this.activeSafePlaceId,
    this.activeSafePlaceSeconds = 0,
    this.onFamilySharingChanged,
    super.key,
  });

  final String userId;
  final AuthUser currentUser;
  final FirestoreService firestoreService;
  final LocationService? locationService;
  final bool familySharing;
  final String? activeSafePlaceId;
  final int activeSafePlaceSeconds;
  final Future<void> Function(bool)? onFamilySharingChanged;

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  bool _sharingEnabled = false;
  bool _savingSharing = false;
  bool _showChats = false;
  late final Stream<List<FamilyContact>> _familyContacts;
  late final Stream<List<ChatConversation>> _chatConversations;
  late final Stream<List<SafePlace>> _safePlaces;
  Timer? _alertExpiryTimer;

  @override
  void initState() {
    super.initState();
    _sharingEnabled = widget.familySharing;
    _familyContacts =
        widget.firestoreService.watchFamilyContacts(widget.userId);
    _chatConversations =
        widget.firestoreService.watchChatConversations(widget.userId);
    _safePlaces = widget.firestoreService.watchSafePlaces(widget.userId);
    _alertExpiryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _alertExpiryTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FamilyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.familySharing != widget.familySharing) {
      _sharingEnabled = widget.familySharing;
    }
  }

  Future<void> _setSharing(bool enabled) async {
    final previous = _sharingEnabled;
    setState(() {
      _sharingEnabled = enabled;
      _savingSharing = true;
    });
    try {
      await widget.onFamilySharingChanged?.call(enabled);
    } catch (error) {
      if (mounted) {
        setState(() => _sharingEnabled = previous);
        _showMessage('Could not update location sharing: $error');
      }
    } finally {
      if (mounted) setState(() => _savingSharing = false);
    }
  }

  Future<void> _inviteMember() async {
    final rawName = await showDialog<String>(
      context: context,
      builder: (_) => const _InviteMemberDialog(),
    );
    if (rawName == null || rawName.isEmpty || !mounted) return;

    final email = rawName.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _showMessage('Enter a valid email address.');
      return;
    }

    try {
      final result = await widget.firestoreService.sendFamilyInvitation(
        sender: widget.currentUser,
        targetEmail: email,
      );
      if (!mounted) return;
      final message = switch (result) {
        FamilyInviteResult.sent =>
          'Request sent. They must accept before you are connected.',
        FamilyInviteResult.accountNotFound =>
          'No Beacon account was found for that email.',
        FamilyInviteResult.selfInvite => 'You cannot invite your own account.',
        FamilyInviteResult.alreadyPending => 'A request is already pending.',
        FamilyInviteResult.alreadyConnected =>
          'You are already in each other’s circle.',
      };
      _showMessage(message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'unavailable' ||
        'deadline-exceeded' =>
          'Could not reach Firestore. Check your internet connection and retry.',
        'permission-denied' =>
          'This usually means the invited person has not signed in to Beacon yet, or the latest Firestore rules are not deployed. Ask them to create their account first, then try again.',
        _ => 'Could not send request (${error.code}). Please retry.',
      };
      _showMessage(message);
    } catch (error) {
      if (mounted) _showMessage('Could not send request: $error');
    }
  }

  Future<void> _removeFamilyMember(FamilyContact member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from your circle?'),
        content:
            Text('This will remove ${member.name} from your family circle.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.firestoreService.removeFamilyConnection(
        userId: widget.userId,
        targetUid: member.id,
      );
      if (mounted) _showMessage('${member.name} was removed from your circle.');
    } catch (error) {
      if (mounted) _showMessage('Could not remove ${member.name}: $error');
    }
  }

  Future<void> _openFamilyMemberProfile(FamilyContact member) async {
    var profile = PublicUserProfile(
      uid: member.id,
      email: member.email,
      displayName: member.name,
    );
    if (member.email.isNotEmpty) {
      try {
        final fetched = await widget.firestoreService
            .findPublicProfileByEmail(member.email);
        if (fetched != null && fetched.uid == member.id) profile = fetched;
      } catch (_) {
        // The cached connection details still provide a usable profile.
      }
    }
    if (!mounted) return;

    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => MemberProfilePage(
        currentUser: widget.currentUser,
        profile: profile,
        firestoreService: widget.firestoreService,
      ),
    ));
  }

  Future<void> _openConversation(ChatConversation conversation) async {
    final profile = conversation.otherProfile(widget.currentUser.uid);
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ChatRoomPage(
        currentUser: widget.currentUser,
        chatId: conversation.id,
        otherProfile: PublicUserProfile(
          uid: profile['uid'] as String? ?? '',
          email: profile['email'] as String? ?? '',
          displayName: profile['displayName'] as String? ?? 'Beacon member',
          photoUrl: profile['photoURL'] as String? ?? '',
        ),
        firestoreService: widget.firestoreService,
      ),
    ));
  }

  Future<void> _addSafePlace() async {
    final locationService = widget.locationService;
    if (locationService == null) {
      _showMessage('Location is unavailable. Enable location access first.');
      return;
    }
    final lastKnown = locationService.lastKnownPosition;
    final initialCenter = lastKnown == null
        ? const LatLng(0, 0)
        : LatLng(lastKnown.latitude, lastKnown.longitude);

    final place = await Navigator.of(context).push<SafePlace>(
      MaterialPageRoute(
        builder: (_) => _SafePlacePickerPage(
          initialCenter: initialCenter,
          hasInitialCenter: lastKnown != null,
          locationService: locationService,
        ),
      ),
    );
    if (place == null || !mounted) return;
    try {
      await widget.firestoreService.saveSafePlace(widget.userId, place);
      if (mounted) _showMessage('${place.name} added to safe places.');
    } catch (error) {
      if (mounted) _showMessage('Could not save safe place: $error');
    }
  }

  Future<void> _deleteSafePlace(SafePlace place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove safe place?'),
        content: Text('Remove ${place.name} from your safe places?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.firestoreService.deleteSafePlace(
        userId: widget.userId,
        placeId: place.id,
      );
    } catch (error) {
      if (mounted) _showMessage('Could not remove safe place: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_showChats) {
      return StreamBuilder<List<ChatConversation>>(
        stream: _chatConversations,
        builder: (context, snapshot) {
          final conversations = snapshot.data ?? const <ChatConversation>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const PageHeading(
                eyebrow: 'Private and direct',
                title: 'Family chats',
                subtitle: 'Keep your circle close and connected.',
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Family')),
                  ButtonSegment(value: true, label: Text('Chats')),
                ],
                selected: {_showChats},
                onSelectionChanged: (selection) =>
                    setState(() => _showChats = selection.first),
              ),
              const SizedBox(height: 16),
              if (snapshot.hasError)
                const SurfacePanel(
                  child: Text('Could not load chats. Check your connection.'),
                )
              else if (conversations.isEmpty)
                const SurfacePanel(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 42, color: BeaconColors.muted),
                        SizedBox(height: 12),
                        Text(
                          'No family messages yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: BeaconColors.ink,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Messages with your circle will show up here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: BeaconColors.muted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SurfacePanel(
                  child: Column(
                    children: [
                      for (var index = 0;
                          index < conversations.length;
                          index++) ...[
                        if (index > 0)
                          const Divider(height: 1, color: BeaconColors.line),
                        _ChatListTile(
                          conversation: conversations[index],
                          currentUserId: widget.currentUser.uid,
                          onTap: () => _openConversation(conversations[index]),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SHARE ONLY WITH YOUR PEOPLE',
                    style: TextStyle(
                      color: BeaconColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Family circle',
                    style: TextStyle(
                      color: BeaconColors.ink,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _inviteMember,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: BeaconColors.line),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add,
                  color: BeaconColors.ink,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Family')),
            ButtonSegment(value: true, label: Text('Chats')),
          ],
          selected: {_showChats},
          onSelectionChanged: (selection) =>
              setState(() => _showChats = selection.first),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: BeaconColors.forest,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: BeaconColors.lime, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'LOCATION SHARING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _sharingEnabled ? 'Sharing is on' : 'Sharing is off',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _sharingEnabled
                    ? 'Your circle can see your latest location while tracking is active.'
                    : 'You decide when your circle can see your location.',
                style: const TextStyle(
                  color: Color(0xFFBDD1C8),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Share my location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: _sharingEnabled,
                    onChanged: _savingSharing ? null : _setSharing,
                    activeThumbColor: BeaconColors.ink,
                    activeTrackColor: BeaconColors.lime,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            const Expanded(
              child: Text(
                'YOUR CIRCLE',
                style: TextStyle(
                  color: BeaconColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: _inviteMember,
              style: TextButton.styleFrom(
                foregroundColor: BeaconColors.ink,
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                'Invite',
                style: TextStyle(
                  color: BeaconColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<FamilyContact>>(
          stream: _familyContacts,
          builder: (context, snapshot) {
            final members = snapshot.data ?? const <FamilyContact>[];
            if (snapshot.hasError) {
              return const SurfacePanel(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'Could not load your circle. Check your connection.'),
                ),
              );
            }
            if (members.isEmpty) {
              return const SurfacePanel(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Accepted connections will appear here.'),
                ),
              );
            }

            final rows = <Widget>[];
            for (var index = 0; index < members.length; index++) {
              final member = members[index];
              rows.add(
                _FamilyMember(
                  name: member.name,
                  email: member.email,
                  isYou: member.id == widget.currentUser.uid,
                  emergencyActive: member.emergencyActive &&
                      (member.emergencyExpiresAt == null ||
                          member.emergencyExpiresAt!.isAfter(DateTime.now())),
                  locationUpdatedAt: member.emergencyActive
                      ? member.emergencyUpdatedAt
                      : member.locationUpdatedAt,
                  latitude: member.latitude,
                  longitude: member.longitude,
                  onTap: () => _openFamilyMemberProfile(member),
                  onRemove: () => _removeFamilyMember(member),
                ),
              );
              if (index < members.length - 1) {
                rows.add(const Divider(height: 1, color: BeaconColors.line));
              }
            }

            return SurfacePanel(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(children: rows),
              ),
            );
          },
        ),
        const SizedBox(height: 22),
        const Text(
          'SAFE PLACES',
          style: TextStyle(
            color: BeaconColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<SafePlace>>(
          stream: _safePlaces,
          builder: (context, snapshot) {
            final places = snapshot.data ?? const <SafePlace>[];
            return SurfacePanel(
              child: Column(
                children: [
                  if (snapshot.hasError)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('Could not load safe places.'),
                    )
                  else if (places.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No safe places added',
                          style: TextStyle(color: BeaconColors.muted),
                        ),
                      ),
                    )
                  else
                    for (var index = 0; index < places.length; index++) ...[
                      if (index > 0)
                        const Divider(height: 1, color: BeaconColors.line),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9F0E3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.place_outlined,
                            color: BeaconColors.ink,
                          ),
                        ),
                        title: Text(
                          places[index].name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${places[index].radiusMeters.round()} m radius · ${_formatVisitTime(places[index].totalVisitSeconds)} total${widget.activeSafePlaceId == places[index].id ? ' · here now ${_formatVisitTime(widget.activeSafePlaceSeconds)}' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: BeaconColors.muted),
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove safe place',
                          onPressed: () => _deleteSafePlace(places[index]),
                          icon: const Icon(Icons.delete_outline),
                          color: BeaconColors.muted,
                        ),
                      ),
                    ],
                  const Divider(height: 1, color: BeaconColors.line),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E5DD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: BeaconColors.ink),
                    ),
                    title: const Text(
                      'Add a safe place',
                      style: TextStyle(
                        color: BeaconColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: BeaconColors.muted,
                    ),
                    onTap: _addSafePlace,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'ONLY ACCEPTED BEACON MEMBERS APPEAR IN YOUR CIRCLE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BeaconColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SafePlacePickerPage extends StatefulWidget {
  const _SafePlacePickerPage({
    required this.initialCenter,
    required this.hasInitialCenter,
    required this.locationService,
  });

  final LatLng initialCenter;
  final bool hasInitialCenter;
  final LocationService locationService;

  @override
  State<_SafePlacePickerPage> createState() => _SafePlacePickerPageState();
}

class _SafePlacePickerPageState extends State<_SafePlacePickerPage> {
  final TextEditingController _nameController = TextEditingController();
  final MapController _mapController = MapController();
  late LatLng _center = widget.initialCenter;
  late bool _hasSelectedCenter = widget.hasInitialCenter;
  bool _userSelectedCenter = false;
  double _radiusMeters = 150;

  @override
  void initState() {
    super.initState();
    if (!_hasSelectedCenter) _locateUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    final position = await widget.locationService.getCurrentPosition();
    if (!mounted || position == null || _userSelectedCenter) return;
    final target = LatLng(position.latitude, position.longitude);
    setState(() {
      _center = target;
      _hasSelectedCenter = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(target, 16);
    });
  }

  void _save() {
    if (!_hasSelectedCenter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for your location or tap the map.')),
      );
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name for this safe place.')),
      );
      return;
    }
    Navigator.of(context).pop(
      SafePlace(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        latitude: _center.latitude,
        longitude: _center.longitude,
        radiusMeters: _radiusMeters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add safe place'),
        actions: [
          IconButton(
            tooltip: 'Save safe place',
            onPressed: _hasSelectedCenter ? _save : null,
            icon: const Icon(Icons.check_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.hasInitialCenter ? 16 : 2,
              maxZoom: 20,
              onTap: (_, point) => setState(() {
                _userSelectedCenter = true;
                _hasSelectedCenter = true;
                _center = point;
              }),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.example.beacon',
                maxZoom: 20,
                maxNativeZoom: 17,
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _center,
                    radius: _radiusMeters,
                    useRadiusInMeter: true,
                    color: BeaconColors.lime.withValues(alpha: 0.3),
                    borderColor: BeaconColors.ink,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    width: 42,
                    height: 48,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: BeaconColors.coral,
                      size: 42,
                    ),
                  ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'Source: Esri, Vantor, Earthstar Geographics, and the GIS User Community',
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      decoration: const InputDecoration(
                        labelText: 'Place name',
                        border: InputBorder.none,
                        icon: Icon(Icons.place_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Material(
                  color: Colors.white,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Safe area radius',
                                style: TextStyle(
                                  color: BeaconColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${_radiusMeters.round()} m',
                              style: const TextStyle(
                                color: BeaconColors.forest,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _radiusMeters,
                          min: 50,
                          max: 500,
                          divisions: 18,
                          label: '${_radiusMeters.round()} m',
                          onChanged: (value) =>
                              setState(() => _radiusMeters = value),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _hasSelectedCenter ? _save : null,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Save safe place'),
                          ),
                        ),
                      ],
                    ),
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

class _FamilyMember extends StatelessWidget {
  const _FamilyMember({
    required this.name,
    required this.email,
    required this.isYou,
    this.emergencyActive = false,
    this.locationUpdatedAt,
    this.latitude,
    this.longitude,
    this.onTap,
    this.onRemove,
  });

  final String name;
  final String email;
  final bool isYou;
  final bool emergencyActive;
  final DateTime? locationUpdatedAt;
  final double? latitude;
  final double? longitude;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final label = emergencyActive
        ? 'SOS active · ${_relativeTime(locationUpdatedAt)}'
        : locationUpdatedAt != null
            ? 'Location shared · updated ${_relativeTime(locationUpdatedAt)}'
            : email.isNotEmpty
                ? email
                : (isYou ? 'You · organizer' : 'Member · location hidden');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isYou ? BeaconColors.lime : const Color(0xFFE8EEDB),
        foregroundColor: BeaconColors.ink,
        child:
            Text(name.isNotEmpty ? name.characters.first.toUpperCase() : 'F'),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        label,
        style: emergencyActive
            ? const TextStyle(
                color: BeaconColors.coral, fontWeight: FontWeight.w600)
            : null,
      ),
      onTap: onTap,
      trailing: isYou
          ? const Icon(Icons.person, size: 20, color: BeaconColors.muted)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!emergencyActive &&
                    locationUpdatedAt != null &&
                    latitude != null &&
                    longitude != null)
                  IconButton(
                    tooltip: 'View shared location',
                    onPressed: () => launchUrl(Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
                    )),
                    icon: const Icon(Icons.map_outlined),
                    color: BeaconColors.forest,
                  ),
                IconButton(
                  tooltip: 'Remove from circle',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  color: BeaconColors.coral,
                ),
              ],
            ),
    );
  }
}

class _ChatListTile extends StatelessWidget {
  const _ChatListTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  final ChatConversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = conversation.otherProfile(currentUserId);
    final displayName = profile['displayName'] as String? ?? 'Beacon member';
    final lastMessage = conversation.lastMessage.isEmpty
        ? 'Say hello to start chatting'
        : conversation.lastMessage;
    final initials = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'B';
    final badgeColor = conversation.hasUnreadFor(currentUserId)
        ? BeaconColors.lime
        : const Color(0xFFE9E7DD);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: badgeColor,
        foregroundColor: BeaconColors.ink,
        child:
            Text(initials, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            _formatChatTime(conversation.lastMessageAt),
            style: const TextStyle(color: BeaconColors.muted, fontSize: 12),
          ),
        ],
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: conversation.hasUnreadFor(currentUserId)
          ? Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: BeaconColors.lime,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}

String _formatVisitTime(int seconds) {
  final duration = Duration(seconds: seconds);
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  return '${duration.inMinutes}m';
}

String _formatChatTime(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  final difference = now.difference(value);
  if (difference.inDays == 0) {
    final time = value.toLocal();
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  if (difference.inDays == 1) return 'Yesterday';
  return '${value.day}/${value.month}';
}

String _relativeTime(DateTime? value) {
  if (value == null) return 'just now';
  final age = DateTime.now().difference(value);
  if (age.inMinutes < 1) return 'just now';
  if (age.inHours < 1) return '${age.inMinutes} min ago';
  if (age.inDays < 1) return '${age.inHours} hr ago';
  return '${age.inDays} days ago';
}

class _InviteMemberDialog extends StatefulWidget {
  const _InviteMemberDialog();

  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite a Beacon member'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        textCapitalization: TextCapitalization.none,
        decoration: const InputDecoration(
          labelText: 'Email address',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Send request'),
        ),
      ],
    );
  }
}
