// 수면 추이 화면 — 추이(Trend) 화면과 동일한 비주얼 스타일.
//   잔디/하늘 배경(추이와 동일 페인터) + 헤더(로고/설정/알림) +
//   요약 카드 + 최저 SpO₂ 라인차트 카드 + 측정 달력 카드.
// 데이터: sleep_records (실측, 없으면 데모 시드).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/health/sleep_analysis.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_theme.dart';
import '../settings/settings_screen.dart';

const double _kFrameW = 402;
const double _kFrameH = 980;

const _ink = Color(0xFF101010);
const _ink2 = Color(0xFF252525);
const _muted = Color(0xFF898989);
const _calGray = Color(0xFF808080);

class _Frame {
  _Frame(this.screenW) : scale = screenW / _kFrameW;
  final double screenW;
  final double scale;
  double sx(double v) => v * scale;

  Positioned at({
    required double x,
    required double y,
    double? w,
    double? h,
    required Widget child,
  }) {
    return Positioned(
      left: sx(x),
      top: sx(y),
      width: w == null ? null : sx(w),
      height: h == null ? null : sx(h),
      child: child,
    );
  }
}

class SleepTrendScreen extends ConsumerStatefulWidget {
  const SleepTrendScreen({super.key});
  @override
  ConsumerState<SleepTrendScreen> createState() => _SleepTrendScreenState();
}

class _SleepTrendScreenState extends ConsumerState<SleepTrendScreen> {
  DateTime _calMonth = _thisMonth();
  static DateTime _thisMonth() {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final f = _Frame(media.size.width);
    final records = ref.watch(recentSleepProvider).valueOrNull ?? const [];
    final sorted = [...records]..sort((a, b) => a.night.compareTo(b.night));
    final effect = computeSleepEffect(records);

    return Scaffold(
      backgroundColor: const Color(0xFF4BA22B),
      body: SingleChildScrollView(
        child: SizedBox(
          width: media.size.width,
          height: f.sx(_kFrameH),
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (_, c) => CustomPaint(
                    size: Size(c.maxWidth, c.maxHeight),
                    painter: _SleepBgPainter(),
                  ),
                ),
              ),
              _content(context, f, sorted, effect),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    _Frame f,
    List<SleepRecord> sorted,
    SleepEffect effect,
  ) {
    final headline = _headline(effect);
    return Stack(
      children: [
        // 로고
        f.at(
          x: 17,
          y: 56,
          w: 81,
          h: 22,
          child: Image.asset('assets/dot/logo.png',
              fit: BoxFit.contain, filterQuality: FilterQuality.high),
        ),
        // 설정
        f.at(
          x: 308,
          y: 41,
          w: 44,
          h: 44,
          child: Builder(
            builder: (ctx) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: SvgPicture.asset('assets/dot/icon_settings.svg',
                    width: f.sx(22),
                    height: f.sx(21),
                    colorFilter:
                        const ColorFilter.mode(_ink, BlendMode.srcIn)),
              ),
            ),
          ),
        ),
        // 알림 종
        f.at(
          x: 354,
          y: 41,
          w: 44,
          h: 44,
          child: Center(
            child: SvgPicture.asset('assets/dot/icon_bell.svg',
                width: f.sx(18),
                height: f.sx(20),
                colorFilter: const ColorFilter.mode(_ink, BlendMode.srcIn)),
          ),
        ),
        // "수면 추이"
        f.at(
          x: 19,
          y: 105,
          child: Text('수면 추이',
              style: TextStyle(
                  fontSize: f.sx(15),
                  fontWeight: FontWeight.w600,
                  color: _ink.withValues(alpha: 0.7),
                  fontFamily: BlowfitTheme.fontFamily)),
        ),
        // 헤드라인
        f.at(
          x: 19,
          y: 127,
          w: 364,
          child: Text(headline,
              style: TextStyle(
                  fontSize: f.sx(20),
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  letterSpacing: -0.4,
                  fontFamily: BlowfitTheme.fontFamily)),
        ),
        // 요약 카드
        f.at(
          x: 20,
          y: 175,
          w: 362,
          h: 91,
          child: _SummaryCard(f: f, records: sorted),
        ),
        // 차트 카드 — 최저 SpO₂ 추이
        f.at(
          x: 20,
          y: 290,
          w: 362,
          h: 250,
          child: _Spo2TrendCard(f: f, records: sorted),
        ),
        // 달력 카드 — 측정한 밤
        f.at(
          x: 20,
          y: 560,
          w: 362,
          h: 348,
          child: _SleepCalendarCard(
            f: f,
            month: _calMonth,
            records: sorted,
            onPrev: () => setState(() =>
                _calMonth = DateTime(_calMonth.year, _calMonth.month - 1)),
            onNext: () => setState(() =>
                _calMonth = DateTime(_calMonth.year, _calMonth.month + 1)),
          ),
        ),
      ],
    );
  }

  String _headline(SleepEffect e) {
    final d = e.spo2MinDelta;
    if (e.nights == 0) return '수면 데이터를 모아볼까요?';
    if (d == null) return '수면을 꾸준히 기록해 봐요!';
    if (d >= 0.5) return '최저 SpO₂가 ${d.toStringAsFixed(1)}%p 좋아졌어요!';
    if (d <= -0.5) return '최저 SpO₂가 ${(-d).toStringAsFixed(1)}%p 낮아졌어요';
    return '최저 SpO₂가 비슷하게 유지돼요';
  }
}

