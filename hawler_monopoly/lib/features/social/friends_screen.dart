import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/online/api_client.dart';
import '../../../data/online/chat_repository.dart';
import '../../../domain/models/chat_models.dart';
import '../board/widgets/player_token.dart';

/// شاشەی هاوڕێکان — لیستی هاوڕێکان، زیادکردنی هاوڕێ، و گفتوگۆ.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _repo = ChatRepository.instance;
  StreamSubscription<List<FriendProfile>>? _sub;
  List<FriendProfile> _friends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sub = _repo.watchFriends().listen((f) {
      if (!mounted) return;
      setState(() {
        _friends = f;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _showAddFriendDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.night2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('زیادکردنی هاوڕێ', style: AppTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ناسنامەی (ID) هاوڕێکەت بنووسە بۆ ناردنی داواکاری:', style: AppTextStyles.bodySoft),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'ناسنامەی یاریزان (User ID)',
                hintStyle: AppTextStyles.caption,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('داخستن', style: AppTextStyles.caption),
          ),
          TextButton(
            onPressed: () async {
              final id = controller.text.trim();
              if (id.isEmpty) return;
              Navigator.pop(ctx);
              final res = await _repo.addFriend(id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(res.ok ? 'داواکاری هاوڕێیەتی نێردرا! 🎉' : (res.error ?? 'هەڵەیەک ڕوویدا'))),
              );
            },
            child: Text('ناردنی داواکاری', style: AppTextStyles.goldLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxuryBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    CircleIconButton(icon: Icons.arrow_forward, onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    Text('هاوڕێکان', style: AppTextStyles.h2),
                    const Spacer(),
                    CircleIconButton(
                      icon: Icons.person_add,
                      onTap: _showAddFriendDialog,
                    ),
                    const SizedBox(width: 8),
                    Text('${_friends.length} هاوڕێ', style: AppTextStyles.goldLabel),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _loading && _friends.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                    : _friends.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, color: AppColors.gold.withValues(alpha: 0.3), size: 50),
                                const SizedBox(height: 12),
                                Text('هیچ هاوڕێیەک نییە', style: AppTextStyles.bodySoft),
                                const SizedBox(height: 8),
                                Text('هاوڕێ زیاد بکە بۆ گفتوگۆکردن', style: AppTextStyles.caption),
                                const SizedBox(height: 16),
                                GoldenButton(
                                  label: 'زیادکردنی هاوڕێ',
                                  icon: Icons.person_add,
                                  width: 170,
                                  height: 42,
                                  fontSize: 13,
                                  onTap: _showAddFriendDialog,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: _friends.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) => _friendTile(_friends[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _friendTile(FriendProfile friend) {
    final isOnline = friend.status == FriendOnlineStatus.online;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FriendChatScreen(friend: friend),
        ));
      },
      child: GlassContainer(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderColor: friend.unreadCount > 0 ? AppColors.gold.withValues(alpha: 0.5) : AppColors.glassBorder,
        child: Row(
          children: [
            Stack(
              children: [
                PlayerToken(
                  color: isOnline ? AppColors.emerald : AppColors.glassBorder,
                  icon: Icons.person,
                  size: 40,
                  isActive: isOnline,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.success : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.night, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(friend.name, style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    isOnline ? 'ئۆنلاین' : 'ئۆفلاین',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: isOnline ? AppColors.success : AppColors.parchment.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (friend.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${friend.unreadCount}', style: AppTextStyles.caption.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_left, color: AppColors.parchment, size: 18),
          ],
        ),
      ),
    );
  }
}

/// شاشەی گفتوگۆی تایبەت نێوان دوو هاوڕێ.
class FriendChatScreen extends StatefulWidget {
  final FriendProfile friend;
  const FriendChatScreen({super.key, required this.friend});

  @override
  State<FriendChatScreen> createState() => _FriendChatScreenState();
}

class _FriendChatScreenState extends State<FriendChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _repo = ChatRepository.instance;
  bool _showEmoji = false;
  StreamSubscription<List<FriendMessage>>? _sub;
  List<FriendMessage> _messages = [];

  static const _quickEmojis = ['👏', '😂', '🔥', '❤️', '😱', '😡', '🎉', '👍', '👎', '😮', '💀', '🏆', '💰', '🎲', '✨', '🤝'];

  @override
  void initState() {
    super.initState();
    _repo.markFriendMessagesRead(widget.friend.id);
    _sub = _repo.watchFriendMessages(widget.friend.id).listen((msgs) {
      if (!mounted) return;
      setState(() => _messages = msgs);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _repo.sendFriendMessage(widget.friend.id, text);
    _controller.clear();
    setState(() => _showEmoji = false);
  }

  void _sendEmoji(String emoji) {
    _repo.sendFriendMessage(widget.friend.id, '', emoji: emoji);
    setState(() => _showEmoji = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxuryBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    CircleIconButton(icon: Icons.arrow_forward, onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    const PlayerToken(color: AppColors.emerald, icon: Icons.person, size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.friend.name, style: AppTextStyles.titleMedium),
                          Text(
                            widget.friend.status == FriendOnlineStatus.online ? 'ئۆنلاین' : 'ئۆفلاین',
                            style: AppTextStyles.caption.copyWith(
                              color: widget.friend.status == FriendOnlineStatus.online
                                  ? AppColors.success
                                  : AppColors.parchment.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: AppColors.glassBorder, height: 1),
              // Messages
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_outlined, color: AppColors.gold.withValues(alpha: 0.3), size: 40),
                            const SizedBox(height: 8),
                            Text('گفتوگۆی تۆ بۆ ${widget.friend.name}', style: AppTextStyles.caption),
                            const SizedBox(height: 4),
                            Text('نامەیەک بنووسە', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) => _messageBubble(_messages[i]),
                      ),
              ),
              // Emoji Selector
              if (_showEmoji)
                Container(
                  height: 110,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.night2.withValues(alpha: 0.95),
                    border: Border(top: BorderSide(color: AppColors.glassBorder)),
                  ),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8, mainAxisSpacing: 4, crossAxisSpacing: 4,
                    ),
                    itemCount: _quickEmojis.length,
                    itemBuilder: (context, i) => GestureDetector(
                      onTap: () => _sendEmoji(_quickEmojis[i]),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(_quickEmojis[i], style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                ),
              // Input bar
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: AppColors.night2.withValues(alpha: 0.95),
                  border: Border(top: BorderSide(color: AppColors.glassBorder)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _showEmoji = !_showEmoji),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _showEmoji ? AppColors.gold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _showEmoji ? AppColors.gold : AppColors.glassBorder),
                        ),
                        alignment: Alignment.center,
                        child: const Text('😊', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: TextField(
                          controller: _controller,
                          style: AppTextStyles.body,
                          maxLength: 500,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendText(),
                          decoration: InputDecoration(
                            hintText: 'نامەیەک بنووسە...',
                            hintStyle: AppTextStyles.caption,
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendText,
                      child: Container(
                        width: 40, height: 40,
                        decoration: const BoxDecoration(
                          gradient: AppColors.goldGradient,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.send, color: AppColors.night, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageBubble(FriendMessage msg) {
    final isMe = msg.senderId == ApiClient.instance.currentUserId;
    final time = DateTime.fromMillisecondsSinceEpoch(msg.timestamp);
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    if (msg.isEmoji) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [Text(msg.emoji!, style: const TextStyle(fontSize: 36))],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.sapphire.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(widget.friend.name.isNotEmpty ? widget.friend.name.substring(0, 1) : '؟',
                style: const TextStyle(fontSize: 11, color: AppColors.ivory)),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? AppColors.gold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMe ? 14 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 14),
                ),
                border: Border.all(
                  color: isMe ? AppColors.gold.withValues(alpha: 0.3) : AppColors.glassBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.text, style: AppTextStyles.body.copyWith(fontSize: 13)),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isMe && msg.read)
                          const Icon(Icons.done_all, size: 12, color: AppColors.info),
                        Text(timeStr, style: AppTextStyles.caption.copyWith(fontSize: 8)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
