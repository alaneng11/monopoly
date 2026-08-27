import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/models/chat_models.dart';
import '../../../data/online/chat_repository.dart';

/// پانێڵی گفتوگۆی ناو یاری — نامە و ئێمۆژی لەگەڵ هاوبەشکردنی کۆی.
class GameChatPanel extends StatefulWidget {
  final String gameRoomId;
  final String myId;
  final String myName;

  const GameChatPanel({
    super.key,
    required this.gameRoomId,
    required this.myId,
    required this.myName,
  });

  @override
  State<GameChatPanel> createState() => _GameChatPanelState();
}

class _GameChatPanelState extends State<GameChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _repo = ChatRepository.instance;
  bool _showEmoji = false;
  StreamSubscription<List<GameChatMessage>>? _sub;
  List<GameChatMessage> _messages = [];

  static const _quickEmojis = ['👏', '😂', '🔥', '❤️', '😱', '😡', '🎉', '👍', '👎', '😮', '💀', '🏆'];

  @override
  void initState() {
    super.initState();
    _sub = _repo.watchGameMessages(widget.gameRoomId).listen((msgs) {
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
    _repo.sendGameMessage(widget.gameRoomId, text);
    _controller.clear();
    setState(() => _showEmoji = false);
  }

  void _sendEmoji(String emoji) {
    _repo.sendGameMessage(widget.gameRoomId, '', emoji: emoji);
    setState(() => _showEmoji = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        gradient: AppColors.royalBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // هێستەر
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(4)),
          ),
          // سەرناو
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, color: AppColors.gold, size: 22),
                const SizedBox(width: 8),
                Text('گفتوگۆی یاری', style: AppTextStyles.h3),
                const Spacer(),
                CircleIconButton(icon: Icons.close, size: 34, onTap: () => Navigator.pop(context)),
              ],
            ),
          ),
          Divider(color: AppColors.glassBorder, height: 1),
          // لیستی نامەکان
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_outlined, color: AppColors.gold.withValues(alpha: 0.3), size: 40),
                        const SizedBox(height: 8),
                        Text('هیچ نامەیەک نییە', style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text('نامەیەک بنووسە یان ئێمۆژی بنێرە', style: AppTextStyles.caption.copyWith(fontSize: 10)),
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
          // ئێمۆژی سیکر
          if (_showEmoji)
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.night2.withValues(alpha: 0.9),
                border: Border(top: BorderSide(color: AppColors.glassBorder)),
              ),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
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
          // ناوەڕۆکی ناردن
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
                    width: 40,
                    height: 40,
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
                      maxLength: 200,
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
                    width: 40,
                    height: 40,
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
    );
  }

  Widget _messageBubble(GameChatMessage msg) {
    final isMe = msg.senderId == widget.myId;
    final time = DateTime.fromMillisecondsSinceEpoch(msg.timestamp);
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    if (msg.isEmoji) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(msg.senderName, style: AppTextStyles.caption.copyWith(fontSize: 9)),
              const SizedBox(width: 6),
            ],
            Text(msg.emoji!, style: const TextStyle(fontSize: 36)),
            if (isMe) ...[
              const SizedBox(width: 6),
              Text(msg.senderName, style: AppTextStyles.caption.copyWith(fontSize: 9)),
            ],
          ],
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
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.sapphire.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(msg.senderName.isNotEmpty ? msg.senderName.substring(0, 1) : '؟',
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
                  if (!isMe)
                    Text(msg.senderName, style: AppTextStyles.caption.copyWith(
                      fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.gold)),
                  Text(msg.text, style: AppTextStyles.body.copyWith(fontSize: 13)),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(timeStr, style: AppTextStyles.caption.copyWith(fontSize: 8)),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}
