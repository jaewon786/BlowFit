package com.hannam.blowfit.blowfit

import android.app.Activity
import android.content.Context
import com.samsung.android.sdk.health.data.HealthDataService
import com.samsung.android.sdk.health.data.HealthDataStore
import com.samsung.android.sdk.health.data.permission.AccessType
import com.samsung.android.sdk.health.data.permission.Permission
import com.samsung.android.sdk.health.data.request.DataType
import com.samsung.android.sdk.health.data.request.DataTypes
import com.samsung.android.sdk.health.data.request.LocalTimeFilter
import java.time.LocalDate

/**
 * Samsung Health Data SDK 얇은 래퍼.
 * - 읽기 전용(수면 / 혈중산소). 권한은 개발자 모드(Read)로 동의.
 * - 모든 호출은 suspend (SDK 가 코루틴 기반). MainActivity 에서 코루틴으로 호출.
 */
class SamsungHealthBridge(private val context: Context) {

  private val store: HealthDataStore by lazy { HealthDataService.getStore(context) }

  /** 핵심 권한 — 이게 있어야 "권한 OK" 로 본다 (수면 + SpO2). */
  private fun corePermissions(): Set<Permission> = setOf(
    Permission.of(DataTypes.SLEEP, AccessType.READ),
    Permission.of(DataTypes.BLOOD_OXYGEN, AccessType.READ),
  )

  /** 요청할 전체 권한 — 무호흡(SLEEP_APNEA)은 선택(워치 모델 따라 미지원 가능). */
  private fun allPermissions(): Set<Permission> =
    corePermissions() + Permission.of(DataTypes.SLEEP_APNEA, AccessType.READ)

  /** 삼성헬스 앱 설치 여부 (간이 가용성 체크). */
  fun isSamsungHealthInstalled(): Boolean = try {
    context.packageManager.getPackageInfo("com.sec.android.app.shealth", 0)
    true
  } catch (e: Exception) {
    false
  }

  /** 핵심 권한(수면+SpO2)이 모두 동의돼 있는지. (무호흡은 선택이라 제외) */
  suspend fun hasAllPermissions(): Boolean {
    val core = corePermissions()
    val granted = store.getGrantedPermissions(core)
    return granted.containsAll(core)
  }

  /** 권한 동의 UI 표시(무호흡 포함 요청) → 핵심 권한이 모두 동의되면 true. */
  suspend fun requestPermissions(activity: Activity): Boolean {
    val granted = store.requestPermissions(allPermissions(), activity)
    return granted.containsAll(corePermissions())
  }

  // [from 00:00, to+1일 00:00) — 종료일(오늘/어젯밤)까지 포함하도록 다음날 0시까지.
  private fun timeFilter(from: LocalDate, to: LocalDate): LocalTimeFilter =
    LocalTimeFilter.of(from.atStartOfDay(), to.plusDays(1).atStartOfDay())

  /** 기간 내 수면 데이터(점수/지속/세션·단계). */
  suspend fun readSleep(from: LocalDate, to: LocalDate): List<Map<String, Any?>> {
    val req = DataTypes.SLEEP.readDataRequestBuilder
      .setLocalTimeFilter(timeFilter(from, to))
      .build()
    val resp = store.readData(req)
    return resp.dataList.map { dp ->
      val sessions = dp.getValue(DataType.SleepType.SESSIONS) ?: emptyList()
      mapOf(
        "uid" to dp.uid,
        "start" to dp.startTime.toString(),
        "end" to dp.endTime.toString(),
        "score" to dp.getValue(DataType.SleepType.SLEEP_SCORE),
        "durationMin" to dp.getValue(DataType.SleepType.DURATION)?.toMinutes(),
        "sessions" to sessions.map { s ->
          mapOf(
            "start" to s.startTime.toString(),
            "end" to s.endTime.toString(),
            "durationMin" to s.duration.toMinutes(),
            "stages" to (s.stages ?: emptyList()).map { st ->
              mapOf(
                "stage" to st.stage.toString(),
                "start" to st.startTime.toString(),
                "end" to st.endTime.toString(),
              )
            },
          )
        },
      )
    }
  }

  /** 기간 내 혈중산소(SpO2) 데이터(평균/최저/최고). */
  suspend fun readSpo2(from: LocalDate, to: LocalDate): List<Map<String, Any?>> {
    val req = DataTypes.BLOOD_OXYGEN.readDataRequestBuilder
      .setLocalTimeFilter(timeFilter(from, to))
      .build()
    val resp = store.readData(req)
    return resp.dataList.map { dp ->
      mapOf(
        "start" to dp.startTime.toString(),
        "end" to dp.endTime.toString(),
        "avg" to dp.getValue(DataType.BloodOxygenType.OXYGEN_SATURATION),
        "min" to dp.getValue(DataType.BloodOxygenType.MIN_OXYGEN_SATURATION),
        "max" to dp.getValue(DataType.BloodOxygenType.MAX_OXYGEN_SATURATION),
      )
    }
  }

  /** 기간 내 수면무호흡 징후 (DETECTED / NOT_DETECTED / UNDEFINED).
   *  미지원 워치/권한이면 호출부에서 빈 리스트로 처리. */
  suspend fun readApneaSigns(from: LocalDate, to: LocalDate): List<Map<String, Any?>> {
    val req = DataTypes.SLEEP_APNEA.readDataRequestBuilder
      .setLocalTimeFilter(timeFilter(from, to))
      .build()
    val resp = store.readData(req)
    return resp.dataList.map { dp ->
      mapOf(
        "start" to dp.startTime.toString(),
        "end" to dp.endTime.toString(),
        "sign" to dp.getValue(DataType.SleepApneaType.DETECTED_SIGN)?.name,
      )
    }
  }
}
