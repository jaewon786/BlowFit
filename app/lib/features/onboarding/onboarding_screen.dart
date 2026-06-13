import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/blowfit_colors.dart';

/// 첫 사용 가이드 (디자인 시안의 01 화면).
///
/// 4단계 슬라이드 — 환영 / 마우스피스 / 다이얼 / 호흡 방향. 각 단계마다
/// 큰 일러스트 + 제목 + 설명 + 다음 버튼.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  static const _steps = <_Step>[
    _Step(
      title: 'BRELOW에 오신 것을\n환영합니다',
      desc: '매일 5분, 호흡근을 단련하여\n수면의 질을 개선하세요.',
      illust: _IllustKind.welcome,
    ),
    _Step(
      title: '마우스피스를\n입에 물어주세요',
      desc: '입으로 가볍게 물고,\n입술로 공기가 새지 않도록 감싸주세요.',
      illust: _IllustKind.mouthpiece,
    ),
    _Step(
      title: '다이얼은\n1단계부터 시작',
      desc: '처음에는 가장 약한 저항으로 시작하고,\n익숙해지면 단계를 올려보세요.',
      illust: _IllustKind.dial,
    ),
    _Step(
      title: '입으로 양방향\n호흡하세요',
      desc: '들이쉴 때도, 내쉴 때도 모두 입으로.\n천천히 깊게 호흡하는 것이 핵심입니다.',
      illust: _IllustKind.breath,
    ),
    // ─── 앱 소개 (기기 사용법 다음, 프로필 설정 직전) ──────────────────
    _Step(
      title: '화면이 호흡을\n안내해요',
      desc: '게이지를 보며 들숨·날숨을 맞추고,\n목표 압력까지 부드럽게 채워보세요.',
      illust: _IllustKind.introGuide,
    ),
    _Step(
      title: '나에게 맞는\n목표 압력',
      desc: '최대 호흡력을 측정해\n내 수준에 맞는 강도로 안전하게 훈련해요.',
      illust: _IllustKind.introTarget,
    ),
    _Step(
      title: '꾸준히 하면\n캐릭터가 자라요',
      desc: '훈련을 쌓을수록 알에서 산소로\n한 단계씩 진화합니다.',
      illust: _IllustKind.introGrow,
    ),
    _Step(
      title: '기록하고\n함께해요',
      desc: '훈련 기록과 추이를 확인하고,\n소중한 사람이 곁에서 응원해 줘요.',
      illust: _IllustKind.introCompanion,
    ),
  ];

  void _next() {
    if (_step >= _steps.length - 1) {
      // 디자인 v2 — 온보딩 끝 → 프로필 설정 → 페어링.
      context.go('/profile-setup');
      return;
    }
    setState(() => _step += 1);
  }

  void _back() {
    if (_step <= 0) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
      return;
    }
    setState(() => _step -= 1);
  }

  void _skip() => context.go('/profile-setup');

  @override
  Widget build(BuildContext context) {
    final cur = _steps[_step];
    final last = _step == _steps.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              step: _step,
              total: _steps.length,
              onBack: _back,
              onSkip: _skip,
            ),
            Expanded(
              // 디자인 v2 — 4 step 모두 일러스트와 텍스트가 동일 위치.
              // 80px top spacer + 220×220 frame + 32px gap + 140 minHeight 텍스트.
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  SizedBox(
                    width: double.infinity,
                    height: 220,
                    child: Center(
                      child: _Illustration(kind: cur.illust),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 140),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          cur.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            letterSpacing: -0.84,
                            color: BlowfitColors.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          cur.desc,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: BlowfitColors.ink2,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(last ? '프로필 설정하기' : '다음'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.title,
    required this.desc,
    required this.illust,
  });
  final String title;
  final String desc;
  final _IllustKind illust;
}

enum _IllustKind {
  welcome,
  mouthpiece,
  dial,
  breath,
  introGuide,
  introTarget,
  introGrow,
  introCompanion,
}

