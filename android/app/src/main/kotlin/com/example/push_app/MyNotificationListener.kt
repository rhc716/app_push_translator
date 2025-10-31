package com.example.push_app

// NotificationListenerService를 상속받아 안드로이드 알림(Notification)을 감지하는 서비스
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.MethodChannel

class MyNotificationListener : NotificationListenerService() {

    companion object {
        // Flutter와 통신할 MethodChannel (MainActivity에서 설정됨)
        var channel: MethodChannel? = null
    }

    private var lastTitle: String? = null
    private var lastText: String? = null

    // 새로운 알림이 게시될 때 호출되는 콜백
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return // null이면 그냥 종료

        // x 앱 알림만 처리
        // if (sbn.packageName != "com.twitter.android") return

        // 알림 정보를 가져오기
        val extras = sbn.notification.extras                // 알림 세부 정보
        val title = extras.getString("android.title") ?: "" // 알림 제목
        val text = extras.getString("android.text") ?: ""   // 알림 내용

        // 제목과 내용이 둘 다 없으면 무시
        if (title.trim().isEmpty() && text.trim().isEmpty()) return
        
        // 마지막 보낸 알림과 같으면 무시
        if (title == lastTitle && text == lastText) return
        lastTitle = title
        lastText = text

        // Flutter로 전달할 데이터 준비
        val data = mapOf(
            "title" to title,
            "text" to text
        )
        // MethodChannel을 통해 Flutter로 알림 데이터 전달
        channel?.invokeMethod("onNotificationReceived", data)
    }
}
