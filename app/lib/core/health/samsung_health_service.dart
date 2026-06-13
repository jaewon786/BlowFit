// Samsung Health Data SDK 연동 — Flutter 측 래퍼 (Android 전용).
//
// 네이티브 브리지(MainActivity + SamsungHealthBridge.kt)와 MethodChannel
// "blowfit/shealth" 로 통신. 읽기 전용(수면 / 혈중산소 SpO2).
//
// 권한은 삼성헬스 "개발자 모드(Data Read)" 로 동의됨 — 파트너 승인 불필요.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Samsung Health SDK 가 보내는 날짜 문자열을 견고하게 DateTime 으로 파싱.
///
/// - `Instant.toString()`("...Z") / `LocalDateTime` / `ZonedDateTime.toString()`
///   ("2026-06-12T22:30+09:00[Asia/Seoul]" — Dart 가 못 읽는 `[지역]` 접미사)
///   모두 처리. 오프셋/`Z` 로 UTC 정규화되면 수면 "밤" 계산이 로컬 캘린더
///   기준이 되도록 `toLocal()` 로 되돌린다.
/// - null / "null" / 빈 문자열 / 파싱불가 → null 반환(해당 레코드는 호출부에서
///   skip). 잘못된 한 건이 전체 sync 를 중단시키지 않도록 절대 throw 하지 않는다.
DateTime? tryParseHealthDateTime(Object? raw) {
  if (raw == null) return null;
  var s = raw.toString().trim();
  if (s.isEmpty || s == 'null') return null;

  // ZonedDateTime 지역 접미사 "[Asia/Seoul]" 제거.
  final bracket = s.indexOf('[');
  if (bracket != -1) s = s.substring(0, bracket);

  var dt = DateTime.tryParse(s);
  if (dt == null) {
    // 폴백: 오프셋/Z 떼고 벽시계만.
    final core = RegExp(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?')
        .stringMatch(s);
    if (core != null) dt = DateTime.tryParse(core.replaceFirst(' ', 'T'));
  }
  if (dt == null) {
    if (kDebugMode) debugPrint('[SHealthDate] PARSE FAIL raw="$raw"');
    return null;
  }
  // 오프셋/Z 로 UTC 정규화됐으면 수면 "밤" 계산이 로컬 캘린더 기준이 되도록 로컬로.
  return dt.isUtc ? dt.toLocal() : dt;
}

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

  /// start/end 가 없거나 파싱 불가면 null → 호출부에서 skip.
  static SleepReading? tryFromMap(Map<String, dynamic> m) {
    final start = tryParseHealthDateTime(m['start']);
    final end = tryParseHealthDateTime(m['end']);
    if (start == null || end == null) return null;
    return SleepReading(
      start: start,
      end: end,
      score: (m['score'] as num?)?.toInt(),
      durationMin: (m['durationMin'] as num?)?.toInt(),
    );
  }
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

  /// start 가 없거나 파싱 불가면 null → 호출부에서 skip.
  static Spo2Record? tryFromMap(Map<String, dynamic> m) {
    final start = tryParseHealthDateTime(m['start']);
    if (start == null) return null;
    return Spo2Record(
      start: start,
      end: tryParseHealthDateTime(m['end']) ?? start,
      avg: (m['avg'] as num?)?.toDouble(),
      min: (m['min'] as num?)?.toDouble(),
      max: (m['max'] as num?)?.toDouble(),
    );
  }
}

/// 수면무호흡 징후 (DETECTED / NOT_DETECTED / UNDEFINED).
class ApneaReading {
  ApneaReading({required this.start, required this.end, this.sign});

  final DateTime start;
  final DateTime end;
  final String? sign;

  /// start 가 없거나 파싱 불가면 null → 호출부에서 skip.
  static ApneaReading? tryFromMap(Map<String, dynamic> m) {
    final start = tryParseHealthDateTime(m['start']);
    if (start == null) return null;
    return ApneaReading(
      start: start,
      end: tryParseHealthDateTime(m['end']) ?? start,
      sign: m['sign'] as String?,
    );
  }
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
    return [
      for (final e in raw ?? const [])
        if (SleepReading.tryFromMap(_asStringMap(e)) case final r?) r,
    ];
  }

  /// 기간 내 SpO2 레코드.
  Future<List<Spo2Record>> readSpo2(DateTime from, DateTime to) async {
    final raw = await _ch.invokeMethod<List<dynamic>>('readSpo2', {
      'from': _date(from),
      'to': _date(to),
    });
    return [
      for (final e in raw ?? const [])
        if (Spo2Record.tryFromMap(_asStringMap(e)) case final r?) r,
    ];
  }

  /// 기간 내 수면무호흡 징후. 미지원 기기는 빈 리스트.
  Future<List<ApneaReading>> readApneaSigns(DateTime from, DateTime to) async {
    final raw = await _ch.invokeMethod<List<dynamic>>('readApneaSigns', {
      'from': _date(from),
      'to': _date(to),
    });
    return [
      for (final e in raw ?? const [])
        if (ApneaReading.tryFromMap(_asStringMap(e)) case final r?) r,
    ];
  }

  // MethodChannel 은 Map<Object?,Object?> 로 넘어옴 → String 키 맵으로 변환.
  static Map<String, dynamic> _asStringMap(dynamic e) =>
      (e as Map).map((k, v) => MapEntry(k.toString(), v));

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