// ---------------------------------------------------------------------------
// Top bar — back · pip dots · skip
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.step,
    required this.total,
    required this.onBack,
    required this.onSkip,
  });

  final int step;
  final int total;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left,
                size: 26, color: BlowfitColors.ink,),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const Spacer(),
          // Pip dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(total, (i) {
              final active = i == step;
              final passed = i < step;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: (active || passed)
                        ? BlowfitColors.blue500
                        : BlowfitColors.gray200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            child: const Text(
              '건너뛰기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BlowfitColors.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Illustrations (Flutter-native simplifications)
// ---------------------------------------------------------------------------

class _Illustration extends StatelessWidget {
  const _Illustration({required this.kind});
  final _IllustKind kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _IllustKind.welcome:
        return const _WelcomeIllust();
      case _IllustKind.mouthpiece:
        return const _MouthpieceIllust();
      case _IllustKind.dial:
        return const _DialIllust();
      case _IllustKind.breath:
        return const _BreathIllust();
      case _IllustKind.introGuide:
        return const _MiniGaugeIllust(showPercent: false);
      case _IllustKind.introTarget:
        return const _MiniGaugeIllust(showPercent: true);
      case _IllustKind.introGrow:
        return const _GrowIllust();
      case _IllustKind.introCompanion:
        return const _CompanionIllust();
    }
  }
}

class _WelcomeIllust extends StatelessWidget {
  const _WelcomeIllust();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [BlowfitColors.blue50, Colors.white],
          stops: [0, 0.7],
        ),
      ),
      child: Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [BlowfitColors.blue400, BlowfitColors.blue500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 102, 255, 0.30),
                blurRadius: 40,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: const Icon(Icons.air, size: 64, color: Colors.white),
        ),
      ),
    );
  }
}

class _MouthpieceIllust extends StatelessWidget {
  const _MouthpieceIllust();

