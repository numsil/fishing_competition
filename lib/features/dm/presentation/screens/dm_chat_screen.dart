import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../league/presentation/screens/league_detail_screen.dart';
import '../../data/dm_repository.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/utils/banned_error_handler.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../marketplace/data/marketplace_model.dart';
import '../../../marketplace/data/marketplace_repository.dart';

class DmChatScreen extends ConsumerStatefulWidget {
  const DmChatScreen({
    super.key,
    required this.conversation,
    this.pendingItem,
  });
  final DmConversation conversation;
  final DmPendingItem? pendingItem;

  @override
  ConsumerState<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends ConsumerState<DmChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  List<DmMessage> _messages = [];
  // 내가 보낸 메시지 낙관적 표시용 (Realtime 에코가 늦거나 누락돼도 즉시 보이게).
  // 스트림(서버)에 반영되면 제거된다.
  final List<DmMessage> _localSent = [];
  bool _isLoading = true;
  StreamSubscription<List<DmMessage>>? _sub;
  // 문의하기로 진입 시 전송 대기 중인 매물 카드. 전송하면 null로 해제.
  DmPendingItem? _pending;

  @override
  void initState() {
    super.initState();
    _pending = widget.pendingItem;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dmRepositoryProvider).markAsRead(widget.conversation.id);
    });

    _sub = ref
        .read(dmRepositoryProvider)
        .streamMessages(widget.conversation.id)
        .listen((msgs) {
      if (!mounted) return;
      // 서버에 반영된 메시지는 낙관적 목록에서 제거 후 병합
      final ids = msgs.map((m) => m.id).toSet();
      _localSent.removeWhere((m) => ids.contains(m.id));
      final merged = _mergeMessages(msgs, _localSent);
      final hasNew = merged.length > _messages.length;
      final shouldScroll = _isNearBottom || hasNew;
      setState(() {
        _messages = merged;
        _isLoading = false;
      });
      if (shouldScroll) _scrollToBottom();
      // 채팅방 열린 상태에서 새 메시지 수신 시 즉시 읽음 처리
      if (hasNew) {
        ref.read(dmRepositoryProvider).markAsRead(widget.conversation.id);
      }
    }, onError: (_) {
      // 스트림 오류(네트워크/RLS 등) 시 무한 스피너 방지: 로딩 종료 + 안내
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.error(context, '메시지를 불러오지 못했어요. 네트워크를 확인해주세요.');
    });
  }

  @override
  void dispose() {
    // 채팅방 나갈 때 배지 즉시 갱신
    ref.invalidate(hasUnreadDmsProvider);
    ref.invalidate(dmConversationsProvider);
    _sub?.cancel();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // 스트림 메시지 + 낙관적 메시지 병합 (id 중복 제거, 시간순 정렬)
  List<DmMessage> _mergeMessages(List<DmMessage> base, List<DmMessage> extra) {
    if (extra.isEmpty) return base;
    final ids = base.map((m) => m.id).toSet();
    final result = [...base, ...extra.where((m) => !ids.contains(m.id))];
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  bool get _isNearBottom {
    if (!_scrollCtrl.hasClients) return true;
    final pos = _scrollCtrl.position;
    return pos.pixels >= pos.maxScrollExtent - 80;
  }

  void _scrollToBottom() {
    // 변동 높이(날짜 구분선·아바타) 때문에 maxScrollExtent가 첫 프레임엔 부정확.
    // 한 프레임 뒤 한 번 더 보정해 항상 정확히 맨 아래로 내린다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollCtrl.hasClients) return;
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      });
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    // 텍스트가 있거나, 전송 대기 매물 카드가 있으면 전송 가능(카드 단독 전송 허용).
    if ((text.isEmpty && _pending == null) || _sending) return;

    final pending = _pending;
    bool cardSent = false;
    setState(() => _sending = true);
    _ctrl.clear();

    try {
      final repo = ref.read(dmRepositoryProvider);

      // 1) 매물 카드 먼저 전송 (카드가 위, 텍스트가 아래에 오도록)
      if (pending != null) {
        final card = await repo.sendItemCard(
          widget.conversation.id,
          itemId: pending.itemId,
          title: pending.title,
        );
        if (mounted) {
          if (!_messages.any((m) => m.id == card.id)) _localSent.add(card);
          setState(() {
            _pending = null;
            _messages = _mergeMessages(_messages, _localSent);
          });
          _scrollToBottom();
          cardSent = true;
        }
      }

      // 2) 텍스트가 있으면 이어서 전송
      if (text.isNotEmpty) {
        final sent = await repo.sendMessage(widget.conversation.id, text);
        if (mounted && !_messages.any((m) => m.id == sent.id)) {
          _localSent.add(sent);
          setState(() {
            _messages = _mergeMessages(_messages, _localSent);
          });
          _scrollToBottom();
        }
      }
    } on DmBlockedException catch (e) {
      if (mounted) {
        AppSnackBar.warning(context, e.toString());
        _ctrl.text = text;
        if (!cardSent) setState(() => _pending = pending); // 실패 시 미리보기 복구
      }
    } catch (e) {
      if (await handleIfBanned(e)) return;
      if (mounted) {
        AppSnackBar.error(context, '메시지 전송에 실패했습니다');
        _ctrl.text = text;
        if (!cardSent) setState(() => _pending = pending); // 실패 시 미리보기 복구
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
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/user/${widget.conversation.otherUserId}'),
          child: Row(
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
      ),
      body: Column(
        children: [
          Divider(height: 0.5, thickness: 0.5, color: divColor),
          Expanded(child: _buildMessageList(context.isDark, context.accentColor, myId)),
          Divider(height: 0.5, thickness: 0.5, color: divColor),
          if (_pending != null) _buildPendingBar(context.isDark, divColor),
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

  Widget _buildPendingBar(bool isDark, Color divColor) {
    final p = _pending!;
    final sub = isDark ? const Color(0xFF999999) : const Color(0xFF888888);
    final thumbBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      color: isDark ? const Color(0xFF141414) : const Color(0xFFFAFAFA),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 40,
              child: (p.thumbnailUrl != null && p.thumbnailUrl!.isNotEmpty)
                  ? Image.network(
                      p.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: thumbBg,
                        child: const Icon(LucideIcons.image,
                            size: 18, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: thumbBg,
                      child: const Icon(LucideIcons.image,
                          size: 18, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.priceLabel,
                  style: TextStyle(fontSize: 12, color: sub),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.x, size: 18, color: sub),
            onPressed: () => setState(() => _pending = null),
          ),
        ],
      ),
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
                final canSend =
                    val.text.trim().isNotEmpty || _pending != null;
                return GestureDetector(
                  onTap: canSend && !_sending ? _send : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: canSend
                          ? accent
                          : (isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFEEEEEE)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.send,
                      size: 18,
                      color: canSend
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

  // 리그 초대 링크 1건 추출 + 본문에서 제거.
  // 포맷: https://nakstar.app/league/<id>
  static final _leagueLinkRe = RegExp(
    r'https:\/\/nakstar\.app\/league\/([0-9a-fA-F-]{36})',
  );

  // 매물 카드 마커: https://nakstar.app/market/<uuid>
  static final _marketLinkRe = RegExp(
    r'https:\/\/nakstar\.app\/market\/([0-9a-fA-F-]{36})',
  );

  ({String text, String? leagueId}) _parseContent(String raw) {
    final m = _leagueLinkRe.firstMatch(raw);
    if (m == null) return (text: raw, leagueId: null);
    // URL이 들어있던 줄 통째로 제거 (앞뒤 공백·줄바꿈 정리)
    final stripped = raw.replaceAll(_leagueLinkRe, '').trim();
    return (text: stripped, leagueId: m.group(1));
  }

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    final marketId = _marketLinkRe.firstMatch(msg.content)?.group(1);
    if (marketId != null) {
      final subColor =
          isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) const SizedBox(width: 38), // 아바타 폭만큼 들여쓰기 정렬
            if (isMe) ...[
              Text(timeStr, style: TextStyle(fontSize: 10, color: subColor)),
              const SizedBox(width: 4),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
              child: _MarketItemCard(itemId: marketId, isDark: isDark),
            ),
            if (!isMe) ...[
              const SizedBox(width: 4),
              Text(timeStr, style: TextStyle(fontSize: 10, color: subColor)),
            ],
          ],
        ),
      );
    }

    final bubbleBg = isMe
        ? accent
        : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0));
    final textColor = isMe
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : Colors.black);
    final subColor =
        isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);

    final parsed = _parseContent(msg.content);
    final hasLeagueLink = parsed.leagueId != null;
    final btnBg =
        isMe ? Colors.white.withValues(alpha: 0.18) : accent.withValues(alpha: 0.12);
    final btnFg = isMe ? textColor : accent;

    final bubbleChild = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (parsed.text.isNotEmpty)
          Text(
            parsed.text,
            style:
                TextStyle(fontSize: 14, color: textColor, height: 1.4),
          ),
        if (hasLeagueLink) ...[
          if (parsed.text.isNotEmpty) const SizedBox(height: 8),
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    LeagueDetailScreen(leagueId: parsed.leagueId!),
              ),
            ),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: btnBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.fish, size: 14, color: btnFg),
                  const SizedBox(width: 6),
                  Text(
                    '리그 보기',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: btnFg,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(LucideIcons.chevronRight, size: 14, color: btnFg),
                ],
              ),
            ),
          ),
        ],
      ],
    );

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
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context
                          .push('/user/${conversation.otherUserId}'),
                      child: UserAvatar(
                        username: conversation.otherUsername,
                        avatarUrl: conversation.otherAvatarUrl,
                        radius: 14,
                        isDark: isDark,
                      ),
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
              child: bubbleChild,
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

