import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/beacon_theme.dart';
import 'chat_room_page.dart';

class MemberProfilePage extends StatefulWidget {
  const MemberProfilePage({
    required this.currentUser,
    required this.profile,
    required this.firestoreService,
    super.key,
  });

  final AuthUser currentUser;
  final PublicUserProfile profile;
  final FirestoreService firestoreService;

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage> {
  late final Future<PublicActivityStats> _stats;
  bool _openingChat = false;

  @override
  void initState() {
    super.initState();
    _stats =
        widget.firestoreService.fetchPublicActivityStats(widget.profile.uid);
  }

  Future<void> _startChat() async {
    setState(() => _openingChat = true);
    try {
      final chatId = await widget.firestoreService.openOrCreateChat(
        currentUser: widget.currentUser,
        otherUser: widget.profile,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          currentUser: widget.currentUser,
          chatId: chatId,
          otherProfile: widget.profile,
          firestoreService: widget.firestoreService,
        ),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open this conversation. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final name = profile.displayName.trim().isEmpty
        ? 'Beacon member'
        : profile.displayName.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Member profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            decoration: BoxDecoration(
              color: BeaconColors.ink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: BeaconColors.lime.withValues(alpha: 0.8),
                        width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 43,
                    backgroundColor: BeaconColors.lime,
                    foregroundColor: BeaconColors.ink,
                    backgroundImage: profile.photoUrl.isEmpty
                        ? null
                        : NetworkImage(profile.photoUrl),
                    child: profile.photoUrl.isEmpty
                        ? Text(name[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w700))
                        : null,
                  ),
                ),
                const SizedBox(height: 15),
                Text(name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text(profile.email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFB8C7BD), fontSize: 13)),
                const SizedBox(height: 17),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openingChat ? null : _startChat,
                    style: FilledButton.styleFrom(
                      backgroundColor: BeaconColors.lime,
                      foregroundColor: BeaconColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _openingChat
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(
                        _openingChat ? 'Opening chat...' : 'Start chatting'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text('ACTIVITY AT A GLANCE',
              style: TextStyle(
                  color: BeaconColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 11),
          FutureBuilder<PublicActivityStats>(
            future: _stats,
            builder: (context, snapshot) {
              final stats = snapshot.data ?? const PublicActivityStats();
              return Row(
                children: [
                  Expanded(
                      child: _StatColumn(
                    icon: Icons.route_outlined,
                    value: '${stats.tripCount}',
                    label: 'TRIPS',
                    tint: BeaconColors.blue,
                  )),
                  const SizedBox(width: 9),
                  Expanded(
                      child: _StatColumn(
                    icon: Icons.straighten_rounded,
                    value:
                        '${(stats.distanceMeters / 1000).toStringAsFixed(stats.distanceMeters >= 10000 ? 0 : 1)} km',
                    label: 'DISTANCE',
                    tint: BeaconColors.coral,
                  )),
                  const SizedBox(width: 9),
                  Expanded(
                      child: _StatColumn(
                    icon: Icons.schedule_rounded,
                    value: _formatMinutes(stats.movingMinutes),
                    label: 'MOVING',
                    tint: BeaconColors.forest,
                  )),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          const Text(
            'Only summary totals are shared here. Routes and precise location stay private.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: BeaconColors.muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 27),
          const Divider(color: BeaconColors.line),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 18, color: BeaconColors.forest),
              SizedBox(width: 9),
              Expanded(
                  child: Text('Beacon member profile',
                      style: TextStyle(
                          color: BeaconColors.forest,
                          fontWeight: FontWeight.w600))),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn(
      {required this.icon,
      required this.value,
      required this.label,
      required this.tint});

  final IconData icon;
  final String value;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BeaconColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 20),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    color: BeaconColors.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  color: BeaconColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

String _formatMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return remainingMinutes == 0 ? '${hours}h' : '${hours}h ${remainingMinutes}m';
}
