# app_push_translator

A new Flutter project.

안드로이드 전용 (S23 안드로이드16 버전에서 개발함)

만든 이유
- 국제 뉴스 등을 구독하다보니.. 너무 많은 PUSH를 받아서 번역과정을 간단히 하기 위해

기능
1. X(구 트위터)에서 PUSH를 수신하면 PUSH 내용을 구글번역으로 
   (최초 번역 모델 다운로드 후 번역 진행) EN -> KR 번역해서 리스트로 보여줌
2. 한국어나 다른 언어는 그대로 유지
3. 500개 까지 리스트를 유지하고, 삭제 기능
4. 확인한 곳 까지 스크롤 유지

* X PUSH 에 대해서만 필터링을 걸어놓음 (아래 코드)
android\app\src\main\kotlin\com\example\push_app\MyNotificationListener.kt
// x 앱 알림만 처리
if (sbn.packageName != "com.twitter.android") return