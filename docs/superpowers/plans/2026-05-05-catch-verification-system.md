# Catch Verification System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 조과 제출 시 활성 유저 10명에게 랜덤 배분 → 응답자 기준 70% 승인 or 60% 거부 시 결과 확정, 인증된 조과에만 점수 반영

**Architecture:** 조과 제출(FeedRepository) → catch_verifications + verification_votes 생성 → 랭킹 화면 인증 탭에서 투표 → 투표마다 결과 재계산 → post.review_status 업데이트. 온도 기능 미구현 단계에서는 활성 유저(포스트 1개 이상) 중 랜덤 10명 선정.

**Tech Stack:** Flutter, Riverpod (riverpod_annotation), Supabase, Freezed, go_router, lucide_icons

---

## 판정 로직 (공통 참조)

```
responded = approve_count + reject_count
if (responded >= 3):
  if approve / responded >= 0.70 → status = 'approved', post.review_status = 'approved'
  if reject / responded >= 0.60  → status = 'rejected', post.review_status = 'rejected'
  else → pending (계속 대기)
if (responded < 3) → 48h 이후 자동 처리 (MVP에서는 자동 승인으로 처리)
```

---

## File Map

| 경로 | 작업 |
|------|------|
| `supabase/migrations/20260505_catch_verification.sql` | 신규 생성 |
| `lib/features/verification/data/verification_model.dart` | 신규 생성 |
| `lib/features/verification/data/verification_repository.dart` | 신규 생성 |
| `lib/features/verification/presentation/screens/verification_tab.dart` | 신규 생성 |
| `lib/features/verification/presentation/screens/verification_detail_screen.dart` | 신규 생성 |
| `lib/features/ranking/presentation/screens/ranking_screen.dart` | 수정 - 탭 4개로 확장, 배지 추가 |
| `lib/features/feed/data/feed_repository.dart` | 수정 - createPost에서 review_status='pending' + 인증 요청 생성 |
| `lib/features/ranking/data/ranking_repository.dart` | 수정 - review_status='approved' 필터 추가 |
| `lib/core/router/app_router.dart` | 수정 - verification_detail 라우트 추가 |

---

## Task 1: Supabase DB Migration

**Files:**
- Create: `supabase/migrations/20260505_catch_verification.sql`

- [ ] **Step 1: SQL 파일 작성**

```sql
-- catch_verifications: 인증 요청 1건
CREATE TABLE IF NOT EXISTS catch_verifications (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id       UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  submitter_id  UUID NOT NULL REFERENCES users(id),
  status        TEXT NOT NULL DEFAULT 'pending',
  -- status: pending | approved | rejected | expired
  approve_count INT NOT NULL DEFAULT 0,
  reject_count  INT NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at   TIMESTAMPTZ,
  UNIQUE(post_id)
);

-- verification_votes: 인증자 1명의 투표
CREATE TABLE IF NOT EXISTS verification_votes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  verification_id     UUID NOT NULL REFERENCES catch_verifications(id) ON DELETE CASCADE,
  voter_id            UUID NOT NULL REFERENCES users(id),
  vote                TEXT,  -- NULL=미응답 | 'approve' | 'reject'
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  voted_at            TIMESTAMPTZ,
  UNIQUE(verification_id, voter_id)
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_verif_votes_voter ON verification_votes(voter_id) WHERE vote IS NULL;
CREATE INDEX IF NOT EXISTS idx_verif_votes_verif ON verification_votes(verification_id);
CREATE INDEX IF NOT EXISTS idx_catch_verif_post  ON catch_verifications(post_id);
CREATE INDEX IF NOT EXISTS idx_catch_verif_status ON catch_verifications(status);

-- RLS
ALTER TABLE catch_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE verification_votes  ENABLE ROW LEVEL SECURITY;

-- catch_verifications: 본인 제출 조회 + 인증자(투표 배정된 사람)만 조회
CREATE POLICY "verif_select" ON catch_verifications FOR SELECT
  USING (
    submitter_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM verification_votes v
      WHERE v.verification_id = id AND v.voter_id = auth.uid()
    )
  );

CREATE POLICY "verif_insert" ON catch_verifications FOR INSERT
  WITH CHECK (submitter_id = auth.uid());

-- verification_votes: 본인 투표만 업데이트
CREATE POLICY "vote_select" ON verification_votes FOR SELECT
  USING (voter_id = auth.uid());

CREATE POLICY "vote_insert" ON verification_votes FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM catch_verifications cv
      WHERE cv.id = verification_id AND cv.submitter_id != auth.uid()
    )
  );

CREATE POLICY "vote_update" ON verification_votes FOR UPDATE
  USING (voter_id = auth.uid())
  WITH CHECK (voter_id = auth.uid());
```

