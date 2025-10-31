package com.example.push_app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions

class MyNotificationListener : NotificationListenerService() {

    companion object {
        // Flutter와 통신할 MethodChannel (MainActivity에서 설정됨)
        var channel: MethodChannel? = null
    }
    
    fun log(msg: String) {
        channel?.invokeMethod("TEST", mapOf("msg" to msg))
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        prepareModel()
    }

    private var lastTitle: String? = null
    private var lastText: String? = null
    private var isModelReady = false

    // 번역기 한 번만 생성
    private val translator by lazy {
        val options = TranslatorOptions.Builder()
            .setSourceLanguage(TranslateLanguage.ENGLISH)
            .setTargetLanguage(TranslateLanguage.KOREAN)
            .build()
        Translation.getClient(options)
    }

    // 앱 시작 시 한 번만 호출 (MainActivity에서)
    fun prepareModel() {
        if (isModelReady) return

        channel?.invokeMethod("modelStatus", mapOf("status" to "downloading"))

        translator.downloadModelIfNeeded()
            .addOnSuccessListener {
                isModelReady = true
                channel?.invokeMethod("modelStatus", mapOf("status" to "ready"))
            }
            .addOnFailureListener {
                channel?.invokeMethod("modelStatus", mapOf("status" to "failed"))
            }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return // null이면 그냥 종료

        // x 앱 알림만 처리
        if (sbn.packageName != "com.twitter.android") return

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

        // 모델 없으면 원문 바로 전송 + 상태 알림
        if (!isModelReady) {
            channel?.invokeMethod("modelStatus", mapOf("status" to "not_ready"))
            val data = mapOf("title" to title, "text" to text)
            channel?.invokeMethod("onNotificationReceived", data)
            return
        }

        // 모델 있으면 번역
        translateText(text) { result ->
            val translatedText = result.getOrDefault(text)
        val data = mapOf(
            "title" to title,
                "text" to translatedText
        )
        // MethodChannel을 통해 Flutter로 알림 데이터 전달
        channel?.invokeMethod("onNotificationReceived", data)
    }
}

    fun translateText(text: String, onComplete: (Result<String>) -> Unit) {
        if (text.trim().isEmpty()) {
            onComplete(Result.success(text))
            return
        }

        translator.translate(text)
            .addOnSuccessListener { translated ->
                onComplete(Result.success(translated))
            }
            .addOnFailureListener {
                onComplete(Result.success(text))
            }
    }
}