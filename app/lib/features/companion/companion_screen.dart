import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/trend_bucketing.dart';
import '../../core/pairing/companion_data_service.dart';
import '../../core/pairing/companion_link_store.dart';
import '../../core/pairing/nudge_service.dart';
import '../../core/pairing/pairing_service.dart';
import '../../core/theme/blowfit_colors.dart';

/// 동반자(배우자·애인) 홈 — Figma node 88:2.
///
/// 연결 전: 연결 코드 입력 안내. 연결 후: 사용자 훈련 현황(오늘 요약 / 달력 /
/// 호기·흡기 추이) + 눈치주기 버튼(알림 전송은 Phase E).
class CompanionScreen extends ConsumerWidget {
  const CompanionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkAsync = ref.watch(companionLinkProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFDFF3F0),
      body: linkAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: BlowfitColors.blue500),
        ),
        error: (_, __) => const SafeArea(child: _ConnectPrompt()),
        data: (link) => link == null
            ? const SafeArea(child: _ConnectPrompt())
            : _Dashboard(link: link),
      ),
    );
  }
}

// ===========================================================================
// 연결 전 — 연결 코드 입력 안내.
// ===========================================================================
class _ConnectPrompt extends StatelessWidget {
  const _ConnectPrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandRow(),
          const Spacer(),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: BlowfitColors.blue50,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.link_rounded,
                  size: 44, color: BlowfitColors.blue500,),
            ),
          ),
          const SizedBox(height: 24),
          const Text('아직 연결된 사용자가 없어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BlowfitColors.ink,),),
          const SizedBox(height: 10),
          const Text(
            '디바이스 사용자의 연결 코드를 입력하면\n훈련 현황을 보고 응원할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: BlowfitColors.ink3,
                fontWeight: FontWeight.w500,),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/companion/link'),
              style: FilledButton.styleFrom(
                backgroundColor: BlowfitColors.blue500,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BlowfitRadius.lg),),
              ),
              child: const Text('연결 코드 입력',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 연결 후 — 훈련 현황 대시보드.
// ===========================================================================
class _Dashboard extends ConsumerStatefulWidget {
  const _Dashboard({required this.link});
  final CompanionLink link;

  @override
  ConsumerState<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<_Dashboard> {
  TrendPeriod _period = TrendPeriod.daily;
  late DateTime _calMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calMonth = DateTime(now.year, now.month);
  }

  Future<void> _nudge() async {
    try {
      await ref
          .read(nudgeServiceProvider)
          .sendNudge(userId: widget.link.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.link.userName}님께 응원을 보냈어요! 💪')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전송에 실패했어요. 네트워크를 확인해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.link.userName;
    final today = ref.watch(companionTodayProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 — 로고 + 눈치주기.
            Row(
              children: [
                const _BrandRow(),
                const Spacer(),
                _NudgeButton(onTap: _nudge),
              ],
            ),
            const SizedBox(height: 18),
            Text('안녕하세요. $name 배우자님 😊',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BlowfitColors.ink2,),),
            const SizedBox(height: 4),
            Text('$name님의 훈련 현황이에요!',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: BlowfitColors.ink,),),
            const SizedBox(height: 18),
            _TodayCard(today: today),
            const SizedBox(height: 16),
            _CalendarCard(
              month: _calMonth,
              trainedDays: _trainedDaysFor(_calMonth),
              onPrev: () => setState(() =>
                  _calMonth = DateTime(_calMonth.year, _calMonth.month - 1),),
              onNext: () => setState(() =>
                  _calMonth = DateTime(_calMonth.year, _calMonth.month + 1),),
            ),
            const SizedBox(height: 16),
            _TrendCard(
              period: _period,
              buckets: _bucketsFor(_period),
              onPeriod: (p) => setState(() => _period = p),
            ),
          ],
        ),
      ),
    );
  }

  Set<int> _trainedDaysFor(DateTime month) {
    final sessions = ref.watch(companionLocalSessionsProvider);
    final start = DateTime(month.year, month.month);
    final next = DateTime(month.year, month.month + 1);
    final days = <int>{};
    for (final s in sessions) {
      final t = s.receivedAt;
      if (t.isBefore(start) || !t.isBefore(next)) continue;
      days.add(t.day);
    }
    return days;
  }

  List<TrendBucket> _bucketsFor(TrendPeriod p) {
    final sessions = ref.watch(companionLocalSessionsProvider);
    return bucketizeForPeriod(sessions, p);
  }
}

