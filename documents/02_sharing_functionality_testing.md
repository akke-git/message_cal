# 공유 기능 테스트 가이드

## 개요
MessageCal 앱의 Android 공유 기능(Share Intent)을 실제 기기에서 체계적으로 테스트하고 문제를 진단하는 단계별 가이드입니다.

## 테스트 환경 준비

### 1. 개발 환경 설정
```bash
# Flutter 버전 확인
flutter --version

# 의존성 설치
flutter pub get

# 프로젝트 클린 빌드
flutter clean
flutter pub get
```

### 2. Android 디버그 환경 설정
```bash
# ADB 연결 확인
adb devices

# 로그캣 실시간 모니터링 설정
adb logcat | grep -E "(MessageCal|ShareIntent|Intent)"

# 또는 특정 패키지만 필터링
adb logcat --pid=$(adb shell pidof -s com.example.message_cal)
```

### 3. 테스트 기기 요구사항
- **실제 Android 기기 권장** (에뮬레이터보다 정확한 테스트)
- Android 7.0 (API 24) 이상
- 다양한 메신저 앱 설치 (카카오톡, 문자메시지, 텔레그램 등)
- 개발자 옵션 활성화

## 단계별 테스트 프로세스

### Step 1: 앱 설치 및 기본 동작 확인

#### 1.1 앱 빌드 및 설치
```bash
# Debug APK 빌드
flutter build apk --debug

# 기기에 설치
flutter install

# 또는 직접 실행
flutter run
```

#### 1.2 기본 기능 테스트
1. **앱 실행 확인**
   - 스플래시 화면 정상 표시
   - 메인 화면 로드 확인
   - 하단 네비게이션 동작 확인

2. **권한 확인**
   ```bash
   # 앱 권한 상태 확인
   adb shell dumpsys package com.example.message_cal | grep permission
   ```

### Step 2: AndroidManifest.xml 설정 검증

