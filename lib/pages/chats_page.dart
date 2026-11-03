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
        title: const Text('Messages',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Find a Beacon member',
            onPressed: _lookingUpPerson ? null : _findPerson,
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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            itemCount: conversations.length + 1,
            separatorBuilder: (_, index) => index == 0
                ? const SizedBox(height: 12)
                : const Divider(
                    height: 1, indent: 72, color: BeaconColors.line),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'RECENT CONVERSATIONS',
                        style: TextStyle(
                          color: BeaconColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text('${conversations.length}',
                        style: const TextStyle(color: BeaconColors.muted)),
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEDB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.forum_outlined,
                  color: BeaconColors.forest, size: 31),
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
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  final String name;
  final String photoUrl;
  final String lastMessage;
  final String time;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 7),
      leading: _BeaconAvatar(name: name, photoUrl: photoUrl, size: 52),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: unread ? BeaconColors.ink : BeaconColors.muted,
                fontWeight: unread ? FontWeight.w600 : FontWeight.normal)),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time,
              style: const TextStyle(color: BeaconColors.muted, fontSize: 11)),
          const SizedBox(height: 7),
          if (unread)
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: BeaconColors.coral, shape: BoxShape.circle)),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _BeaconAvatar extends StatelessWidget {
  const _BeaconAvatar(
      {required this.name, required this.photoUrl, required this.size});

  final String name;
  final String photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'B' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: BeaconColors.lime,
      foregroundColor: BeaconColors.ink,
      backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
      child: photoUrl.isEmpty
          ? Text(initial,
              style:
                  TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w700))
          : null,
    );
  }
}

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