// ===========================================================================
// 공통 — 로고 / 눈치주기 버튼.
// ===========================================================================
class _BrandRow extends StatelessWidget {
  const _BrandRow();
  @override
  Widget build(BuildContext context) {
    return const Text('BRELOW',
        style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: BlowfitColors.blue500,
            letterSpacing: -0.4,),);
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: BlowfitColors.ink,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text('눈치주기',
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,),),
      ),
    );
  }
}

// ===========================================================================
// 오늘 요약 카드.
// ===========================================================================
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today});
  final CompanionToday today;

  static const _goalMin = 30;

  @override
  Widget build(BuildContext context) {
    final pct = (today.totalMinutes / _goalMin).clamp(0.0, 1.0);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('오늘 총 ${today.sessionCount}회 하셨어요!',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: BlowfitColors.ink,),),
              const Spacer(),
              Text('${(pct * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: BlowfitColors.blue500,),),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: BlowfitColors.gray150,
              valueColor:
                  const AlwaysStoppedAnimation(BlowfitColors.blue500),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: '날숨',
                  value: today.avgExhale.round().toString(),
                  unit: 'cmH₂O',
                  color: DotColorsLite.exhale,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: '들숨',
                  value: today.avgInhale.round().toString(),
                  unit: 'cmH₂O',
                  color: DotColorsLite.inhale,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: BlowfitColors.gray100,
        borderRadius: BorderRadius.circular(BlowfitRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BlowfitColors.ink2,),),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: BlowfitColors.ink,),),
              const SizedBox(width: 4),
              Text(unit,
                  style: const TextStyle(
                      fontSize: 12, color: BlowfitColors.ink3,),),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 달력 카드 — 훈련한 날 하이라이트.
// ===========================================================================
class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.trainedDays,
    required this.onPrev,
    required this.onNext,
  });
  final DateTime month;
  final Set<int> trainedDays;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(month.year, month.month, 1).weekday % 7; // 일=0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();
    final cells = <Widget>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final trained = trainedDays.contains(d);
      final isToday = today.year == month.year &&
          today.month == month.month &&
          today.day == d;
      cells.add(_DayCell(day: d, trained: trained, isToday: isToday));
    }
    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left, size: 22),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text('${month.year}년 ${month.month}월',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: BlowfitColors.ink,),),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right, size: 22),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: ['일', '월', '화', '수', '목', '금', '토']
                .asMap()
                .entries
                .map((e) => Expanded(
                      child: Center(
                        child: Text(e.value,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: e.key == 0
                                    ? DotColorsLite.sunday
                                    : (e.key == 6
                                        ? DotColorsLite.saturday
                                        : BlowfitColors.ink3),),),
                      ),
                    ),)
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1,
            children: cells,
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell(
      {required this.day, required this.trained, required this.isToday,});
  final int day;
  final bool trained;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (isToday) {
      bg = BlowfitColors.blue500;
      fg = Colors.white;
    } else if (trained) {
      bg = BlowfitColors.blue100;
      fg = BlowfitColors.blue700;
    } else {
      bg = Colors.transparent;
      fg = BlowfitColors.ink3;
    }
    return Center(
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text('$day',
            style: TextStyle(
                fontSize: 13,
                fontWeight:
                    trained || isToday ? FontWeight.w700 : FontWeight.w500,
                color: fg,),),
      ),
    );
  }
}