  @override
  Widget build(BuildContext context) {
    // 디자인 v2 — 4 step 모두 220×220 frame 안에 맞도록 220×183 으로 통일.
    return SizedBox(
      width: 220,
      height: 183,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // lip stand-in
          Positioned(
            left: 24,
            child: Container(
              width: 78,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFB7185),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          // mouthpiece tube
          Positioned(
            left: 96,
            child: Container(
              width: 34,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // device body
          Positioned(
            right: 14,
            child: Container(
              width: 88,
              height: 60,
              decoration: BoxDecoration(
                color: BlowfitColors.blue500,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 102, 255, 0.24),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.tune, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialIllust extends StatelessWidget {
  const _DialIllust();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var n = 1; n <= 3; n++) ...[
          if (n > 1) const SizedBox(width: 16),
          _DialPill(level: n, active: n == 1),
        ],
      ],
    );
  }
}

class _DialPill extends StatelessWidget {
  const _DialPill({required this.level, required this.active});
  final int level;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: active ? BlowfitColors.blue500 : BlowfitColors.gray100,
            shape: BoxShape.circle,
            border: active
                ? null
                : Border.all(color: BlowfitColors.gray200, width: 2),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 102, 255, 0.3),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '$level',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : BlowfitColors.gray400,
              ),
            ),
          ),
        ),
        if (active)
          Positioned(
            bottom: -16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: BlowfitColors.shadowLevel1,
              ),
              child: const Text(
                '여기서 시작',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: BlowfitColors.blue500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BreathIllust extends StatelessWidget {
  const _BreathIllust();

  @override
  Widget build(BuildContext context) {
    // 디자인 v2 — 220×183 으로 통일.
    return SizedBox(
      width: 220,
      height: 183,
      child: Stack(
        children: [
          // Face
          Positioned(
            left: 24,
            top: 42,
            child: Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE4D6),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.face, size: 52, color: Color(0xFF8A5A00)),
              ),
            ),
          ),
          // Inhale arrow (cyan, top)
          const Positioned(
            right: 14,
            top: 52,
            child: Row(
              children: [
                Icon(Icons.arrow_back, size: 20, color: Color(0xFF0099CC)),
                SizedBox(width: 4),
                Text(
                  '들숨',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0099CC),
                  ),
                ),
              ],
            ),
          ),
          // Exhale arrow (blue, bottom)
          const Positioned(
            right: 14,
            top: 108,
            child: Row(
              children: [
                Icon(Icons.arrow_forward,
                    size: 20, color: BlowfitColors.blue500,),
                SizedBox(width: 4),
                Text(
                  '날숨',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: BlowfitColors.blue500,
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
// App intro illustrations (앱 소개 — 실시간 가이드 / 맞춤 목표 / 성장 / 기록·동반자)
// ---------------------------------------------------------------------------

/// 미니 링 게이지 — 훈련 화면 원형 게이지의 축소판.
///  - showPercent=false : 목표 밴드(amber) + 진행 dot → "실시간 가이드"
///  - showPercent=true  : 55% 채움 + 중앙 "55%" → "맞춤 목표"
class _MiniGaugeIllust extends StatelessWidget {
  const _MiniGaugeIllust({required this.showPercent});
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final gauge = CustomPaint(
      size: const Size(200, 200),
      painter: _MiniGaugePainter(showPercent: showPercent),
    );
    if (!showPercent) {
      return SizedBox(width: 200, height: 200, child: gauge);
    }
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          gauge,
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '55%',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: BlowfitColors.blue500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '맞춤 강도',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BlowfitColors.ink3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniGaugePainter extends CustomPainter {
  _MiniGaugePainter({required this.showPercent});
  final bool showPercent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 34.0;
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 안쪽 배경 + 흰 도넛 트랙
    canvas.drawCircle(
      center,
      radius - stroke / 2,
      Paint()..color = const Color(0xFFEAF3FF),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    final fill = Paint()
      ..color = BlowfitColors.blue500
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    if (showPercent) {
      // 55% 채움 (12시부터 시계방향)
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * 0.55, false, fill);
      return;
    }

    // 실시간 가이드: 부분 채움(파랑) + 목표 밴드(amber, 6시 부근) + 진행 dot
    const sweep = math.pi * 0.78;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, fill);
    canvas.drawArc(
      rect,
      math.pi / 2 - 0.45,
      0.9,
      false,
      Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    const ang = -math.pi / 2 + sweep;
    canvas.drawCircle(
      Offset(
        center.dx + radius * math.cos(ang),
        center.dy + radius * math.sin(ang),
      ),
      stroke / 2,
      Paint()..color = BlowfitColors.blue500,
    );
  }

  @override
  bool shouldRepaint(_MiniGaugePainter old) => old.showPercent != showPercent;
}

/// 진화 3단계 — 알 → 아기 → 산소 (점점 커지는 원 + 라벨).
class _GrowIllust extends StatelessWidget {
  const _GrowIllust();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 220,
      height: 200,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StageDot(size: 52, color: Color(0xFFFFE4C4), label: '알'),
            _GrowArrow(),
            _StageDot(size: 66, color: BlowfitColors.blue50, label: '아기'),
            _GrowArrow(),
            _StageDot(
              size: 82,
              color: BlowfitColors.blue500,
              label: '산소',
              glow: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({
    required this.size,
    required this.color,
    required this.label,
    this.glow = false,
  });
  final double size;
  final Color color;
  final String label;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: glow
                ? const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 102, 255, 0.28),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: BlowfitColors.ink2,
          ),
        ),
      ],
    );
  }
}

class _GrowArrow extends StatelessWidget {
  const _GrowArrow();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 10, right: 10, bottom: 28),
      child: Icon(Icons.chevron_right, size: 26, color: BlowfitColors.gray400),
    );
  }
}

/// 기록 & 동반자 — 막대 차트(기록·추이) + 하트 배지(동반자 응원).
class _CompanionIllust extends StatelessWidget {
  const _CompanionIllust();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 172,
            height: 128,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: BlowfitColors.shadowLevel1,
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Bar(34),
                _Bar(52),
                _Bar(70),
                _Bar(88),
              ],
            ),
          ),
          Positioned(
            top: 26,
            right: 20,
            child: Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFFFB7185),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(251, 113, 133, 0.4),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.height);
  final double height;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [BlowfitColors.blue400, BlowfitColors.blue500],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    );
  }
}