- [ ] **Step 2: Supabase 대시보드 SQL 에디터에서 실행 및 테이블 생성 확인**

테이블 `catch_verifications`, `verification_votes` 2개가 생성되어야 함.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260505_catch_verification.sql
git commit -m "feat: catch_verifications, verification_votes DB migration"
```

---

## Task 2: VerificationModel

**Files:**
- Create: `lib/features/verification/data/verification_model.dart`

- [ ] **Step 1: 모델 파일 작성**

```dart
// lib/features/verification/data/verification_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'verification_model.freezed.dart';
part 'verification_model.g.dart';

@freezed
abstract class VerificationRequest with _$VerificationRequest {
  const factory VerificationRequest({
    required String id,
    @JsonKey(name: 'post_id') required String postId,
    @JsonKey(name: 'submitter_id') required String submitterId,
    required String status,
    @JsonKey(name: 'approve_count') @Default(0) int approveCount,
    @JsonKey(name: 'reject_count') @Default(0) int rejectCount,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'resolved_at') DateTime? resolvedAt,
    // joined
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String imageUrl,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String submitterName,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String submitterAvatar,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('배스') String fishType,
    @JsonKey(includeFromJson: false, includeToJson: false) double? length,
    @JsonKey(includeFromJson: false, includeToJson: false) double? weight,
    @JsonKey(includeFromJson: false, includeToJson: false) String? location,
    @JsonKey(includeFromJson: false, includeToJson: false) String? myVote,
  }) = _VerificationRequest;

  factory VerificationRequest.fromJson(Map<String, dynamic> json) =>
      _$VerificationRequestFromJson(json);
}
```

- [ ] **Step 2: 코드 생성 실행**

```bash
cd /Users/jun/Desktop/code/HUK/fishing_competition
dart run build_runner build --delete-conflicting-outputs
```

Expected: `verification_model.freezed.dart`, `verification_model.g.dart` 생성

- [ ] **Step 3: Commit**

```bash
git add lib/features/verification/data/
git commit -m "feat: VerificationRequest model (freezed)"
```

---

## Task 3: VerificationRepository

**Files:**
- Create: `lib/features/verification/data/verification_repository.dart`

- [ ] **Step 1: Repository 작성**

```dart
// lib/features/verification/data/verification_repository.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'verification_model.dart';

part 'verification_repository.g.dart';

class VerificationRepository {
  final SupabaseClient _supabase;
  VerificationRepository(this._supabase);

  // 조과 제출 후 호출 - 인증 요청 생성 + 랜덤 10명 배정
  Future<void> createVerificationRequest(String postId, String submitterId) async {
    // 1. catch_verifications 생성
    final verif = await _supabase
        .from('catch_verifications')
        .insert({'post_id': postId, 'submitter_id': submitterId})
        .select('id')
        .single();
    final verifId = verif['id'] as String;

    // 2. 적격 유저 풀 조회 (본인 제외, posts 1개 이상)
    final candidates = await _supabase
        .from('users')
        .select('id')
        .neq('id', submitterId)
        .limit(50);

    if (candidates.isEmpty) return;

    final ids = List<Map<String, dynamic>>.from(candidates);
    ids.shuffle();
    final selected = ids.take(10).toList();

    // 3. verification_votes 생성
    final votes = selected.map((u) => {
      'verification_id': verifId,
      'voter_id': u['id'],
    }).toList();
    await _supabase.from('verification_votes').insert(votes);
  }

