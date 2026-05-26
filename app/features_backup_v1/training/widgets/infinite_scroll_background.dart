// 무한 스크롤 배경 — 두 이미지 stitch 패턴.
//
// `walking == true` 일 때 [speedMps] 만큼 좌측으로 스크롤. offset 이 한 이미지
// 너비에 도달하면 imgWidth 만큼 빼서 seamless loop.
//
// 사용자 픽셀 아트 배경 이미지가 `assets/backgrounds/pixel_field.png` 에 추가되면
// 자동으로 사용. 없으면 placeholder (그라데이션 하늘 + 픽셀 풍 풀밭) 으로 폴백.

import 'dart:async' show Completer;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show rootBundle;

class InfiniteScrollBackground extends StatefulWidget {
  const InfiniteScrollBackground({
    super.key,
    required this.walking,
    required this.speedMps,
    this.imageAssetPath = 'assets/backgrounds/pixel_field.png',
    this.pxPerMeter = 4.0,
    this.bottomBandRatio = 1.0,
    this.skyColor = const Color(0xFF5FB7E8),
    this.mirrorTile = true,
  });

  /// true 면 매 프레임 offset 증가, false 면 정지.
  final bool walking;

  /// 진행 속도 (m/s). 1500m 기준 50 m/s 시 약 30s 에 완주.
  final double speedMps;

  /// 배경 이미지 path. 없으면 placeholder 사용.
  final String imageAssetPath;

  /// 시각 속도 환산 — meter 당 px. pxPerMeter * speedMps = px/s.
  /// 50 m/s × 4 = 200 px/s — 적당한 횡스크롤 게임 속도.
  final double pxPerMeter;

  /// 배경 이미지가 화면에서 차지할 높이 비율. 0.55 = 화면 하단 55% 영역만 이미지,
  /// 나머지 위쪽은 [skyColor] 로 채움. 픽셀 아트 가로형 배경 (sky+ground 가 한
  /// 이미지에 들어있는) 을 자연스러운 비율로 보여주기 위한 옵션.
  final double bottomBandRatio;

  /// 이미지 위쪽 sky 영역에 깔리는 단색.
  final Color skyColor;

  /// true 면 짝수번째 tile 은 정상, 홀수번째 tile 은 좌우 반전해서 stitch.
  /// 좌우 seamless 가 아닌 이미지도 양 끝 픽셀이 자동으로 매칭되어 끊김이
  /// 사라짐. (대신 패턴이 좌우 대칭으로 반복.)
  final bool mirrorTile;

  @override
  State<InfiniteScrollBackground> createState() =>
      _InfiniteScrollBackgroundState();
}

class _InfiniteScrollBackgroundState extends State<InfiniteScrollBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _offset = 0;

  ImageProvider? _bgImage;
  double? _bgImageWidth;
  double? _bgImageHeight;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
    _tryLoadBackground();
  }

  Future<void> _tryLoadBackground() async {
    try {
      // assets 매니페스트에 존재하는지 확인 — 없으면 ImageProvider 만들지 않음.
      await rootBundle.load(widget.imageAssetPath);
      final provider = AssetImage(widget.imageAssetPath);
      final stream = provider.resolve(ImageConfiguration.empty);
      final completer = Completer<void>();
      late final ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        if (!mounted) {
          stream.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
          return;
        }
        setState(() {
          _bgImage = provider;
          _bgImageWidth = info.image.width.toDouble();
          _bgImageHeight = info.image.height.toDouble();
        });
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      }, onError: (_, __) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },);
      stream.addListener(listener);
      await completer.future;
    } catch (_) {
      // asset 없음 — placeholder 그대로.
    }
  }

  Widget _buildTile({required bool mirror}) {
    final image = Image(
      image: _bgImage!,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium, // 부드러운 보간 (3D 그래픽)
    );
    if (!mirror) return image;
    return Transform(
      transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
      alignment: Alignment.center,
      child: image,
    );
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (!widget.walking) return;
    if (dt <= 0) return;
    final pxStep = widget.pxPerMeter * widget.speedMps * dt;
    setState(() {
      _offset += pxStep;
      // 부동소수점 정밀도 보호용 wrap. tile width 와 무관한 큰 값 — build 에서
      // firstTileIndex 로 mirror cycle 을 정확히 계산하므로 그 단위로 wrap 할
      // 필요 없음.
      const safeWrap = 1e7;
      if (_offset > safeWrap) _offset -= safeWrap;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        // 이미지가 있으면 비율 유지하며 화면 하단 [bottomBandRatio] 영역에 stitch.
        if (_bgImage != null &&
            _bgImageWidth != null &&
            _bgImageHeight != null) {
          final tileH = h * widget.bottomBandRatio;
          final scale = tileH / _bgImageHeight!;
          final tileW = _bgImageWidth! * scale;

          // mirror tiling — 짝수 tileIndex 정상, 홀수 좌우 반전. 양 끝 픽셀이
          // 자동 매칭되어 seamless 하지 않은 이미지도 끊김 없이 이어짐.
          final continuousOffset = _offset / tileW;
          final firstTileIndex = continuousOffset.floor();
          final fractional = continuousOffset - firstTileIndex;
          final firstTileLeft = -fractional * tileW;
          final tileCount = (w / tileW).ceil() + 2;

          return ClipRect(
            child: Stack(
              children: [
                // 위쪽 sky 영역 — 단색 fill.
                Positioned.fill(
                  child: Container(color: widget.skyColor),
                ),
                // 하단 픽셀아트 띠.
                for (int i = 0; i < tileCount; i++)
                  Positioned(
                    left: firstTileLeft + i * tileW,
                    bottom: 0,
                    width: tileW,
                    height: tileH,
                    child: _buildTile(
                      mirror: widget.mirrorTile &&
                          (firstTileIndex + i).abs() % 2 == 1,
                    ),
                  ),
              ],
            ),
          );
        }

        // Placeholder — 그라데이션 + 픽셀 풍 풀밭.
        return ClipRect(
          child: CustomPaint(
            size: Size(w, h),
            painter: _PixelFieldPainter(scrollOffset: _offset),
          ),
        );
      },
    );
  }
}

