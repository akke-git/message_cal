
## App(프로젝트) 이름
MessageCal

## Android Client name
MessageCal Android Client

## 클라이언트 ID
571347725381-4s5j8n68s76lpjptfb2o53rum157145c.apps.googleusercontent.com

## 패키지 이름
com.example.message_cal

## SHA1 지문
8B:94:44:5C:94:C3:77:78:07:05:9F:DE:16:F8:EF:D8:DB:9F:C8:F1







VSCode에서 Android 에뮬레이터를 실행하는 방법을 안내해드리겠습니다.



📱 VSCode에서 Android 에뮬레이터 실행 방법


방법 1: Command Palette 사용 (가장 쉬운 방법)


VSCode에서 `Ctrl + Shift + P` (또는 `F1`) 누르기
"Flutter: Launch Emulator" 입력
사용 가능한 에뮬레이터 목록에서 선택


방법 2: VSCode 하단 상태바 사용


VSCode 하단 상태바 확인
"No Device Selected" 또는 현재 선택된 디바이스 클릭
"Start iOS Simulator" 또는 Android 에뮬레이터 선택


방법 3: Flutter Extension 사용


VSCode 왼쪽 사이드바에서 Flutter Extension 아이콘 클릭
"DEVICES" 섹션에서 에뮬레이터 선택
▶️ 버튼 클릭하여 실행



---



🚨 에뮬레이터가 안 보이는 경우 해결 방법


1. Android Studio에서 에뮬레이터 생성



```bash

Android Studio 실행
Tools > AVD Manager > Create Virtual Device
또는 명령어로 확인

flutter emulators

```



2. 에뮬레이터가 없는 경우 생성



Android Studio에서:

Tools → AVD Manager 클릭
"Create Virtual Device" 클릭
Phone → Pixel 7 선택 (권장)
System Image → API 34 (Android 14) 선택
"Next" → "Finish"


3. 명령어로 에뮬레이터 실행



```bash

사용 가능한 에뮬레이터 목록 확인

flutter emulators



특정 에뮬레이터 실행 (예시)

flutter emulators --launch Pixel_7_API_34

```




---



🔧 에뮬레이터 실행 후 Flutter 앱 실행


1. 에뮬레이터가 실행된 후:



```bash

flutter run

```



2. 또는 VSCode에서:
F5 키 누르기 (디버그 모드로 실행)
Ctrl + F5 (디버그 없이 실행)



---



📋 문제 해결


에뮬레이터가 목록에 안 나타나는 경우:


Android SDK 경로 확인:

```bash

flutter doctor

```



VSCode 재시작


Flutter Extension 재설치


에뮬레이터가 느린 경우:
AVD Manager에서 RAM 크기 증가 (4GB 이상)
Hardware Acceleration 활성화
Graphics: Hardware - GLES 2.0 선택



---




에뮬레이터가 실행되면 MessageCal 앱에서 Google 로그인과 공유 기능을 실제로 테스트할 수 있습니다!




어떤 단계에서 문제가 발생하는지 알려주시면 더 자세히 도와드리겠습니다.