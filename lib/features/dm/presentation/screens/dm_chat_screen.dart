import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/dm_repository.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/extensions/theme_extensions.dart';

class DmChatScreen extends ConsumerStatefulWidget {
  const DmChatScreen({super.key, required this.conversation});
  final DmConversation conversation;

  @override
  ConsumerState<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends ConsumerState<DmChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  List<DmMessage> _messages = [];
  bool _isLoading = true;
  StreamSubscription<List<DmMessage>>? _sub;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dmRepositoryProvider).markAsRead(widget.conversation.id);
    });

    _sub = ref
        .read(dmRepositoryProvider)
        .streamMessages(widget.conversation.id)
        .listen((msgs) {
      if (!mounted) return;
      final shouldScroll = _isNearBottom || msgs.length > _messages.length;
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      if (shouldScroll) _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool get _isNearBottom {
    if (!_scrollCtrl.hasClients) return true;
    final pos = _scrollCtrl.position;
    return pos.pixels >= pos.maxScrollExtent - 80;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _ctrl.clear();

    try {
      await ref
          .read(dmRepositoryProvider)
          .sendMessage(widget.conversation.id, text);
    } catch (e) {
      if (mounted) {
                AppSnackBar.error(context, '메시지 전송에 실패했습니다');
        _ctrl.text = text;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.isDark ? AppColors.darkBg : Colors.white;
    final divColor = context.isDark ? const Color(0xFF262626) : const Color(0xFFEEEEEE);
    final myId = ref.watch(currentUserProvider)?.id ?? '';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft,
              color: context.isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            UserAvatar(
              username: widget.conversation.otherUsername,
              avatarUrl: widget.conversation.otherAvatarUrl,
              radius: 18,
              isDark: context.isDark,
            ),
            const SizedBox(width: 10),
            Text(
              widget.conversation.otherUsername,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Divider(height: 0.5, thickness: 0.5, color: divColor),
          Expanded(child: _buildMessageList(context.isDark, context.accentColor, myId)),
          Divider(height: 0.5, thickness: 0.5, color: divColor),
          _buildInput(context.isDark, context.accentColor, divColor),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDark, Color accent, String myId) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return Center(
        child: Text(
          '첫 메시지를 보내보세요 🎣',
          style: TextStyle(
            color: isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        final isMe = msg.senderId == myId;
        // 날짜 구분선: 이전 메시지와 날짜가 다르거나 첫 메시지일 때
        final showDate =
            i == 0 || !_isSameDay(_messages[i - 1].createdAt, msg.createdAt);
        // 아바타: 상대방 메시지이고 다음 메시지와 발신자가 다를 때(그룹 마지막)
        final showAvatar = !isMe &&
            (i == _messages.length - 1 ||
                _messages[i + 1].senderId != msg.senderId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate) _DateDivider(dt: msg.createdAt, isDark: isDark),
            _MessageBubble(
              msg: msg,
              isMe: isMe,
              isDark: isDark,
              accent: accent,
              showAvatar: showAvatar,
              conversation: widget.conversation,
            ),
          ],
        );
      },
    );
  }

  Widget _buildInput(bool isDark, Color accent, Color divColor) {
    final sub =
        isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 8,
          bottom:
              MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 10,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: '메시지 입력...',
                  hintStyle: TextStyle(color: sub, fontSize: 14),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder(
              valueListenable: _ctrl,
              builder: (_, val, __) {
                final hasText = val.text.trim().isNotEmpty;
                return GestureDetector(
                  onTap: hasText && !_sending ? _send : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasText
                          ? accent
                          : (isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFEEEEEE)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.send,
                      size: 18,
                      color: hasText
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark
                              ? const Color(0xFF555555)
                              : const Color(0xFFAAAAAA)),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.dt, required this.isDark});
  final DateTime dt;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final sub =
        isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final divColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: divColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${dt.month}월 ${dt.day}일',
              style: TextStyle(fontSize: 11, color: sub),
            ),
          ),
          Expanded(child: Divider(color: divColor)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.isDark,
    required this.accent,
    required this.showAvatar,
    required this.conversation,
  });

  final DmMessage msg;
  final bool isMe;
  final bool isDark;
  final Color accent;
  final bool showAvatar;
  final DmConversation conversation;

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';
    final bubbleBg = isMe
        ? accent
        : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0));
    final textColor = isMe
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : Colors.black);
    final subColor =
        isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            SizedBox(
              width: 32,
              child: showAvatar
                  ? UserAvatar(
                      username: conversation.otherUsername,
                      avatarUrl: conversation.otherAvatarUrl,
                      radius: 14,
                      isDark: isDark,
                    )
                  : null,
            ),
            const SizedBox(width: 6),
          ],
          if (isMe) ...[
            Text(timeStr,
                style: TextStyle(fontSize: 10, color: subColor)),
            const SizedBox(width: 4),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                    fontSize: 14, color: textColor, height: 1.4),
              ),
            ),
          ),
          if (!isMe) ...[
            const SizedBox(width: 4),
            Text(timeStr,
                style: TextStyle(fontSize: 10, color: subColor)),
          ],
        ],
      ),
    );
  }
}
