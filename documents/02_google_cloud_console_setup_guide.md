# Google Cloud Console 설정 상세 가이드

MessageCal Flutter 앱에서 Google Calendar API를 사용하기 위한 Google Cloud Console 설정을 단계별로 상세하게 안내합니다.

## Google Cloud Console 설정 상세 가이드

### 1단계: Google Cloud Console 접속 및 프로젝트 생성

**1-1. Google Cloud Console 접속**
- 웹 브라우저에서 https://console.cloud.google.com/ 접속
- Google 계정으로 로그인 (Gmail 계정 사용)

**1-2. 프로젝트 생성 (신규 프로젝트인 경우)**
- 화면 상단의 프로젝트 선택 드롭다운 클릭 (현재 프로젝트명 옆의 화살표)
- "새 프로젝트" 버튼 클릭
- 프로젝트 정보 입력:
  - 프로젝트 이름: `MessageCal` 또는 원하는 이름
  - 조직: 개인 계정이면 "조직 없음" 선택
  - 위치: 기본값 유지
- "만들기" 버튼 클릭
- 프로젝트 생성 완료까지 1-2분 대기

### 2단계: Google Calendar API 활성화

**2-1. API 라이브러리 접근**
- 왼쪽 사이드바에서 "API 및 서비스" 클릭
- 하위 메뉴에서 "라이브러리" 클릭

**2-2. Calendar API 검색 및 활성화**
- 검색창에 "Google Calendar API" 입력
- 검색 결과에서 "Google Calendar API" 클릭
- API 상세 페이지에서 "사용 설정" 버튼 클릭
- "API가 사용 설정됨" 메시지 확인

### 3단계: OAuth 동의 화면 구성 (먼저 필요)

**3-1. OAuth 동의 화면 설정**
- 왼쪽 사이드바에서 "API 및 서비스" 클릭
- 하위 메뉴에서 "OAuth 동의 화면" 클릭

**3-2. 사용자 유형 선택**
- "외부" 선택 (개인 개발자인 경우)
- "만들기" 버튼 클릭

**3-3. 앱 정보 입력**
- **앱 이름**: `MessageCal`
- **사용자 지원 이메일**: 본인 Gmail 주소 선택
- **앱 로고**: 선택사항 (건너뛰기 가능)
- **앱 도메인**: 선택사항 (건너뛰기 가능)
- **승인된 도메인**: 비워두기
- **개발자 연락처 정보**: 본인 Gmail 주소 입력
- "저장 후 계속" 클릭

**3-4. 범위 설정**
- "범위 추가 또는 삭제" 클릭
- 검색창에 "calendar" 입력
- 다음 범위들을 선택:
  - `../auth/calendar.events` (캘린더 이벤트 보기 및 수정)
  - `../auth/calendar.readonly` (캘린더 이벤트 보기)
- "업데이트" 클릭
- "저장 후 계속" 클릭

**3-5. 테스트 사용자 추가**
- "테스트 사용자 추가" 클릭
- 본인 Gmail 주소 입력
- "추가" 클릭
- "저장 후 계속" 클릭

**3-6. 요약 확인**
- 설정 내용 확인 후 "대시보드로 돌아가기" 클릭

### 4단계: OAuth 2.0 클라이언트 ID 생성

**4-1. 사용자 인증 정보 페이지로 이동**
- 왼쪽 사이드바에서 "API 및 서비스" 클릭
- 하위 메뉴에서 "사용자 인증 정보" 클릭

**4-2. OAuth 클라이언트 ID 생성**
- 상단의 "+ 사용자 인증 정보 만들기" 클릭
- 드롭다운에서 "OAuth 클라이언트 ID" 선택

**4-3. 애플리케이션 유형 선택**
- "애플리케이션 유형": "Android" 선택

**4-4. Android 앱 정보 입력**
- **이름**: `MessageCal Android Client` (원하는 이름)
- **패키지 이름**: `com.example.message_cal` (정확히 입력)
- **SHA-1 인증서 지문**: 다음 단계에서 생성할 값 입력

