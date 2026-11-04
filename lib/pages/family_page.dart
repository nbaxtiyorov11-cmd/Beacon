import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
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
  late final Stream<List<FamilyContact>> _familyContacts;
  late final Stream<List<SafePlace>> _safePlaces;
  Timer? _alertExpiryTimer;

  @override
  void initState() {
    super.initState();
    _sharingEnabled = widget.familySharing;
    _familyContacts =
        widget.firestoreService.watchFamilyContacts(widget.userId);
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
                    'YOUR PEOPLE',
                    style: TextStyle(
                      color: BeaconColors.forest,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your trusted circle and places.',
                    style: TextStyle(
                      color: BeaconColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _inviteMember,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Invite'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BeaconColors.ink,
                side: const BorderSide(color: BeaconColors.line),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.fromLTRB(17, 16, 17, 14),
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
                      color: BeaconColors.lime.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: BeaconColors.lime,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location sharing',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Private to your accepted circle',
                          style: TextStyle(
                            color: Color(0xFFB8C7BD),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: _sharingEnabled
                          ? BeaconColors.lime.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _sharingEnabled ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: _sharingEnabled
                            ? BeaconColors.lime
                            : const Color(0xFFCFD9D2),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _sharingEnabled ? 'Sharing is on' : 'Sharing is off',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _sharingEnabled
                    ? 'Your circle can see your latest location while tracking is active.'
                    : 'Turn on sharing to let your circle see your location while tracking.',
                style: const TextStyle(
                  color: Color(0xFFCFD9D2),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0x334D7162), height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Share my location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: BeaconColors.blue.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: BeaconColors.forest,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Your circle',
                style: TextStyle(
                  color: BeaconColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
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
        const SizedBox(height: 24),
        const Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x1FE66E61),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.place_rounded,
                  color: BeaconColors.coral,
                  size: 20,
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Safe places',
                style: TextStyle(
                  color: BeaconColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: BeaconColors.coral.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.add_location_alt_outlined,
                              color: BeaconColors.coral,
                            ),
                          ),
                          const SizedBox(width: 11),
                          const Expanded(
                            child: Text(
                              'No safe places added',
                              style: TextStyle(color: BeaconColors.muted),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (var index = 0; index < places.length; index++) ...[
                      if (index > 0)
                        const Divider(height: 1, color: BeaconColors.line),
                      Builder(builder: (context) {
                        final place = places[index];
                        final active = widget.activeSafePlaceId == place.id;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: active
                                  ? BeaconColors.lime.withValues(alpha: 0.28)
                                  : BeaconColors.coral.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              active
                                  ? Icons.home_filled
                                  : Icons.place_outlined,
                              color: active
                                  ? BeaconColors.forest
                                  : BeaconColors.coral,
                            ),
                          ),
                          title: Text(
                            place.name,
                            style: const TextStyle(
                              color: BeaconColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${place.radiusMeters.round()} m radius · ${_formatVisitTime(place.totalVisitSeconds)} total${active ? ' · here now ${_formatVisitTime(widget.activeSafePlaceSeconds)}' : ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: BeaconColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (active)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE7F1DE),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'HERE',
                                    style: TextStyle(
                                      color: BeaconColors.forest,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Remove safe place',
                                onPressed: () => _deleteSafePlace(place),
                                icon: const Icon(Icons.delete_outline),
                                color: BeaconColors.muted,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  const Divider(height: 16, color: BeaconColors.line),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _addSafePlace,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Add a safe place'),
                      style: FilledButton.styleFrom(
                        foregroundColor: BeaconColors.forest,
                        backgroundColor: const Color(0xFFE7F1DE),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
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
                          min: 20,
                          max: 500,
                          divisions: 48,
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
    final avatarColor = emergencyActive
      ? BeaconColors.coral
      : locationUpdatedAt != null
        ? BeaconColors.blue
        : isYou
          ? BeaconColors.forest
          : BeaconColors.ink;
    final avatarBackground = emergencyActive
      ? BeaconColors.coral.withValues(alpha: 0.15)
      : locationUpdatedAt != null
        ? BeaconColors.blue.withValues(alpha: 0.18)
        : const Color(0xFFE9EEE8);
    final label = emergencyActive
        ? 'SOS active · ${_relativeTime(locationUpdatedAt)}'
        : locationUpdatedAt != null
            ? 'Location shared · updated ${_relativeTime(locationUpdatedAt)}'
            : email.isNotEmpty
                ? email
                : (isYou ? 'You · organizer' : 'Member · location hidden');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 3),
      leading: SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: avatarBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                name.isNotEmpty ? name.characters.first.toUpperCase() : 'F',
                style: TextStyle(
                  color: avatarColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (emergencyActive || locationUpdatedAt != null)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: emergencyActive ? BeaconColors.coral : BeaconColors.forest,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          color: BeaconColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        label,
        style: emergencyActive
            ? const TextStyle(
                color: BeaconColors.coral, fontWeight: FontWeight.w600)
            : const TextStyle(color: BeaconColors.muted, fontSize: 12),
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

String _formatVisitTime(int seconds) {
  final duration = Duration(seconds: seconds);
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  return '${duration.inMinutes}m';
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