// ───────────────────────── 요약 카드 ─────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.f, required this.records});
  final _Frame f;
  final List<SleepRecord> records;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysFromMon = now.weekday - DateTime.monday;
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysFromMon));
    final monthStart = DateTime(now.year, now.month, 1);
    var week = 0, month = 0;
    for (final r in records) {
      if (!r.night.isBefore(monday)) week++;
      if (!r.night.isBefore(monthStart)) month++;
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(f.sx(10)),
      ),
      child: Stack(
        children: [
          Positioned(
              left: f.sx(117),
              top: f.sx(17),
              child:
                  Container(width: 1, height: f.sx(58), color: Colors.black12)),
          Positioned(
              left: f.sx(241),
              top: f.sx(17),
              child:
                  Container(width: 1, height: f.sx(58), color: Colors.black12)),
          _col(0, 117, '이번 주', '$week박'),
          _col(117, 241, '이번 달', '$month박'),
          _col(241, 362, '지금까지', '${records.length}박'),
        ],
      ),
    );
  }

  Widget _col(double l, double r, String label, String value) => Positioned(
        left: f.sx(l),
        width: f.sx(r - l),
        top: f.sx(18),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: f.sx(12),
                    fontWeight: FontWeight.w500,
                    color: _ink,
                    fontFamily: BlowfitTheme.fontFamily)),
            SizedBox(height: f.sx(2)),
            Text(value,
                style: TextStyle(
                    fontSize: f.sx(27),
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    fontFamily: BlowfitTheme.fontFamily)),
          ],
        ),
      );
}

// ───────────────────────── 차트 카드 ─────────────────────────
class _Spo2TrendCard extends StatelessWidget {
  const _Spo2TrendCard({required this.f, required this.records});
  final _Frame f;
  final List<SleepRecord> records; // asc

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(f.sx(10)),
      ),
      child: Stack(
        children: [
          // legend
          Positioned(
            left: f.sx(16),
            top: f.sx(14),
            child: Row(
              children: [
                Container(
                    width: f.sx(9),
                    height: f.sx(9),
                    decoration: BoxDecoration(
                        color: DotColors.primary,
                        borderRadius: BorderRadius.circular(f.sx(1)))),
                SizedBox(width: f.sx(6)),
                Text('최저 SpO₂ (%)',
                    style: TextStyle(
                        fontSize: f.sx(10),
                        fontWeight: FontWeight.w500,
                        color: _ink2,
                        fontFamily: BlowfitTheme.fontFamily)),
              ],
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _Spo2LinePainter(scale: f.scale, records: records),
            ),
          ),
          if (records.every((r) => r.spo2Min == null))
            Center(
              child: Text('SpO₂ 데이터 없음',
                  style: TextStyle(
                      fontSize: f.sx(12),
                      color: _muted,
                      fontFamily: BlowfitTheme.fontFamily)),
            ),
        ],
      ),
    );
  }
}

