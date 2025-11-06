# app_push_translator

> **Flutter 기반 안드로이드 전용 앱**  
> **Galaxy S23 (Android 16)에서 개발 및 테스트**

---

## 📌 만든 이유
국제 뉴스를 구독하다 보니 너무 많은 푸시 알림을 받게 되어, 번역 과정을 간단히 하기 위해 제작

---

## ✨ 주요 기능
1. **X (구 트위터) 푸시 알림 번역**  
   - X 앱에서 수신한 푸시 알림 내용을 **Google 번역**을 통해 EN → KR로 번역.  
   - 최초 실행 시 번역 모델 다운로드 후 번역 진행.

2. **언어 필터링**  
   - 한국어나 다른 언어로 된 알림은 번역하지 않고 그대로 유지.

3. **리스트 관리**  
   - 최대 **500개**의 알림을 리스트로 유지.  
   - **삭제 버튼**.

4. **스크롤 위치 유지**  
   - 확인한 위치까지 스크롤 상태를 유지.

---

## 🛠️ 구현 세부 사항
- **푸시 알림 필터링**  
  X 앱(구 트위터)에서 수신한 알림만 처리하도록 필터링. 
  아래 코드:

  ```kotlin
  // filepath: android\app\src\main\kotlin\com\example\push_app\MyNotificationListener.kt

  // X 앱 알림만 처리
  if (sbn.packageName != "com.twitter.android") return
  ```