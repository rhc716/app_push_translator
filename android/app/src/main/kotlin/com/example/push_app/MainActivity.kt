package com.example.push_app

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.service.notification.NotificationListenerService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.text.TextUtils
import android.util.Log

class MainActivity : FlutterActivity() {
    // Flutter와 통신할 MethodChannel 이름
    private val CHANNEL = "notification_channel"

    // FlutterEngine가 준비되었을 때 호출되는 콜백
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Flutter와 통신할 MethodChannel 생성
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // NotificationListenerService에서 Flutter로 메시지를 보내도록 채널 연결
        MyNotificationListener.channel = methodChannel

        // Flutter에서 호출하는 메서드 처리
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Flutter가 권한 체크를 요청할 때
                "checkPermission" -> {
                    val granted = isNotificationServiceEnabled(this) // 권한 여부 확인
                    result.success(granted) // Flutter에 true/false 반환
                }
                // Flutter가 설정 화면 열기를 요청할 때
                "openPermissionSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)) 
                    // 알림 접근 권한 설정 화면 열기
                    result.success(null) // Flutter에 성공 여부 반환
                }
                else -> result.notImplemented() // 정의되지 않은 메서드 호출 시
            }
        }
    }

    // NotificationListener 권한이 앱에 허용되었는지 확인하는 함수
    private fun isNotificationServiceEnabled(context: Context): Boolean {
        val pkgName = context.packageName
        // 시스템에 등록된 알림 리스너 문자열 가져오기
        val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
        if (!TextUtils.isEmpty(flat)) {
            // 여러 개의 알림 리스너가 ":"로 구분되어 있음
            val names = flat.split(":")
            for (name in names) {
                // 현재 앱 패키지가 포함되어 있으면 권한 허용됨
                if (name.contains(pkgName)) {
                    return true
                }
            }
        }
        // 없으면 권한 없음
        return false
    }
}