/// 채팅 버블용 매물 카드. marketplaceItemProvider로 현재 매물 상태를 실시간 조회한다.
/// 로딩/삭제(null)/정상 3상태. 탭 시 매물 상세로 이동(삭제 시 안내).
class _MarketItemCard extends ConsumerWidget {
  const _MarketItemCard({required this.itemId, required this.isDark});
  final String itemId;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketplaceItemProvider(itemId));
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    final sub = isDark ? const Color(0xFF999999) : const Color(0xFF888888);
    final thumbBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);

    Widget shell({required Widget child, VoidCallback? onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      );
    }

    return async.when(
      loading: () => shell(
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: thumbBg,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              Text('매물 불러오는 중…',
                  style: TextStyle(fontSize: 13, color: sub)),
            ],
          ),
        ),
      ),
      error: (_, __) => shell(
        child: _deletedRow(sub, thumbBg),
        onTap: null,
      ),
      data: (item) {
        if (item == null) {
          return shell(child: _deletedRow(sub, thumbBg), onTap: () {
            AppSnackBar.info(context, '삭제된 매물이에요');
          });
        }
        return shell(
          onTap: () => context.push('/marketplace/${item.id}', extra: item),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: item.imageUrls.isNotEmpty
                      ? Image.network(
                          item.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: thumbBg,
                            child: const Icon(LucideIcons.image,
                                size: 20, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: thumbBg,
                          child: const Icon(LucideIcons.image,
                              size: 20, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sub,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.formattedPrice,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: sub),
            ],
          ),
        );
      },
    );
  }

  Widget _deletedRow(Color sub, Color thumbBg) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: thumbBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.imageOff, size: 20, color: sub),
          ),
          const SizedBox(width: 10),
          Text('삭제된 매물',
              style: TextStyle(fontSize: 13, color: sub)),
        ],
      ),
    );
  }
}
