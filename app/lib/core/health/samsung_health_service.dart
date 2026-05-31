// Samsung Health Data SDK 연동 — Flutter 측 래퍼 (Android 전용).
//
// 네이티브 브리지(MainActivity + SamsungHealthBridge.kt)와 MethodChannel
// "blowfit/shealth" 로 통신. 읽기 전용(수면 / 혈중산소 SpO2).
//
// 권한은 삼성헬스 "개발자 모드(Data Read)" 로 동의됨 — 파트너 승인 불필요.

import 'package:flutter/services.dart';

/// 하룻밤 수면 레코드 (Samsung Health SLEEP).
class SleepReading {
  SleepReading({
    required this.start,
    required this.end,
    this.score,
    this.durationMin,
  });

  final DateTime start;
  final DateTime end;
  final int? score; // 수면 점수 (0~100)
  final int? durationMin; // 총 수면 시간(분)

  factory SleepReading.fromMap(Map<String, dynamic> m) => SleepReading(
        start: DateTime.parse(m['start'] as String),
        end: DateTime.parse(m['end'] as String),
        score: (m['score'] as num?)?.toInt(),
        durationMin: (m['durationMin'] as num?)?.toInt(),
      );
}

/// 혈중산소(SpO2) 레코드.
class Spo2Record {
  Spo2Record({
    required this.start,
    required this.end,
    this.avg,
    this.min,
    this.max,
  });

  final DateTime start;
  final DateTime end;
  final double? avg;
  final double? min;
  final double? max;

  factory Spo2Record.fromMap(Map<String, dynamic> m) => Spo2Record(
        start: DateTime.parse(m['start'] as String),
        end: DateTime.parse(m['end'] as String),
        avg: (m['avg'] as num?)?.toDouble(),
        min: (m['min'] as num?)?.toDouble(),
        max: (m['max'] as num?)?.toDouble(),
      );
}

/// 수면무호흡 징후 (DETECTED / NOT_DETECTED / UNDEFINED).
class ApneaReading {
  ApneaReading({required this.start, required this.end, this.sign});

  final DateTime start;
  final DateTime end;
  final String? sign;

  factory ApneaReading.fromMap(Map<String, dynamic> m) => ApneaReading(
        start: DateTime.parse(m['start'] as String),
        end: DateTime.parse(m['end'] as String),
        sign: m['sign'] as String?,
      );
}

class SamsungHealthService {
  static const MethodChannel _ch = MethodChannel('blowfit/shealth');

  /// 삼성헬스 앱 설치 여부.
  Future<bool> isAvailable() async =>
      (await _ch.invokeMethod<bool>('isAvailable')) ?? false;

  /// 필요한 읽기 권한이 모두 동의돼 있는지.
  Future<bool> hasPermissions() async =>
      (await _ch.invokeMethod<bool>('hasPermissions')) ?? false;

  /// 권한 동의 UI 표시 → 모두 동의되면 true.
  Future<bool> requestPermissions() async =>
      (await _ch.invokeMethod<bool>('requestPermissions')) ?? false;

  /// 기간 내 수면 레코드.
  Future<List<SleepReading>> readSleep(DateTime from, DateTime to) async {
    final raw = await _ch.invokeMethod<List<dynamic>>('readSleep', {
      'from': _date(from),
      'to': _date(to),
    });
    return (raw ?? [])
        .map((e) => SleepReading.fromMap(_asStringMap(e)))
        .toList();
  }

  /// 기간 내 SpO2 레코드.
  Future<List<Spo2Record>> readSpo2(DateTime from, DateTime to) async {
    final raw = await _ch.invokeMethod<List<dynamic>>('readSpo2', {
      'from': _date(from),
      'to': _date(to),
    });
    return (raw ?? [])
        .map((e) => Spo2Record.fromMap(_asStringMap(e)))
        .toList();
  }

  /// 기간 내 수면무호흡 징후. 미지원 기기는 빈 리스트.
  Future<List<ApneaReading>> readApneaSigns(DateTime from, DateTime to) async {
    final raw = await _ch.invokeMethod<List<dynamic>>('readApneaSigns', {
      'from': _date(from),
      'to': _date(to),
    });
    return (raw ?? [])
        .map((e) => ApneaReading.fromMap(_asStringMap(e)))
        .toList();
  }

  // MethodChannel 은 Map<Object?,Object?> 로 넘어옴 → String 키 맵으로 변환.
  static Map<String, dynamic> _asStringMap(dynamic e) =>
      (e as Map).map((k, v) => MapEntry(k.toString(), v));

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
