import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_widgets.dart';

/// 훈련 기록 (캘린더). 디자인 시안의 07 화면 (`screens/calendar.jsx`).
///
/// 변경: 주간/월간 trend 탭 → 월별 캘린더 그리드 + streak hero + recent
/// sessions 리스트.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  // 표시 중인 달의 1일. setState 로 ‹/› 버튼이 갱신.
  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month, 1);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(sessionRepositoryProvider);
    final consecutiveDays =
        ref.watch(consecutiveDaysProvider).valueOrNull ?? 0;
    final weekHits = ref.watch(weekHitsProvider).valueOrNull ?? 0;

    // 6개월 lookback — 캘린더 + 최근 세션 모두 충분히 커버.
    final since =
        DateTime.now().subtract(const Duration(days: 200));

    return Scaffold(
      appBar: AppBar(
        title: const Text('훈련 기록'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Session>>(
          stream: repo.watchSince(since),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final sessions = snap.data!;
            final newestFirst = sessions.reversed.toList(growable: false);
            final monthSessions =
                _filterMonth(sessions, _viewMonth);
            final monthDays = _trainedDays(monthSessions);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _StreakHero(days: consecutiveDays),
                const SizedBox(height: 12),
                _StatsTriple(
                  monthCount: monthDays.length,
                  weekCount: weekHits,
                  totalCount: sessions.length,
                ),
                const SizedBox(height: 14),
                _CalendarCard(
                  viewMonth: _viewMonth,
                  trainedDays: monthDays,
                  onPrev: () => _shiftMonth(-1),
                  onNext: () => _shiftMonth(1),
                ),
                const SizedBox(height: 14),
                _RecentSessionsHeader(),
                const SizedBox(height: 8),
                if (newestFirst.isEmpty)
                  const _EmptyHint()
                else
                  _RecentSessionsList(sessions: newestFirst.take(5).toList()),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 해당 달에 속하는 세션만 필터.
  List<Session> _filterMonth(List<Session> all, DateTime monthStart) {
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    return all
        .where((s) =>
            !s.receivedAt.isBefore(monthStart) &&
            s.receivedAt.isBefore(monthEnd))
        .toList(growable: false);
  }

  /// 훈련한 날짜 (year-month-day) 의 day 만 모음. 월별 캘린더 그리드용.
  Set<int> _trainedDays(List<Session> sessions) {
    return sessions.map((s) => s.receivedAt.day).toSet();
  }
}

// ---------------------------------------------------------------------------
// Streak hero — orange gradient with flame
// ---------------------------------------------------------------------------

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.days});
  final int days;

  int get _nextGoal {
    const goals = [3, 7, 14, 21, 30, 60, 100];
    for (final g in goals) {
      if (days < g) return g;
    }
    return days + 30;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BlowfitRadius.xl),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB347), Color(0xFFFF7A00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(255, 122, 0, 0.20),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color.fromRGBO(255, 255, 255, 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.local_fire_department,
                  size: 36, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '연속 훈련',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color.fromRGBO(255, 255, 255, 0.9),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$days',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.72,
                        height: 1.1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      '일',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '다음 목표: $_nextGoal일 연속!',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color.fromRGBO(255, 255, 255, 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats triple — 이번 달 / 이번 주 / 총 훈련
// ---------------------------------------------------------------------------

class _StatsTriple extends StatelessWidget {
  const _StatsTriple({
    required this.monthCount,
    required this.weekCount,
    required this.totalCount,
  });

  final int monthCount;
  final int weekCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _MiniStat(
                label: '이번 달', value: '$monthCount', unit: '일')),
        const SizedBox(width: 8),
        Expanded(
            child: _MiniStat(
                label: '이번 주', value: '$weekCount', unit: '회')),
        const SizedBox(width: 8),
        Expanded(
            child: _MiniStat(
                label: '총 훈련', value: '$totalCount', unit: '회')),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return BlowfitCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: BlowfitColors.ink3,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BlowfitColors.ink,
                  letterSpacing: -0.4,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 11,
                  color: BlowfitColors.ink3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar card — month grid + day-of-week header + legend
// ---------------------------------------------------------------------------

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.viewMonth,
    required this.trainedDays,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime viewMonth;
  final Set<int> trainedDays;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isCurrentMonth =
        viewMonth.year == today.year && viewMonth.month == today.month;
    final todayDay = isCurrentMonth ? today.day : -1;

    final monthLabel =
        DateFormat('y년 M월', 'ko').format(viewMonth);
    final daysInMonth =
        DateTime(viewMonth.year, viewMonth.month + 1, 0).day;
    // DateTime weekday: 1=Mon..7=Sun. 디자인은 일=0 부터 시작 → 변환.
    final firstWeekday = DateTime(viewMonth.year, viewMonth.month, 1).weekday;
    final firstOffset = firstWeekday % 7; // Sun=0..Sat=6

    final cells = <int?>[];
    for (var i = 0; i < firstOffset; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(d);
    }

    return BlowfitCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left,
                    size: 20, color: BlowfitColors.ink),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Text(
                monthLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BlowfitColors.ink,
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right,
                    size: 20, color: BlowfitColors.ink),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 요일 헤더 (일 ~ 토)
          Row(
            children: List.generate(7, (i) {
              const labels = ['일', '월', '화', '수', '목', '금', '토'];
              final color = i == 0
                  ? BlowfitColors.red500
                  : i == 6
                      ? BlowfitColors.blue500
                      : BlowfitColors.ink3;
              return Expanded(
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // 일자 그리드
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: cells.length,
            itemBuilder: (_, i) {
              final day = cells[i];
              if (day == null) return const SizedBox.shrink();
              final trained = trainedDays.contains(day);
              final isToday = day == todayDay;
              return _CalendarCell(
                day: day,
                trained: trained,
                isToday: isToday,
              );
            },
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: BlowfitColors.gray150),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: BlowfitColors.blue500, label: '오늘'),
              SizedBox(width: 16),
              _LegendItem(color: BlowfitColors.blue50, label: '훈련 완료'),
              SizedBox(width: 16),
              _LegendItem(color: BlowfitColors.gray200, label: '미훈련'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.trained,
    required this.isToday,
  });

  final int day;
  final bool trained;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Border? border;
    if (isToday) {
      bg = trained ? BlowfitColors.blue500 : Colors.transparent;
      fg = trained ? Colors.white : BlowfitColors.blue500;
      border = trained
          ? null
          : Border.all(color: BlowfitColors.blue500, width: 2);
    } else if (trained) {
      bg = BlowfitColors.blue50;
      fg = BlowfitColors.blue600;
      border = null;
    } else {
      bg = Colors.transparent;
      fg = BlowfitColors.ink2;
      border = null;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: border,
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: trained ? FontWeight.w700 : FontWeight.w500,
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        if (trained && !isToday)
          const Positioned(
            bottom: 2,
            child: SizedBox(
              width: 4,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BlowfitColors.green500,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: BlowfitColors.ink3,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recent sessions
// ---------------------------------------------------------------------------

class _RecentSessionsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '최근 세션',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: BlowfitColors.ink,
        ),
      ),
    );
  }
}

class _RecentSessionsList extends StatelessWidget {
  const _RecentSessionsList({required this.sessions});
  final List<Session> sessions;

  @override
  Widget build(BuildContext context) {
    return BlowfitCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < sessions.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: BlowfitColors.gray150),
            _SessionRow(session: sessions[i]),
          ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});
  final Session session;

  String _relativeDate(DateTime t) {
    final today = DateTime.now();
    final dt = DateTime(t.year, t.month, t.day);
    final today0 = DateTime(today.year, today.month, today.day);
    final diff = today0.difference(dt).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return DateFormat('M월 d일', 'ko').format(t);
  }

  String _hm(DateTime t) => DateFormat('HH:mm').format(t);

  String _dur(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// 세션의 점수 — result_screen 의 공식과 동일.
  int _score(Session s) {
    if (s.durationSec <= 0) return 0;
    final endRatio =
        (s.enduranceSec / s.durationSec).clamp(0.0, 1.0);
    final hitsPart = (s.targetHits.clamp(0, 5) / 5) * 50;
    return (hitsPart + endRatio * 50).round().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final when = session.startedAt ?? session.receivedAt;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/session/${session.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BlowfitColors.blue50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.air,
                    size: 22, color: BlowfitColors.blue500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _relativeDate(when),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: BlowfitColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_hm(when)} · ${_dur(session.durationSec)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: BlowfitColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_score(session)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: BlowfitColors.blue500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Text(
                    '점수',
                    style: TextStyle(
                      fontSize: 10,
                      color: BlowfitColors.ink3,
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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return BlowfitCard(
      padding: const EdgeInsets.all(20),
      child: const Center(
        child: Text(
          '아직 완료한 세션이 없어요\n첫 훈련을 시작해보세요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: BlowfitColors.ink3,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