  // 내가 투표해야 할 인증 요청 목록 (미응답만)
  Future<List<VerificationRequest>> getPendingForMe(String userId) async {
    final rows = await _supabase
        .from('verification_votes')
        .select(
          'verification_id, vote, catch_verifications!inner(id, post_id, submitter_id, status, approve_count, reject_count, created_at, posts!inner(image_url, fish_type, length, weight, location, users!inner(username, avatar_url)))'
        )
        .eq('voter_id', userId)
        .isFilter('vote', null)
        .eq('catch_verifications.status', 'pending');

    return rows.map((row) {
      final cv = row['catch_verifications'] as Map<String, dynamic>;
      final post = cv['posts'] as Map<String, dynamic>;
      final user = post['users'] as Map<String, dynamic>;
      final req = VerificationRequest.fromJson(cv);
      return req.copyWith(
        myVote: row['vote'] as String?,
        imageUrl: post['image_url'] as String? ?? '',
        submitterName: user['username'] as String? ?? '',
        submitterAvatar: user['avatar_url'] as String? ?? '',
        fishType: post['fish_type'] as String? ?? '배스',
        length: (post['length'] as num?)?.toDouble(),
        weight: (post['weight'] as num?)?.toDouble(),
        location: post['location'] as String?,
      );
    }).toList();
  }

  // 투표 제출 + 결과 자동 판정
  Future<void> submitVote(String verificationId, String voterId, String vote) async {
    // 1. 투표 기록
    await _supabase
        .from('verification_votes')
        .update({'vote': vote, 'voted_at': DateTime.now().toIso8601String()})
        .eq('verification_id', verificationId)
        .eq('voter_id', voterId);

    // 2. 현재 집계 조회
    final counts = await _supabase
        .from('verification_votes')
        .select('vote')
        .eq('verification_id', verificationId)
        .not('vote', 'is', null);

    int approveCount = 0;
    int rejectCount = 0;
    for (final row in counts) {
      if (row['vote'] == 'approve') approveCount++;
      if (row['vote'] == 'reject') rejectCount++;
    }

    // 3. catch_verifications 카운트 업데이트
    await _supabase
        .from('catch_verifications')
        .update({'approve_count': approveCount, 'reject_count': rejectCount})
        .eq('id', verificationId);

    // 4. 판정
    final responded = approveCount + rejectCount;
    if (responded < 3) return;

    String? newStatus;
    if (approveCount / responded >= 0.7) {
      newStatus = 'approved';
    } else if (rejectCount / responded >= 0.6) {
      newStatus = 'rejected';
    }
    if (newStatus == null) return;

    // 5. 결과 확정
    final verif = await _supabase
        .from('catch_verifications')
        .update({
          'status': newStatus,
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', verificationId)
        .select('post_id')
        .single();

    await _supabase
        .from('posts')
        .update({'review_status': newStatus})
        .eq('id', verif['post_id']);
  }

  // 내가 완료한 투표 포함 전체 목록 (인증 탭 히스토리)
  Future<List<VerificationRequest>> getMyVerificationHistory(String userId) async {
    final rows = await _supabase
        .from('verification_votes')
        .select(
          'verification_id, vote, catch_verifications!inner(id, post_id, submitter_id, status, approve_count, reject_count, created_at, posts!inner(image_url, fish_type, length, weight, location, users!inner(username, avatar_url)))'
        )
        .eq('voter_id', userId)
        .order('created_at', referencedTable: 'catch_verifications', ascending: false)
        .limit(30);

    return rows.map((row) {
      final cv = row['catch_verifications'] as Map<String, dynamic>;
      final post = cv['posts'] as Map<String, dynamic>;
      final user = post['users'] as Map<String, dynamic>;
      final req = VerificationRequest.fromJson(cv);
      return req.copyWith(
        myVote: row['vote'] as String?,
        imageUrl: post['image_url'] as String? ?? '',
        submitterName: user['username'] as String? ?? '',
        submitterAvatar: user['avatar_url'] as String? ?? '',
        fishType: post['fish_type'] as String? ?? '배스',
        length: (post['length'] as num?)?.toDouble(),
        weight: (post['weight'] as num?)?.toDouble(),
        location: post['location'] as String?,
      );
    }).toList();
  }

  // 특정 포스트의 인증 상태 조회
  Future<VerificationRequest?> getVerificationByPostId(String postId) async {
    final rows = await _supabase
        .from('catch_verifications')
        .select('id, post_id, submitter_id, status, approve_count, reject_count, created_at')
        .eq('post_id', postId)
        .limit(1);
    if (rows.isEmpty) return null;
    return VerificationRequest.fromJson(rows.first);
  }
}

@riverpod
VerificationRepository verificationRepository(VerificationRepositoryRef ref) {
  return VerificationRepository(Supabase.instance.client);
}

@riverpod
Future<List<VerificationRequest>> myPendingVerifications(
  MyPendingVerificationsRef ref,
) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  return ref.watch(verificationRepositoryProvider).getPendingForMe(userId);
}

@riverpod
Future<List<VerificationRequest>> myVerificationHistory(
  MyVerificationHistoryRef ref,
) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  return ref.watch(verificationRepositoryProvider).getMyVerificationHistory(userId);
}
```

- [ ] **Step 2: 코드 생성 실행**

```bash
cd /Users/jun/Desktop/code/HUK/fishing_competition
dart run build_runner build --delete-conflicting-outputs
```

Expected: `verification_repository.g.dart` 생성

- [ ] **Step 3: Commit**

```bash
git add lib/features/verification/data/
git commit -m "feat: VerificationRepository - 인증 요청 생성, 투표, 판정 로직"
```

---

## Task 4: 인증 상세 화면

**Files:**
- Create: `lib/features/verification/presentation/screens/verification_detail_screen.dart`

- [ ] **Step 1: 화면 작성**

```dart
// lib/features/verification/presentation/screens/verification_detail_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/verification_model.dart';
import '../../data/verification_repository.dart';