class _Spo2LinePainter extends CustomPainter {
  _Spo2LinePainter({required this.scale, required this.records});
  final double scale;
  final List<SleepRecord> records;
  static const _yMin = 80.0, _yMax = 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final padL = size.width * 0.12;
    final padR = size.width * 0.05;
    final padT = size.height * 0.24;
    final padB = size.height * 0.10;
    final plot = Rect.fromLTRB(padL, padT, size.width - padR, size.height - padB);

    double yFor(double v) =>
        plot.top + (_yMax - v.clamp(_yMin, _yMax)) / (_yMax - _yMin) * plot.height;

    // grid + Y labels (100/95/90/85/80)
    final grid = Paint()
      ..color = _muted.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (final v in const [100.0, 95.0, 90.0, 85.0, 80.0]) {
      final y = yFor(v);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final tp = TextPainter(
        text: TextSpan(
          text: v.toStringAsFixed(0),
          style: TextStyle(
              color: _muted,
              fontSize: 8 * scale,
              fontFamily: BlowfitTheme.fontFamily),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(plot.left - tp.width - 4 * scale, y - tp.height / 2));
    }

    // line + dots
    final n = records.length;
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final v = records[i].spo2Min;
      if (v == null) continue;
      final x = plot.left + (n == 1 ? 0.5 : i / (n - 1)) * plot.width;
      pts.add(Offset(x, yFor(v)));
    }
    if (pts.isEmpty) return;
    if (pts.length > 1) {
      final line = Paint()
        ..color = DotColors.primary
        ..strokeWidth = 2 * scale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, line);
    }
    final dot = Paint()..color = DotColors.primary;
    for (final p in pts) {
      canvas.drawCircle(p, 3 * scale, dot);
    }
  }

  @override
  bool shouldRepaint(_Spo2LinePainter old) => old.records != records;
}

// ───────────────────────── 달력 카드 ─────────────────────────
class _SleepCalendarCard extends StatelessWidget {
  const _SleepCalendarCard({
    required this.f,
    required this.month,
    required this.records,
    required this.onPrev,
    required this.onNext,
  });
  final _Frame f;
  final DateTime month;
  final List<SleepRecord> records;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static const _measuredCircle = Color(0xFFA5D3FF);
  static const _todayCircle = Color(0xFF0084FF);
  static const _measuredText = Color(0xFF2F2F2F);