### 5단계: SHA-1 인증서 지문 생성 및 등록

**5-1. 개발용 SHA-1 지문 생성**

터미널에서 다음 명령어 실행:

```bash
# Windows (Git Bash 또는 PowerShell)
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# macOS/Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**5-2. SHA-1 값 복사**
- 명령어 실행 결과에서 `SHA1:` 로 시작하는 줄 찾기
- 예시: `SHA1: A1:B2:C3:D4:E5:F6:G7:H8:I9:J0:K1:L2:M3:N4:O5:P6:Q7:R8:S9:T0`
- 콜론(:)을 포함한 전체 값 복사

**5-3. Google Cloud Console에 SHA-1 등록**
- Google Cloud Console의 OAuth 클라이언트 ID 생성 화면으로 돌아가기
- "SHA-1 인증서 지문" 필드에 복사한 값 붙여넣기
- "만들기" 버튼 클릭

**5-4. 클라이언트 ID 정보 확인**
- 생성 완료 후 나타나는 팝업에서 "클라이언트 ID"와 "클라이언트 보안 비밀번호" 확인
- "JSON 다운로드" 클릭하여 설정 파일 다운로드 (선택사항)
- "확인" 클릭

### 6단계: 추가 설정 확인

**6-1. API 할당량 확인**
- 왼쪽 사이드바에서 "API 및 서비스" 클릭
- "할당량" 클릭
- "Google Calendar API" 할당량 확인 (기본적으로 충분함)

**6-2. 설정 완료 확인**
- "사용자 인증 정보" 페이지에서 생성된 OAuth 2.0 클라이언트 ID 확인
- "사용 설정된 API" 페이지에서 Google Calendar API가 활성화되어 있는지 확인

### 7단계: Flutter 앱에서 사용할 정보 정리

생성 완료 후 다음 정보들을 기록해 두세요:

1. **프로젝트 ID**: `your-project-id`
2. **OAuth 2.0 클라이언트 ID**: `123456789-abcdefg.apps.googleusercontent.com`
3. **패키지 이름**: `com.example.message_cal`
4. **SHA-1 지문**: 등록한 SHA-1 값

## 주의사항

- **테스트 모드**: 현재 앱은 테스트 모드로 설정되어 있어 테스트 사용자만 로그인 가능합니다.
- **배포 시**: 앱을 실제 배포할 때는 OAuth 동의 화면을 "게시됨" 상태로 변경해야 합니다.
- **보안**: 클라이언트 ID와 같은 민감한 정보는 안전하게 관리하세요.
- **할당량**: Google Calendar API 사용량이 많은 경우 할당량 증가를 요청해야 할 수 있습니다.

## 다음 단계

Google Cloud Console 설정이 완료되었습니다! 이제 Flutter 앱에서 Google Calendar API를 사용할 준비가 되었습니다. 

다음으로 진행할 작업:
1. Flutter 프로젝트의 CalendarService 구현
2. AuthService 업데이트
3. 실제 Google Calendar 연동 테스트

## 문제 해결

### 자주 발생하는 문제

1. **SHA-1 지문 오류**
   - Android 디버그 키스토어가 없는 경우: Flutter 프로젝트에서 `flutter run` 실행 후 다시 시도
   - 경로 문제: `%USERPROFILE%\.android\debug.keystore` 또는 `~/.android/debug.keystore` 파일 존재 확인

2. **OAuth 동의 화면 오류**
   - 범위 설정을 빠뜨린 경우: 3-4단계 다시 확인
   - 테스트 사용자 미등록: 3-5단계에서 본인 이메일 추가 확인

3. **API 활성화 오류**
   - 프로젝트 선택 확인: 올바른 프로젝트가 선택되어 있는지 확인
   - 결제 계정 연결: 필요한 경우 결제 계정 연결 (무료 할당량 내에서는 불필요)