/// 픽셀 풍 풍경 placeholder.
class _PixelFieldPainter extends CustomPainter {
  _PixelFieldPainter({required this.scrollOffset});
  final double scrollOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final skyHeight = h * 0.62;
    final groundHeight = h - skyHeight;

    // 하늘 그라데이션
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB7E3FF), Color(0xFFEAF6FF)],
      ).createShader(Rect.fromLTWH(0, 0, w, skyHeight));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, skyHeight), skyPaint);

    // 풀밭 base
    final groundPaint = Paint()..color = const Color(0xFF87C969);
    canvas.drawRect(Rect.fromLTWH(0, skyHeight, w, groundHeight), groundPaint);

    // 풀밭 어두운 stripe
    const stripeRows = 6;
    final stripeH = groundHeight / stripeRows;
    for (int i = 0; i < stripeRows; i++) {
      final shade = 0.05 + 0.06 * i;
      canvas.drawRect(
        Rect.fromLTWH(0, skyHeight + i * stripeH, w, stripeH * 0.5),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF87C969),
            const Color(0xFF3F8B3A),
            shade,
          )!,
      );
    }

    // 풀잎 픽셀 (scroll 됨)
    final tuftPaint = Paint()..color = const Color(0xFF5DAA52);
    const tuftSpacing = 28.0;
    final wrap = (scrollOffset % tuftSpacing);
    for (double x = -wrap; x < w + tuftSpacing; x += tuftSpacing) {
      final baseY = skyHeight + 6;
      canvas.drawRect(Rect.fromLTWH(x + 4, baseY, 4, 4), tuftPaint);
      canvas.drawRect(Rect.fromLTWH(x + 8, baseY - 4, 4, 4), tuftPaint);
      canvas.drawRect(Rect.fromLTWH(x + 12, baseY, 4, 4), tuftPaint);
    }

    // 멀리 있는 구름 (parallax — 30% 속도)
    final cloudPaint =
        Paint()..color = const Color.fromRGBO(255, 255, 255, 0.85);
    final cloudWrap = (scrollOffset * 0.3) % 220;
    for (double x = -cloudWrap; x < w + 220; x += 220) {
      _drawPixelCloud(canvas, cloudPaint, x + 20, skyHeight * 0.25);
      _drawPixelCloud(canvas, cloudPaint, x + 130, skyHeight * 0.42);
    }
  }

  void _drawPixelCloud(Canvas c, Paint p, double cx, double cy) {
    c.drawRect(Rect.fromLTWH(cx, cy, 36, 10), p);
    c.drawRect(Rect.fromLTWH(cx + 8, cy - 6, 24, 10), p);
    c.drawRect(Rect.fromLTWH(cx + 4, cy + 4, 32, 6), p);
  }

  @override
  bool shouldRepaint(covariant _PixelFieldPainter old) =>
      old.scrollOffset != scrollOffset;
}
