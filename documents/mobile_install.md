- 용량: 더 작음
  - 설치: APK 파일을 핸드폰으로 복사 후 설치

  2. Android App Bundle 빌드 (Play Store용)

  flutter build appbundle --release
  - 생성 위치: build/app/outputs/bundle/release/app-release.aab
  - 용도: Google Play Store 업로드용

  3. 핸드폰 설치 단계:

  옵션 A: 직접 연결
  # 핸드폰을 USB로 연결 후
  flutter install

  옵션 B: APK 파일 전송
  1. flutter build apk --release 실행
  2. build/app/outputs/flutter-apk/app-release.apk 파일을 핸드폰으로 복사
  3. 핸드폰에서 설정 > 보안 > 알 수 없는 소스 허용
  4. APK 파일 터치하여 설치

  📋 전체 빌드 과정:

  # 1. 의존성 설치
  flutter pub get

  # 2. 앱 아이콘 생성
  flutter packages pub run flutter_launcher_icons:main

  # 3. APK 빌드
  flutter build apk --release

  # 4. (선택) 직접 설치
  flutter install

  참고: Release 빌드는 Debug 빌드보다 훨씬 빠르고 용량이 작습니다. 실제 사용을 위해서는
  --release 옵션을 꼭 사용하세요!