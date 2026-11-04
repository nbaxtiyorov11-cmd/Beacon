import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/beacon_theme.dart';
import 'chat_room_page.dart';
import 'member_profile_page.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({
    required this.currentUser,
    required this.firestoreService,
    super.key,
  });

  final AuthUser currentUser;
  final FirestoreService firestoreService;

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  late final Stream<List<ChatConversation>> _conversations;
  bool _lookingUpPerson = false;

  @override
  void initState() {
    super.initState();
    _conversations = widget.firestoreService.watchChatConversations(
      widget.currentUser.uid,
    );
  }

  Future<void> _findPerson() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) => const _FindPersonDialog(),
    );
    if (email == null || email.trim().isEmpty || !mounted) return;

    setState(() => _lookingUpPerson = true);
    try {
      final profile =
          await widget.firestoreService.findPublicProfileByEmail(email);
      if (!mounted) return;
      if (profile == null) {
        _showMessage('No Beacon profile was found for that email.');
        return;
      }
      if (profile.uid == widget.currentUser.uid) {
        _showMessage('That is your own account.');
        return;
      }
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => MemberProfilePage(
          currentUser: widget.currentUser,
          profile: profile,
          firestoreService: widget.firestoreService,
        ),
      ));
    } catch (_) {
      if (mounted) {
        _showMessage(
            'Could not find that profile. Check your connection and retry.');
      }
    } finally {
      if (mounted) setState(() => _lookingUpPerson = false);
    }
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

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: BeaconColors.paper,
        scrolledUnderElevation: 0,
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
                  Icons.forum_rounded,
                  color: BeaconColors.forest,
                  size: 19,
                ),
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR CIRCLE',
                  style: TextStyle(
                    color: BeaconColors.forest,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Messages',
                  style: TextStyle(
                    color: BeaconColors.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Find a Beacon member',
            onPressed: _lookingUpPerson ? null : _findPerson,
            style: IconButton.styleFrom(
              foregroundColor: BeaconColors.forest,
              backgroundColor: const Color(0xFFE7EEE9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            icon: _lookingUpPerson
                ? const SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_search_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<ChatConversation>>(
        stream: _conversations,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Could not load messages. Try again shortly.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final conversations = snapshot.data ?? const <ChatConversation>[];
          if (conversations.isEmpty) {
            return _EmptyChats(onFindPerson: _findPerson);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: conversations.length + 1,
            separatorBuilder: (_, index) => index == 0
                ? const SizedBox(height: 10)
                : const SizedBox(height: 6),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent conversations',
                        style: TextStyle(
                          color: BeaconColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7EEE9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${conversations.length}',
                        style: const TextStyle(
                          color: BeaconColors.forest,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                );
              }
              final conversation = conversations[index - 1];
              final other = conversation.otherProfile(widget.currentUser.uid);
              final name = other['displayName'] as String? ?? 'Beacon member';
              final unread = conversation.hasUnreadFor(widget.currentUser.uid);
              return _ConversationTile(
                name: name,
                photoUrl: other['photoURL'] as String? ?? '',
                accent: _chatAccents[(index - 1) % _chatAccents.length],
                lastMessage: conversation.lastMessage.isEmpty
                    ? 'Say hello to start chatting'
                    : conversation.lastMessage,
                time: _formatConversationTime(conversation.lastMessageAt),
                unread: unread,
                onTap: () => _openConversation(conversation),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats({required this.onFindPerson});

  final VoidCallback onFindPerson;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE7EEE9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.forum_rounded,
                  color: BeaconColors.forest, size: 28),
            ),
            const SizedBox(height: 18),
            const Text(
              'Good conversations start here',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: BeaconColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Find a Beacon member by email to view their profile and say hello.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BeaconColors.muted, height: 1.4),
            ),
            const SizedBox(height: 19),
            FilledButton.icon(
              onPressed: onFindPerson,
              icon: const Icon(Icons.person_search_outlined),
              label: const Text('Find a person'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.name,
    required this.photoUrl,
    required this.accent,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  final String name;
  final String photoUrl;
  final Color accent;
  final String lastMessage;
  final String time;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 12, 12, 12),
          child: Row(
            children: [
              _BeaconAvatar(
                name: name,
                photoUrl: photoUrl,
                size: 50,
                accent: accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: BeaconColors.ink,
                        fontWeight:
                            unread ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unread ? BeaconColors.forest : BeaconColors.muted,
                        fontSize: 12,
                        fontWeight:
                            unread ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      color: BeaconColors.muted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (unread)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: BeaconColors.coral,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeaconAvatar extends StatelessWidget {
  const _BeaconAvatar(
  {required this.name,
  required this.photoUrl,
  required this.size,
  required this.accent});

  final String name;
  final String photoUrl;
  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'B' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(15),
        image: photoUrl.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(photoUrl),
                fit: BoxFit.cover,
              ),
      ),
      alignment: Alignment.center,
      child: photoUrl.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                color: accent,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

const _chatAccents = [
  BeaconColors.blue,
  BeaconColors.coral,
  BeaconColors.forest,
  Color(0xFF8F9D61),
];

class _FindPersonDialog extends StatefulWidget {
  const _FindPersonDialog();

  @override
  State<_FindPersonDialog> createState() => _FindPersonDialogState();
}

class _FindPersonDialogState extends State<_FindPersonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Find a Beacon member'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        textCapitalization: TextCapitalization.none,
        decoration: const InputDecoration(
          labelText: 'Email address',
          prefixIcon: Icon(Icons.alternate_email),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('View profile')),
      ],
    );
  }
}

String _formatConversationTime(DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  return '${date.day}/${date.month}';
}