class VerificationDetailScreen extends ConsumerStatefulWidget {
  const VerificationDetailScreen({super.key, required this.request});
  final VerificationRequest request;

  @override
  ConsumerState<VerificationDetailScreen> createState() =>
      _VerificationDetailScreenState();
}

class _VerificationDetailScreenState
    extends ConsumerState<VerificationDetailScreen> {
  bool _loading = false;

  Future<void> _vote(String vote) async {
    setState(() => _loading = true);
    try {
      final userId = ref.read(verificationRepositoryProvider).runtimeType; // unused
      final supabase = ref.read(verificationRepositoryProvider);
      // voter_id is the current user — handled in repository
      await ref.read(verificationRepositoryProvider).submitVote(
            widget.request.id,
            _currentUserId(),
            vote,
          );
      ref.invalidate(myPendingVerificationsProvider);
      ref.invalidate(myVerificationHistoryProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '처리 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _currentUserId() {
    import 'package:supabase_flutter/supabase_flutter.dart';
    return Supabase.instance.client.auth.currentUser!.id;
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final isDark = context.isDark;
    final accent = context.accentColor;
    final sub = isDark ? const Color(0xFF888888) : const Color(0xFF999999);
    final alreadyVoted = req.myVote != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('인증 심사',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 조과 사진
            AspectRatio(
              aspectRatio: 1.0,
              child: CachedNetworkImage(
                imageUrl: req.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제출자 정보
                  Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: req.submitterAvatar.isNotEmpty
                          ? CachedNetworkImageProvider(req.submitterAvatar)
                          : null,
                      child: req.submitterAvatar.isEmpty
                          ? Text(req.submitterName.isNotEmpty
                              ? req.submitterName[0].toUpperCase()
                              : '?')
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(req.submitterName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ]),
                  const SizedBox(height: 20),
                  // 조과 정보
                  _InfoRow(
                    icon: LucideIcons.fish,
                    label: '어종',
                    value: req.fishType,
                    accent: accent,
                  ),
                  if (req.length != null)
                    _InfoRow(
                      icon: LucideIcons.ruler,
                      label: '길이',
                      value: '${req.length!.toStringAsFixed(1)} cm',
                      accent: accent,
                    ),
                  if (req.weight != null)
                    _InfoRow(
                      icon: LucideIcons.scale,
                      label: '무게',
                      value: '${req.weight!.toStringAsFixed(2)} kg',
                      accent: accent,
                    ),
                  if (req.location != null)
                    _InfoRow(
                      icon: LucideIcons.mapPin,
                      label: '위치',
                      value: req.location!,
                      accent: accent,
                    ),
                  const SizedBox(height: 8),
                  // 현재 집계
                  Row(children: [
                    Icon(LucideIcons.users, size: 14, color: sub),
                    const SizedBox(width: 6),
                    Text(
                      '${req.approveCount + req.rejectCount}명 응답 · 승인 ${req.approveCount} / 거부 ${req.rejectCount}',
                      style: TextStyle(fontSize: 12, color: sub),
                    ),
                  ]),
                  const SizedBox(height: 28),
                  // 투표 버튼
                  if (alreadyVoted)
                    Center(
                      child: Text(
                        req.myVote == 'approve' ? '✅ 승인 완료' : '❌ 거부 완료',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: req.myVote == 'approve' ? Colors.green : Colors.red,
                        ),
                      ),
                    )
                  else
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : () => _vote('reject'),
                          icon: const Icon(LucideIcons.x, size: 18),
                          label: const Text('거부'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : () => _vote('approve'),
                          icon: const Icon(LucideIcons.check, size: 18),
                          label: const Text('승인'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
  final IconData icon;
  final String label, value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontSize: 13)),
      ]),
    );
  }
}
```

> **주의**: `_currentUserId()` 내 import 문은 파일 상단으로 이동해야 함. 실제 파일 작성 시 `import 'package:supabase_flutter/supabase_flutter.dart';`를 상단에 추가하고 메서드는 단순히 `Supabase.instance.client.auth.currentUser!.id`를 반환.

- [ ] **Step 2: import 정리 후 flutter analyze 통과 확인**

```bash
cd /Users/jun/Desktop/code/HUK/fishing_competition
flutter analyze lib/features/verification/presentation/screens/verification_detail_screen.dart
```

Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/verification/presentation/screens/verification_detail_screen.dart
git commit -m "feat: VerificationDetailScreen - 조과 심사 화면"
```

