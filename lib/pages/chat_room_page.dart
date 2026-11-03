import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/beacon_theme.dart';

class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({
    required this.currentUser,
    required this.chatId,
    required this.otherProfile,
    required this.firestoreService,
    super.key,
  });

  final AuthUser currentUser;
  final String chatId;
  final PublicUserProfile otherProfile;
  final FirestoreService firestoreService;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  static const _quickEmojis = [
    '🙂',
    '❤️',
    '😂',
    '🎉',
    '👏',
    '👍',
    '🙏',
    '✨',
    '🔥',
    '🥰',
    '🤔',
    '🙌'
  ];

  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  late final Stream<List<ChatMessage>> _messages;
  late final Stream<ChatConversation?> _conversation;
  ChatMessage? _replyingTo;
  bool _emojiTrayOpen = false;
  String? _markedLatestMessage;

  @override
  void initState() {
    super.initState();
    _messages = widget.firestoreService.watchChatMessages(widget.chatId);
    _conversation =
        widget.firestoreService.watchChatConversation(widget.chatId);
    unawaited(_markRead());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await widget.firestoreService.markChatRead(
        chatId: widget.chatId,
        readerUid: widget.currentUser.uid,
      );
    } catch (_) {
      // The stream remains usable if updating a read marker fails temporarily.
    }
  }

  void _insertEmoji(String emoji) {
    final value = _messageController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final text = value.text.replaceRange(start, end, emoji);
    _messageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    _focusNode.requestFocus();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final reply = _replyingTo;
    _messageController.clear();
    setState(() {
      _replyingTo = null;
      _emojiTrayOpen = false;
    });

    try {
      await widget.firestoreService.sendChatMessage(
        chatId: widget.chatId,
        senderUid: widget.currentUser.uid,
        text: text,
        replyToMessageId: reply?.id,
        replyToText: reply?.text,
        replyToSenderUid: reply?.senderUid,
      );
      _scrollToLatest();
    } catch (_) {
      if (!mounted) return;
      _messageController.text = text;
      setState(() => _replyingTo = reply);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Message was not sent. Check your connection and retry.')),
      );
    }
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: BeaconColors.paper,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('React to this message',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _quickEmojis
                    .map((emoji) => IconButton(
                          tooltip: emoji,
                          onPressed: () =>
                              Navigator.pop(context, 'emoji:$emoji'),
                          icon:
                              Text(emoji, style: const TextStyle(fontSize: 24)),
                        ))
                    .toList(),
              ),
              const Divider(height: 20),
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'reply') {
      setState(() => _replyingTo = message);
      _focusNode.requestFocus();
      return;
    }
    if (choice.startsWith('emoji:')) {
      await widget.firestoreService.setChatMessageReaction(
        chatId: widget.chatId,
        messageId: message.id,
        userId: widget.currentUser.uid,
        emoji: choice.substring('emoji:'.length),
      );
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.otherProfile.displayName.trim().isEmpty
        ? 'Beacon member'
        : widget.otherProfile.displayName.trim();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _ChatAvatar(
                name: name, photoUrl: widget.otherProfile.photoUrl, radius: 18),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const Text('Beacon member',
                      style:
                          TextStyle(fontSize: 11, color: BeaconColors.muted)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Conversation details',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (context) => SafeArea(
                child: ListTile(
                  leading: const Icon(Icons.alternate_email),
                  title: Text(widget.otherProfile.email),
                  subtitle: const Text('Direct conversation'),
                ),
              ),
            ),
            icon: const Icon(Icons.more_horiz_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<ChatConversation?>(
              stream: _conversation,
              builder: (context, snapshot) {
                final conversation = snapshot.data;
                final otherUid = widget.otherProfile.uid;
                final otherReadAt = conversation?.lastReadAt[otherUid];
                return StreamBuilder<List<ChatMessage>>(
                  stream: _messages,
                  builder: (context, messageSnapshot) {
                    if (messageSnapshot.hasError) {
                      return const Center(
                          child: Text(
                              'Messages could not load. Check your connection.'));
                    }
                    if (messageSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !messageSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages =
                        messageSnapshot.data ?? const <ChatMessage>[];
                    if (messages.isEmpty) return _FirstMessage(name: name);
                    final latestId = messages.last.id;
                    if (_markedLatestMessage != latestId) {
                      _markedLatestMessage = latestId;
                      unawaited(_markRead());
                      _scrollToLatest();
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final own = message.senderUid == widget.currentUser.uid;
                        final previous = index > 0 ? messages[index - 1] : null;
                        final showDay = previous == null ||
                            !_sameDay(previous.createdAt, message.createdAt);
                        return Column(
                          children: [
                            if (showDay) _DayDivider(date: message.createdAt),
                            _MessageBubble(
                              message: message,
                              own: own,
                              isLatest: index == messages.length - 1,
                              otherReadAt: otherReadAt,
                              onLongPress: () => _showMessageActions(message),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _messageController,
            focusNode: _focusNode,
            replyingTo: _replyingTo,
            emojiTrayOpen: _emojiTrayOpen,
            onToggleEmojiTray: () =>
                setState(() => _emojiTrayOpen = !_emojiTrayOpen),
            onEmojiSelected: _insertEmoji,
            onCancelReply: () => setState(() => _replyingTo = null),
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.replyingTo,
    required this.emojiTrayOpen,
    required this.onToggleEmojiTray,
    required this.onEmojiSelected,
    required this.onCancelReply,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ChatMessage? replyingTo;
  final bool emojiTrayOpen;
  final VoidCallback onToggleEmojiTray;
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyingTo != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
                color: BeaconColors.paper,
                child: Row(
                  children: [
                    Container(width: 3, height: 34, color: BeaconColors.coral),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Replying to message',
                            style: TextStyle(
                                color: BeaconColors.forest,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        Text(replyingTo!.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: BeaconColors.muted, fontSize: 12)),
                      ],
                    )),
                    IconButton(
                        onPressed: onCancelReply,
                        icon: const Icon(Icons.close, size: 18)),
                  ],
                ),
              ),
            if (emojiTrayOpen)
              SizedBox(
                height: 52,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  scrollDirection: Axis.horizontal,
                  itemCount: _ChatRoomPageState._quickEmojis.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) => IconButton(
                    onPressed: () =>
                        onEmojiSelected(_ChatRoomPageState._quickEmojis[index]),
                    icon: Text(_ChatRoomPageState._quickEmojis[index],
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: emojiTrayOpen ? 'Hide emojis' : 'Add emoji',
                    onPressed: onToggleEmojiTray,
                    icon: Icon(
                        emojiTrayOpen
                            ? Icons.keyboard_rounded
                            : Icons.emoji_emotions_outlined,
                        color: BeaconColors.forest),
                  ),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 130),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 4000,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Write a message',
                          counterText: '',
                          filled: true,
                          fillColor: BeaconColors.paper,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: onSend,
                    style: IconButton.styleFrom(
                        backgroundColor: BeaconColors.ink,
                        foregroundColor: BeaconColors.lime),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.own,
    required this.isLatest,
    required this.otherReadAt,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool own;
  final bool isLatest;
  final DateTime? otherReadAt;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isRead = own &&
        isLatest &&
        otherReadAt != null &&
        message.createdAt != null &&
        !otherReadAt!.isBefore(message.createdAt!);
    final alignment = own ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = own ? BeaconColors.ink : Colors.white;
    final textColor = own ? Colors.white : BeaconColors.ink;
    final reactions = message.reactions.values.toSet().toList();
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: alignment,
            children: [
              GestureDetector(
                onLongPress: onLongPress,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(17),
                      topRight: const Radius.circular(17),
                      bottomLeft: Radius.circular(own ? 17 : 5),
                      bottomRight: Radius.circular(own ? 5 : 17),
                    ),
                    border: own ? null : Border.all(color: BeaconColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if ((message.replyToText ?? '').isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                          decoration: BoxDecoration(
                            color: own
                                ? Colors.white.withValues(alpha: 0.12)
                                : BeaconColors.paper,
                            borderRadius: BorderRadius.circular(5),
                            border: Border(
                                left: BorderSide(
                                    color: own
                                        ? BeaconColors.lime
                                        : BeaconColors.coral,
                                    width: 2)),
                          ),
                          child: Text(message.replyToText!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color:
                                      own ? Colors.white70 : BeaconColors.muted,
                                  fontSize: 11)),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(message.text,
                            style: TextStyle(
                                color: textColor, fontSize: 15, height: 1.3)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_formatMessageTime(message.createdAt),
                              style: TextStyle(
                                  color:
                                      own ? Colors.white70 : BeaconColors.muted,
                                  fontSize: 10)),
                          if (own && isLatest) ...[
                            const SizedBox(width: 4),
                            Icon(
                              isRead
                                  ? Icons.done_all_rounded
                                  : Icons.check_rounded,
                              size: 13,
                              color:
                                  isRead ? BeaconColors.lime : Colors.white70,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Wrap(
                    spacing: 4,
                    children: reactions
                        .map((emoji) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: BeaconColors.line),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstMessage extends StatelessWidget {
  const _FirstMessage({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.waving_hand_rounded,
                color: BeaconColors.coral, size: 30),
            const SizedBox(height: 12),
            Text('Say hello to $name',
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: BeaconColors.ink)),
            const SizedBox(height: 6),
            const Text('Your messages are private to this conversation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BeaconColors.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar(
      {required this.name, required this.photoUrl, required this.radius});

  final String name;
  final String photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: BeaconColors.lime,
      foregroundColor: BeaconColors.ink,
      backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
      child: photoUrl.isEmpty
          ? Text(name.trim().isEmpty ? 'B' : name.trim()[0].toUpperCase())
          : null,
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final label = date == null ? 'Today' : _formatDay(date!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider(color: BeaconColors.line)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(label,
                  style: const TextStyle(
                      color: BeaconColors.muted, fontSize: 11))),
          const Expanded(child: Divider(color: BeaconColors.line)),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime? first, DateTime? second) {
  if (first == null || second == null) return first == second;
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _formatDay(DateTime date) {
  final now = DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) {
    return 'Today';
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  return '${date.day}/${date.month}/${date.year}';
}

String _formatMessageTime(DateTime? date) {
  if (date == null) return 'Sending';
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
