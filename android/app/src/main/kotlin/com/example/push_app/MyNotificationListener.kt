package com.example.push_app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateRemoteModel

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
        // 번역 모델 준비
        prepareModel()        
    }

    private fun shouldUpdateModel(): Boolean {
        val prefs = getSharedPreferences("MyNotificationListener", MODE_PRIVATE)
        val lastUpdate = prefs.getLong("lastModelUpdate", 0)
        val currentTime = System.currentTimeMillis()
        val updateInterval = 7 * 24 * 60 * 60 * 1000 // 7일 (밀리초 단위)

        return (currentTime - lastUpdate) > updateInterval
    }

    private fun saveModelUpdateTime() {
        val prefs = getSharedPreferences("MyNotificationListener", MODE_PRIVATE)
        prefs.edit().putLong("lastModelUpdate", System.currentTimeMillis()).apply()
    }

    private var lastTitle: String? = null
    private var lastText: String? = null

    // 번역기 한 번만 생성
    private val translator by lazy {
        val options = TranslatorOptions.Builder()
            .setSourceLanguage(TranslateLanguage.ENGLISH)
            .setTargetLanguage(TranslateLanguage.KOREAN)
            .build()
        Translation.getClient(options)
    }

    // 모델 준비
    fun prepareModel() {
        val modelManager = RemoteModelManager.getInstance()
        val targetModel = TranslateRemoteModel.Builder(TranslateLanguage.KOREAN).build()

        modelManager.getDownloadedModels(TranslateRemoteModel::class.java)
            .addOnSuccessListener { downloadedModels ->
                val isModelAlreadyDownloaded = downloadedModels.contains(targetModel)

                if (isModelAlreadyDownloaded) {
                    // log("한국어 모델이 이미 다운로드되어 있습니다.")
                } else {
                    log("한국어 모델이 아직 다운로드되지 않았습니다. 다운로드를 시도합니다.")
                    translator.downloadModelIfNeeded()
                        .addOnSuccessListener {
                            saveModelUpdateTime()
                            log("한국어 모델이 성공적으로 다운로드되었습니다.")
                        }
                        .addOnFailureListener { exception ->
                            log("한국어 모델 다운로드에 실패했습니다: ${exception.message}")
                        }
                }
            }
            .addOnFailureListener { exception ->
                log("다운로드된 번역 모델 목록을 가져오는 데 실패했습니다: ${exception.message}")
                translator.downloadModelIfNeeded()
                    .addOnSuccessListener {
                        saveModelUpdateTime()
                        log("한국어 모델이 성공적으로 다운로드되었거나 이미 존재했습니다.")
                    }
                    .addOnFailureListener { downloadException ->
                        log("한국어 모델 다운로드에 실패했습니다: ${downloadException.message}")
                    }
            }
        // 그리고 업데이트 주기마다 체크
        if (shouldUpdateModel()) {
            translator.downloadModelIfNeeded()
                .addOnSuccessListener {
                    saveModelUpdateTime()
                    log("한국어 모델이 최신 버전으로 준비되었습니다.")
                }
                .addOnFailureListener { exception ->
                    log("한국어 모델 업데이트에 실패했습니다: ${exception.message}")
                }
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

        // 번역
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