  @override
  Widget build(BuildContext context) {
    final measured = <int>{};
    for (final r in records) {
      if (r.night.year == month.year && r.night.month == month.month) {
        measured.add(r.night.day);
      }
    }
    final now = DateTime.now();
    final isThisMonth = now.year == month.year && now.month == month.month;
    final firstDow = DateTime(month.year, month.month, 1).weekday % 7; // Sun=0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    const labels = ['일', '월', '화', '수', '목', '금', '토'];

    final cells = <Widget>[];
    var day = 1;
    for (var row = 0; row < 6; row++) {
      for (var col = 0; col < 7; col++) {
        final idx = row * 7 + col;
        if (idx < firstDow || day > daysInMonth) {
          cells.add(const SizedBox());
          continue;
        }
        final d = day;
        final isToday = isThisMonth && d == now.day;
        final isMeasured = measured.contains(d);
        cells.add(Center(
          child: Container(
            width: f.sx(30),
            height: f.sx(30),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday
                  ? _todayCircle
                  : (isMeasured ? _measuredCircle : Colors.transparent),
              shape: BoxShape.circle,
            ),
            child: Text('$d',
                style: TextStyle(
                  fontSize: f.sx(13),
                  fontWeight:
                      isToday || isMeasured ? FontWeight.w600 : FontWeight.w400,
                  color: isToday
                      ? Colors.white
                      : (isMeasured ? _measuredText : _calGray),
                  fontFamily: BlowfitTheme.fontFamily,
                )),
          ),
        ));
        day++;
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: f.sx(20), vertical: f.sx(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(f.sx(10)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                  onTap: onPrev,
                  child: Icon(Icons.chevron_left, color: _ink, size: f.sx(20))),
              Text('${month.year}년 ${month.month}월',
                  style: TextStyle(
                      fontSize: f.sx(15),
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      fontFamily: BlowfitTheme.fontFamily)),
              GestureDetector(
                  onTap: onNext,
                  child:
                      Icon(Icons.chevron_right, color: _ink, size: f.sx(20))),
            ],
          ),
          SizedBox(height: f.sx(12)),
          Row(
            children: [
              for (final l in labels)
                Expanded(
                  child: Center(
                    child: Text(l,
                        style: TextStyle(
                            fontSize: f.sx(11),
                            fontWeight: FontWeight.w500,
                            color: _calGray,
                            fontFamily: BlowfitTheme.fontFamily)),
                  ),
                ),
            ],
          ),
          SizedBox(height: f.sx(6)),
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 7,
              children: cells,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 배경 페인터 (추이와 동일) ─────────────────────────
class _SleepBgPainter extends CustomPainter {
  static const _e47Width = 1017.3922729492188;
  static const _e47Height = 1284.04150390625;
  static const _e47Transform = <List<double>>[
    [0.9964643716812134, -0.08401674032211304, -453.1190185546875],
    [0.08401674032211304, 0.9964643716812134, 650.0],
  ];
  static const _e47Colors = <Color>[
    Color(0xFFCFFF94),
    Color(0xFF89C76A),
    Color(0xFF4BA22B),
  ];
  static const _e47Stops = <double>[0.0, 0.5144, 1.0];

  static const _e48Width = 488.5125427246094;
  static const _e48Height = 503.53411865234375;
  static const _e48Transform = <List<double>>[
    [0.7538431286811829, -0.6570544242858887, 323.30615234375],
    [0.6570544242858887, 0.7538431286811829, 455.0],
  ];
  static const _e48Colors = <Color>[Color(0xFFE2F8C8), Color(0xFF78CA59)];
  static const _e48Stops = <double>[0.0, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint();
    final scale = size.width / _kFrameW;

    paint.shader = const LinearGradient(
      begin: Alignment(-0.4, -1.0),
      end: Alignment(0.4, 1.0),
      stops: [0.082, 0.589, 1.0],
      colors: [
        DotColors.lightBgTop,
        DotColors.lightBgBottom,
        DotColors.lightBgBottom,
      ],
    ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;

    _drawEllipse(canvas, scale, _e48Transform, _e48Width, _e48Height,
        _e48Colors, _e48Stops, 70);
    _drawEllipse(canvas, scale, _e47Transform, _e47Width, _e47Height,
        _e47Colors, _e47Stops, 18.1);
  }

  void _drawEllipse(Canvas canvas, double scale, List<List<double>> m, double w,
      double h, List<Color> colors, List<double> stops, double blurSigma) {
    canvas.save();
    canvas.scale(scale, scale);
    canvas.transform(Float64List.fromList(<double>[
      m[0][0], m[1][0], 0, 0,
      m[0][1], m[1][1], 0, 0,
      0, 0, 1, 0,
      m[0][2], m[1][2], 0, 1,
    ]));
    final rect = Rect.fromLTWH(0, 0, w, h);
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: stops,
    ).createShader(rect);
    final paint = Paint()..shader = shader;
    final blurBounds = rect.inflate(blurSigma * 2);
    canvas.saveLayer(
      blurBounds,
      Paint()
        ..imageFilter =
            ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
    );
    canvas.drawOval(rect, paint);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SleepBgPainter old) => false;
}
