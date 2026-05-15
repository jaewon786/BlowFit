// 별 먹기 오버레이 — 흡기 phase 의 zone 안에서 활성화.
//
// 화면 우측에서 노란 별들이 생성되어 화면 중앙 (Kirby 입 위치) 으로 빨려들어감.
// CustomPaint + Ticker + Particle list.
//
// `active == true` 면 0.18s 마다 새 별 spawn, 각 별은 ~1.0s 동안 캐릭터 입 쪽으로
// 이동 후 소멸 (입에 도달).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

class StarEatingOverlay extends StatefulWidget {
  const StarEatingOverlay({
    super.key,
    required this.active,
    this.mouthAlignment = const Alignment(0.0, -0.05),
  });

  /// true 면 별 spawn, false 면 spawn 정지 (기존 별은 화면 밖으로 빠질 때까지 유지).
  final bool active;

  /// Kirby 입 위치 (Alignment 기반 — 화면 비례).
  final Alignment mouthAlignment;

  @override
  State<StarEatingOverlay> createState() => _StarEatingOverlayState();
}

class _StarEatingOverlayState extends State<StarEatingOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final List<_Star> _stars = [];
  final _rng = math.Random();
  double _spawnAccumulator = 0;
  static const _spawnInterval = 0.18; // 초당 ~5.5 개

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;

    // spawn
    if (widget.active) {
      _spawnAccumulator += dt;
      while (_spawnAccumulator >= _spawnInterval) {
        _spawnAccumulator -= _spawnInterval;
        _spawnStar();
      }
    } else {
      _spawnAccumulator = 0;
    }

    // advance
    final toRemove = <int>[];
    for (var i = 0; i < _stars.length; i++) {
      _stars[i].progress += dt / _stars[i].duration;
      if (_stars[i].progress >= 1.0) toRemove.add(i);
    }
    for (var i = toRemove.length - 1; i >= 0; i--) {
      _stars.removeAt(toRemove[i]);
    }

    if (mounted) setState(() {});
  }

  void _spawnStar() {
    // 우측에서 시작 (화면 비례 좌표 — LayoutBuilder 에서 변환)
    final yJitter = (_rng.nextDouble() - 0.5) * 0.6;
    _stars.add(
      _Star(
        startNorm: Offset(1.1, yJitter),
        duration: 0.8 + _rng.nextDouble() * 0.4,
        size: 22 + _rng.nextDouble() * 14,
        hueShift: _rng.nextDouble(),
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _StarsPainter(
              stars: List.unmodifiable(_stars),
              mouth: widget.mouthAlignment,
            ),
          );
        },
      ),
    );
  }
}

class _Star {
  _Star({
    required this.startNorm,
    required this.duration,
    required this.size,
    required this.hueShift,
  });
  final Offset startNorm; // x ∈ [-? , 1.1+?], y ∈ [-1, 1] (Alignment 좌표)
  final double duration;
  final double size;
  final double hueShift;
  double progress = 0.0;
}

class _StarsPainter extends CustomPainter {
  _StarsPainter({required this.stars, required this.mouth});
  final List<_Star> stars;
  final Alignment mouth;

  Offset _alignmentToOffset(Alignment a, Size size) {
    return Offset(
      (a.x + 1) / 2 * size.width,
      (a.y + 1) / 2 * size.height,
    );
  }

  Color _starColor(double hueShift) {
    // 노랑 ~ 주황 사이.
    return Color.lerp(
      const Color(0xFFFFE066),
      const Color(0xFFFFA800),
      hueShift,
    )!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final mouthOff = _alignmentToOffset(mouth, size);
    for (final s in stars) {
      final startOff = _alignmentToOffset(
        Alignment(s.startNorm.dx, s.startNorm.dy),
        size,
      );
      // ease-in 가속 — 입 가까이서 빨라짐.
      final t = Curves.easeInQuad.transform(s.progress.clamp(0.0, 1.0));
      final pos = Offset.lerp(startOff, mouthOff, t)!;
      final radius = s.size * (1.0 - t * 0.3);
      // 입 가까이 (t >= 0.7) 부터만 fade out — 그 전까지는 완전히 불투명.
      const fadeStart = 0.7;
      final alpha = t < fadeStart
          ? 1.0
          : (1.0 - (t - fadeStart) / (1.0 - fadeStart)).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = _starColor(s.hueShift).withValues(alpha: alpha);
      _drawStar(canvas, pos, radius, paint);
    }
  }

  /// 5각 별 path.
  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    const points = 5;
    final inner = r * 0.45;
    for (var i = 0; i < points * 2; i++) {
      final angle = -math.pi / 2 + i * math.pi / points;
      final radius = i.isEven ? r : inner;
      final x = c.dx + radius * math.cos(angle);
      final y = c.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) =>
      old.stars != stars || old.mouth != mouth;
}
