package com.hannam.blowfit.blowfit

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.time.LocalDate

class MainActivity : FlutterActivity() {

  private val channelName = "blowfit/shealth"
  private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
  private lateinit var bridge: SamsungHealthBridge

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    bridge = SamsungHealthBridge(applicationContext)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result -> onCall(call, result) }
  }

  private fun onCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "isAvailable" -> result.success(bridge.isSamsungHealthInstalled())

      "hasPermissions" -> scope.launch {
        runCatching { bridge.hasAllPermissions() }
          .onSuccess { result.success(it) }
          .onFailure { result.error("SHEALTH", it.message, null) }
      }

      "requestPermissions" -> scope.launch {
        runCatching { bridge.requestPermissions(this@MainActivity) }
          .onSuccess { result.success(it) }
          .onFailure { result.error("SHEALTH", it.message, null) }
      }

      "readSleep" -> scope.launch {
        runCatching {
          bridge.readSleep(localDate(call, "from"), localDate(call, "to"))
        }.onSuccess { result.success(it) }
          .onFailure { result.error("SHEALTH", it.message, null) }
      }

      "readSpo2" -> scope.launch {
        runCatching {
          bridge.readSpo2(localDate(call, "from"), localDate(call, "to"))
        }.onSuccess { result.success(it) }
          .onFailure { result.error("SHEALTH", it.message, null) }
      }

      "readApneaSigns" -> scope.launch {
        runCatching {
          bridge.readApneaSigns(localDate(call, "from"), localDate(call, "to"))
        }.onSuccess { result.success(it) }
          // 무호흡 미지원/미동의 기기는 에러 대신 빈 리스트.
          .onFailure { result.success(emptyList<Map<String, Any?>>()) }
      }

      else -> result.notImplemented()
    }
  }

  private fun localDate(call: MethodCall, key: String): LocalDate =
    LocalDate.parse(call.argument<String>(key))

  override fun onDestroy() {
    scope.cancel()
    super.onDestroy()
  }
}