// ===========================================================================
// 추이 카드 — 호기/흡기 평균 라인 차트.
// ===========================================================================
class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.period,
    required this.buckets,
    required this.onPeriod,
  });
  final TrendPeriod period;
  final List<TrendBucket> buckets;
  final ValueChanged<TrendPeriod> onPeriod;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final p in TrendPeriod.values)
                Expanded(child: _Tab(p: p, selected: p == period, onTap: () => onPeriod(p))),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              _Legend(color: DotColorsLite.exhale, label: '날숨 평균'),
              SizedBox(width: 16),
              _Legend(color: DotColorsLite.inhale, label: '들숨 평균'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: 200, child: _Chart(buckets: buckets)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.p, required this.selected, required this.onTap});
  final TrendPeriod p;
  final bool selected;
  final VoidCallback onTap;

  static const _labels = {
    TrendPeriod.daily: '일간',
    TrendPeriod.weekly: '주간',
    TrendPeriod.monthly: '월간',
    TrendPeriod.yearly: '년간',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? BlowfitColors.blue50 : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(_labels[p]!,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? BlowfitColors.blue500 : BlowfitColors.ink3,),),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: BlowfitColors.ink2,),),
      ],
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.buckets});
  final List<TrendBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final exhale = <FlSpot>[];
    final inhale = <FlSpot>[];
    for (final b in buckets) {
      final x = b.xPos.toDouble();
      if (b.avgExhale != null && b.avgExhale! > 0) {
        exhale.add(FlSpot(x, b.avgExhale!));
      }
      if (b.avgInhale != null && b.avgInhale! > 0) {
        inhale.add(FlSpot(x, -b.avgInhale!));
      }
    }
    final hasData = exhale.isNotEmpty || inhale.isNotEmpty;
    if (!hasData) {
      return const Center(
        child: Text('아직 훈련 기록이 없어요',
            style: TextStyle(color: BlowfitColors.ink3, fontSize: 13),),
      );
    }
    return LineChart(
      LineChartData(
        minY: -35,
        maxY: 35,
        minX: 0.5,
        maxX: buckets.length + 0.5,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (v) => FlLine(
            color: v == 0 ? BlowfitColors.gray300 : BlowfitColors.gray150,
            strokeWidth: v == 0 ? 1.2 : 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 10,
              reservedSize: 34,
              getTitlesWidget: (v, _) => Text(
                v == 0 ? '0' : (v > 0 ? '+${v.toInt()}' : '${v.toInt()}'),
                style: const TextStyle(
                    fontSize: 9, color: BlowfitColors.ink3,),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final i = v.round() - 1;
                if (i < 0 || i >= buckets.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(buckets[i].label,
                      style: const TextStyle(
                          fontSize: 9, color: BlowfitColors.ink3,),),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          if (exhale.isNotEmpty)
            _line(exhale, DotColorsLite.exhale),
          if (inhale.isNotEmpty)
            _line(inhale, DotColorsLite.inhale),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
        spots: spots,
        color: color,
        barWidth: 2.5,
        isCurved: true,
        curveSmoothness: 0.25,
        dotData: FlDotData(
          show: true,
          getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
              radius: 3, color: color, strokeWidth: 0,),
        ),
      );
}

// ===========================================================================
// 공통 카드 컨테이너.
// ===========================================================================
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BlowfitRadius.xl),
        boxShadow: BlowfitColors.shadowLevel1,
      ),
      child: child,
    );
  }
}

/// 차트/통계 색 (DotColors 의 라이트 일부만 사용).
class DotColorsLite {
  DotColorsLite._();
  static const exhale = Color(0xFF0A89FC); // 호기 = 파랑
  static const inhale = Color(0xFF32B65E); // 흡기 = 초록
  static const sunday = Color(0xFFFF3B30);
  static const saturday = Color(0xFF0088FF);
}