#### 2.1 Intent Filter 설정 확인
현재 설정된 Intent Filter를 점검합니다:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <action android:name="android.intent.action.SEND_MULTIPLE" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/*" />
</intent-filter>
```

#### 2.2 Activity 설정 확인
```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTask"
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
```

#### 2.3 설정 검증 명령어
```bash
# 설치된 앱의 Manifest 정보 확인
adb shell dumpsys package com.example.message_cal | grep -A 20 "Activity"

# Intent Filter 정보 확인
adb shell dumpsys package com.example.message_cal | grep -A 10 "intent-filter"
```

### Step 3: 공유 기능 단계별 테스트

#### 3.1 시스템 레벨 테스트

**방법 1: ADB를 통한 직접 Intent 전송**
```bash
# 텍스트 공유 Intent 직접 전송
adb shell am start \
  -a android.intent.action.SEND \
  -t "text/plain" \
  -e android.intent.extra.TEXT "테스트 메시지: 내일 오후 2시 강남역에서 만나요" \
  --activity-brought-to-front \
  com.example.message_cal/.MainActivity

# 결과 확인 (앱이 실행되고 텍스트가 수신되는지 확인)
```

**방법 2: 시스템 공유 시뮬레이션**
```bash
# 시스템 공유 다이얼로그 테스트
adb shell am start \
  -a android.intent.action.SEND \
  -t "text/plain" \
  -e android.intent.extra.TEXT "회의 일정: 12월 25일 오전 10시 회의실 A" \
  --activity-brought-to-front
```

#### 3.2 실제 앱에서 공유 테스트

**카카오톡 테스트**
1. 카카오톡 실행
2. 임의의 대화방에서 텍스트 메시지 선택
3. "공유" 또는 "전달" 버튼 클릭
4. 공유 대상 목록에서 "MessageCal" 앱 확인
5. MessageCal 선택 시 앱 실행 및 텍스트 수신 확인

**문자메시지 테스트**
1. 기본 문자메시지 앱 실행
2. 메시지 선택 → 공유
3. MessageCal 표시 및 동작 확인

**브라우저 테스트**
1. Chrome 브라우저 실행
2. 텍스트 선택 → 공유
3. MessageCal 표시 확인

#### 3.3 로그 분석

실시간 로그 모니터링:
```bash
# 전체 로그 모니터링
adb logcat | grep -E "(MessageCal|Intent|Share)"

# Flutter 전용 로그
adb logcat | grep "flutter"

# 시스템 Intent 로그
adb logcat | grep "ActivityManager"
```

중요한 로그 패턴:
- `ActivityManager: START` - Activity 시작 로그
- `Intent` - Intent 관련 로그
- `PackageManager` - 패키지 등록 관련 로그

### Step 4: 문제 진단 및 해결

#### 4.1 공유 목록에 앱이 표시되지 않는 경우

**원인 분석:**
```bash
# 시스템에서 인식하는 공유 가능한 앱 목록 확인
adb shell pm query-activities \
  -a android.intent.action.SEND \
  -t "text/plain"

# MessageCal이 목록에 있는지 확인
adb shell pm query-activities \
  -a android.intent.action.SEND \
  -t "text/plain" | grep message_cal
```

**해결 방법:**
1. **앱 재설치**
   ```bash
   # 완전 삭제 후 재설치
   adb uninstall com.example.message_cal
   flutter install
   ```

2. **시스템 캐시 초기화**
   ```bash
   # 시스템 패키지 캐시 초기화 (root 권한 필요)
   adb shell pm clear android
   ```

3. **Manifest 설정 수정**
   ```xml
   <!-- 더 구체적인 MIME 타입 추가 -->
   <intent-filter>
       <action android:name="android.intent.action.SEND" />
       <category android:name="android.intent.category.DEFAULT" />
       <data android:mimeType="text/plain" />
   </intent-filter>
   <intent-filter>
       <action android:name="android.intent.action.SEND" />
       <category android:name="android.intent.category.DEFAULT" />
       <data android:mimeType="text/*" />
   </intent-filter>
   ```

#### 4.2 앱은 실행되지만 텍스트를 수신하지 못하는 경우

**진단 방법:**
```dart
// lib/screens/home_screen.dart 디버깅 코드 추가
@override
void initState() {
  super.initState();
  
  print("HomeScreen initState called");
  
  // 스트림 리스너 디버깅
  _intentDataStreamSubscription =
      ReceiveSharingIntent.instance.getMediaStream().listen(
    (List<SharedMediaFile> value) {
      print("Stream received: ${value.length} files");
      for (var file in value) {
        print("File type: ${file.type}, path: ${file.path}");
      }
      // ... 기존 코드
    },
    onError: (err) {
      print("Stream error: $err");
    },
  );

  // 초기 데이터 디버깅
  ReceiveSharingIntent.instance.getInitialMedia().then((value) {
    print("Initial media received: ${value.length} files");
    for (var file in value) {
      print("Initial file type: ${file.type}, path: ${file.path}");
    }
    // ... 기존 코드
  });
}
```

#### 4.3 특정 앱에서만 동작하지 않는 경우

**앱별 테스트 매트릭스:**

| 앱 | MIME Type | 예상 동작 | 실제 결과 | 비고 |
|---|---|---|---|---|
| 카카오톡 | text/plain | ✅ | ⬜ | |
| 문자메시지 | text/plain | ✅ | ⬜ | |
| 텔레그램 | text/plain | ✅ | ⬜ | |
| Chrome | text/plain | ✅ | ⬜ | |
| Gmail | text/plain | ✅ | ⬜ | |

### Step 5: 성능 및 안정성 테스트

#### 5.1 부하 테스트
```bash
# 연속 공유 테스트
for i in {1..10}; do
  adb shell am start \
    -a android.intent.action.SEND \
    -t "text/plain" \
    -e android.intent.extra.TEXT "테스트 메시지 $i" \
    com.example.message_cal/.MainActivity
  sleep 2
done
```

#### 5.2 메모리 사용량 모니터링
```bash
# 메모리 사용량 확인
adb shell dumpsys meminfo com.example.message_cal

# CPU 사용량 확인
adb shell top | grep message_cal
```

#### 5.3 배터리 영향 테스트
```bash
# 배터리 사용량 확인
adb shell dumpsys batterystats | grep message_cal
```

### Step 6: 자동화 테스트 스크립트

#### 6.1 기본 테스트 스크립트
```bash
#!/bin/bash
# test_sharing.sh

echo "MessageCal 공유 기능 테스트 시작"

# 1. 앱 설치 확인
if adb shell pm list packages | grep -q "com.example.message_cal"; then
    echo "✅ 앱이 설치되어 있습니다"
else
    echo "❌ 앱이 설치되어 있지 않습니다"
    exit 1
fi

# 2. Intent Filter 확인
if adb shell pm query-activities -a android.intent.action.SEND -t "text/plain" | grep -q "message_cal"; then
    echo "✅ Intent Filter가 등록되어 있습니다"
else
    echo "❌ Intent Filter가 등록되어 있지 않습니다"
fi

# 3. 테스트 Intent 전송
echo "테스트 Intent 전송 중..."
adb shell am start \
  -a android.intent.action.SEND \
  -t "text/plain" \
  -e android.intent.extra.TEXT "자동 테스트: $(date)" \
  com.example.message_cal/.MainActivity

echo "테스트 완료"
```

#### 6.2 CI/CD 통합 테스트
```yaml
# .github/workflows/test_sharing.yml
name: Sharing Functionality Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-java@v1
        with:
          java-version: '11'
      - uses: subosito/flutter-action@v1
      - run: flutter pub get
      - run: flutter test
      - name: Build APK
        run: flutter build apk --debug
      - name: Upload APK for manual testing
        uses: actions/upload-artifact@v2
        with:
          name: debug-apk
          path: build/app/outputs/flutter-apk/app-debug.apk
```

## 문제 해결 체크리스트

### 일반적인 문제들

#### ❌ 공유 목록에 앱이 표시되지 않음
- [ ] AndroidManifest.xml의 intent-filter 설정 확인
- [ ] 앱이 올바르게 설치되었는지 확인
- [ ] MIME 타입 설정 확인 (`text/*` vs `text/plain`)
- [ ] android:exported="true" 설정 확인

#### ❌ 앱이 실행되지만 데이터를 받지 못함
- [ ] receive_sharing_intent 패키지 최신 버전 사용
- [ ] getMediaStream()과 getInitialMedia() 모두 구현
- [ ] 디버그 로그로 데이터 수신 확인
- [ ] SharedMediaFile.path에서 텍스트 내용 추출 확인

#### ❌ 특정 앱에서만 동작하지 않음
- [ ] 해당 앱의 공유 MIME 타입 확인
- [ ] 다양한 MIME 타입 지원 추가
- [ ] 앱별 특수한 Intent Extra 확인

#### ❌ 성능 문제
- [ ] 메모리 누수 확인
- [ ] UI 스레드 블로킹 방지
- [ ] 적절한 에러 처리 구현

## 배포 전 최종 검증

### 체크리스트
- [ ] 최소 5개 이상의 서로 다른 앱에서 공유 테스트 성공
- [ ] 다양한 Android 버전에서 테스트 (API 24, 28, 30+)
- [ ] 다양한 기기 제조사에서 테스트 (Samsung, LG, Google 등)
- [ ] 긴 텍스트, 특수문자 포함 텍스트 테스트
- [ ] 앱 백그라운드/포그라운드 상태별 테스트
- [ ] 메모리 부족 상황에서의 안정성 테스트

### 성능 지표
- 공유 성공률: 95% 이상
- 앱 실행 시간: 3초 이내
- 메모리 사용량: 100MB 이하
- 배터리 드레인: 무시할 수 있는 수준

## 참고 자료

- [Android Intent and Intent Filters](https://developer.android.com/guide/components/intents-filters)
- [receive_sharing_intent 패키지 문서](https://pub.dev/packages/receive_sharing_intent)
- [Android Debug Bridge (ADB) 가이드](https://developer.android.com/studio/command-line/adb)
- [Flutter 앱 디버깅 가이드](https://docs.flutter.dev/testing/debugging)