---

## Task 5: 인증 탭 (목록 화면)

**Files:**
- Create: `lib/features/verification/presentation/screens/verification_tab.dart`

- [ ] **Step 1: 탭 화면 작성**

```dart
// lib/features/verification/presentation/screens/verification_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/verification_model.dart';
import '../../data/verification_repository.dart';
import 'verification_detail_screen.dart';

class VerificationTab extends ConsumerWidget {
  const VerificationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final accent = context.accentColor;
    final sub = isDark ? const Color(0xFF888888) : const Color(0xFF999999);

    final pendingAsync = ref.watch(myPendingVerificationsProvider);
    final historyAsync = ref.watch(myVerificationHistoryProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myPendingVerificationsProvider);
        ref.invalidate(myVerificationHistoryProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 대기 중 섹션
          Row(children: [
            Text('심사 대기',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(width: 8),
            pendingAsync.when(
              data: (list) => list.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${list.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    )
                  : const SizedBox(),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ]),
          const SizedBox(height: 12),
          pendingAsync.when(
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text('대기 중인 심사가 없습니다',
                            style: TextStyle(color: sub, fontSize: 13))),
                  )
                : Column(
                    children: list
                        .map((req) => _VerifCard(
                              request: req,
                              isDark: isDark,
                              accent: accent,
                              sub: sub,
                              onTap: () => _openDetail(context, req, ref),
                            ))
                        .toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('오류: $e', style: TextStyle(color: sub))),
          ),
          const SizedBox(height: 28),
          // 완료된 심사 섹션
          Text('완료된 심사',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          historyAsync.when(
            data: (list) {
              final done = list.where((r) => r.myVote != null).toList();
              if (done.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                      child: Text('완료된 심사가 없습니다',
                          style: TextStyle(color: sub, fontSize: 13))),
                );
              }
              return Column(
                children: done
                    .map((req) => _VerifCard(
                          request: req,
                          isDark: isDark,
                          accent: accent,
                          sub: sub,
                          onTap: () => _openDetail(context, req, ref),
                        ))
                    .toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('오류: $e', style: TextStyle(color: sub))),
          ),
        ],
      ),
    );
  }

  void _openDetail(
      BuildContext context, VerificationRequest req, WidgetRef ref) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => VerificationDetailScreen(request: req)),
    );
    if (result == true) {
      ref.invalidate(myPendingVerificationsProvider);
      ref.invalidate(myVerificationHistoryProvider);
    }
  }
}

class _VerifCard extends StatelessWidget {
  const _VerifCard({
    required this.request,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.onTap,
  });
  final VerificationRequest request;
  final bool isDark;
  final Color accent, sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final req = request;
    final isPending = req.myVote == null;

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        radius: 14,
        borderColor: isPending
            ? accent.withValues(alpha: 0.4)
            : (isDark ? AppColors.darkSurface2 : AppColors.lightDivider),
        child: Row(children: [
          // 썸네일
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64,
              height: 64,
              child: CachedNetworkImage(
                imageUrl: req.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF0F0F0)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req.submitterName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  '${req.fishType}${req.length != null ? ' · ${req.length!.toStringAsFixed(1)}cm' : ''}',
                  style: TextStyle(fontSize: 12, color: sub),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(LucideIcons.users, size: 12, color: sub),
                  const SizedBox(width: 4),
                  Text(
                    '${req.approveCount + req.rejectCount}명 응답',
                    style: TextStyle(fontSize: 11, color: sub),
                  ),
                ]),
              ],
            ),
          ),
          // 상태 뱃지
          _StatusBadge(request: req, accent: accent),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.request, required this.accent});
  final VerificationRequest request;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (request.myVote == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('심사하기',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
      );
    }
    final approved = request.myVote == 'approve';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (approved ? Colors.green : Colors.red).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        approved ? '승인' : '거부',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: approved ? Colors.green : Colors.red),
      ),
    );
  }
}
```

- [ ] **Step 2: flutter analyze 확인**

```bash
flutter analyze lib/features/verification/presentation/screens/verification_tab.dart
```

Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/verification/presentation/screens/verification_tab.dart
git commit -m "feat: VerificationTab - 심사 목록 UI"
```

---

## Task 6: 랭킹 화면 탭 확장 (인증 탭 추가 + 배지)

**Files:**
- Modify: `lib/features/ranking/presentation/screens/ranking_screen.dart`

- [ ] **Step 1: RankingScreen 수정**

`ranking_screen.dart`에서 다음 세 곳을 수정:

**1) import 추가** (파일 상단):
```dart
import '../../../verification/data/verification_repository.dart';
import '../../../verification/presentation/screens/verification_tab.dart';
```

**2) `initState`에서 TabController length 변경:**
```dart
// 변경 전
_tab = TabController(length: 3, vsync: this);
// 변경 후
_tab = TabController(length: 4, vsync: this);
```

**3) AppBar bottom의 TabBar 및 TabBarView 교체:**

```dart
// AppBar bottom (TabBar 부분 전체 교체)
bottom: PreferredSize(
  preferredSize: const Size.fromHeight(48),
  child: Consumer(
    builder: (context, ref, _) {
      final pendingCount = ref.watch(myPendingVerificationsProvider)
          .whenOrNull(data: (list) => list.length) ?? 0;
      return TabBar(
        controller: _tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
        tabs: [
          const Tab(text: '리그'),
          const Tab(text: '개인'),
          const Tab(text: '이달의'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('인증'),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  ),
),
```

**4) TabBarView children에 VerificationTab 추가:**

```dart
// 변경 전
children: [
  _LeagueScoreTab(...),
  _PersonalScoreTab(...),
  _MonthlyTab(...),
],
// 변경 후
children: [
  _LeagueScoreTab(isDark: context.isDark, accent: context.accentColor),
  _PersonalScoreTab(isDark: context.isDark, accent: context.accentColor),
  _MonthlyTab(isDark: context.isDark, accent: context.accentColor),
  const VerificationTab(),
],
```

- [ ] **Step 2: flutter analyze 확인**

```bash
flutter analyze lib/features/ranking/presentation/screens/ranking_screen.dart
```

Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/ranking/presentation/screens/ranking_screen.dart
git commit -m "feat: 랭킹 화면에 인증 탭 추가, pending 배지 표시"
```

---

## Task 7: 조과 제출 시 인증 요청 연동 + 랭킹 필터

**Files:**
- Modify: `lib/features/feed/data/feed_repository.dart`
- Modify: `lib/features/ranking/data/ranking_repository.dart`

- [ ] **Step 1: FeedRepository.createPost 수정**

`feed_repository.dart`에서 `createPost` 메서드 안의 최종 insert 호출 부분 수정:

```dart
// import 추가 (파일 상단)
import '../../verification/data/verification_repository.dart';
```

`createPost` 메서드 내 `_supabase.from('posts').insert({...})` 호출 부분에서:
```dart
// 변경 전 (insert의 키-값 목록)
'is_lunker': length != null && length >= 50.0,
'score': calculateFishScore(length),

// 변경 후
'is_lunker': length != null && length >= 50.0,
'score': calculateFishScore(length),
'review_status': 'pending',
```

그리고 insert 이후에 인증 요청 생성 코드 추가:

```dart
// 기존 마지막 insert 이후
final inserted = await _supabase.from('posts').insert({
  // ... 기존 필드들 ...
  'review_status': 'pending',
}).select('id').single();

// 인증 요청 생성
final verificationRepo = VerificationRepository(_supabase);
await verificationRepo.createVerificationRequest(
  inserted['id'] as String,
  userId,
);
```

> **주의**: 기존 `.insert({...})` 호출이 `select('id').single()` 없이 끝나는 경우, `.select('id').single()`을 체이닝하여 post id를 받아야 함.

- [ ] **Step 2: RankingRepository 쿼리에 review_status 필터 추가**

`ranking_repository.dart`의 `getLeagueScoreRanking`에서:
```dart
// 변경 전
.not('league_id', 'is', null)
.eq('is_deleted', false)

// 변경 후
.not('league_id', 'is', null)
.eq('is_deleted', false)
.eq('review_status', 'approved')
```

`getPersonalScoreRanking`에서:
```dart
// 변경 전
.eq('is_personal_record', true)
.eq('is_deleted', false)

// 변경 후
.eq('is_personal_record', true)
.eq('is_deleted', false)
.eq('review_status', 'approved')
```

- [ ] **Step 3: flutter analyze 확인**

```bash
flutter analyze lib/features/feed/data/feed_repository.dart lib/features/ranking/data/ranking_repository.dart
```

Expected: No errors

- [ ] **Step 4: 기존 데이터 마이그레이션 (Supabase SQL 에디터)**

기존 posts는 모두 approved 처리 유지 (DB 기본값 'approved'이므로 기존 데이터 변경 불필요).

- [ ] **Step 5: Commit**

```bash
git add lib/features/feed/data/feed_repository.dart lib/features/ranking/data/ranking_repository.dart
git commit -m "feat: 조과 제출 시 인증 요청 자동 생성, 랭킹에 review_status 필터 추가"
```

---

## Task 8: 인증 마크 표시

**Files:**
- Modify: `lib/features/feed/presentation/screens/` (피드 아이템에 인증 마크)

- [ ] **Step 1: PostModel에 인증 상태 확인 헬퍼 추가**

`post_model.dart`의 `Post` factory에는 이미 `review_status` 필드가 있음.
별도 코드 추가 없이 `post.reviewStatus == 'approved'`로 판단 가능.

피드 카드나 상세 화면에서 인증 마크 표시가 필요한 위치를 찾아 아래 위젯 삽입:

```dart
// 인증 마크 위젯 (inline 사용)
if (post.reviewStatus == 'approved' && post.reviewStatus != 'pending')
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.green.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.badgeCheck, size: 11, color: Colors.green[700]),
      const SizedBox(width: 3),
      Text('인증',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.green[700])),
    ]),
  ),
```

> 실제 적용 파일은 피드 화면 구조에 따라 post_detail_screen.dart 또는 피드 카드 위젯에 추가.

- [ ] **Step 2: flutter analyze 확인**

```bash
flutter analyze lib/features/feed/
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/feed/
git commit -m "feat: 인증 완료 게시물에 인증 마크 표시"
```

---

## 최종 검증 체크리스트

- [ ] 조과 제출 → DB에 `catch_verifications` 1건 + `verification_votes` N건 생성 확인
- [ ] 랭킹 > 인증 탭 접근 가능, pending 목록 표시
- [ ] 인증 카드 탭 → 상세 화면 진입, 사진/정보 표시
- [ ] 승인/거부 투표 → DB 반영, 탭 목록 갱신
- [ ] 응답자 3명 이상 + 70% 승인 → post.review_status = 'approved', 랭킹 반영
- [ ] 인증 탭 배지(빨간 점) — pending 없으면 미표시, 있으면 표시
- [ ] 기존 approved 포스트 랭킹 정상 표시 (하위 호환)

---

## 참고: 향후 온도 기능 연동 시

`VerificationRepository.createVerificationRequest`의 유저 풀 조회 부분:

```dart
// 현재 (임시): 모든 유저 중 랜덤
final candidates = await _supabase.from('users').select('id').neq('id', submitterId).limit(50);

// 온도 기능 추가 후: 온도 임계값 이상만
final candidates = await _supabase.from('users').select('id').neq('id', submitterId).gte('angler_temperature', 30.0).limit(50);
```
