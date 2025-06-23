# Google Calendar API 연동 구현 가이드

## 개요
MessageCal 앱에서 Google Calendar API를 실제로 연동하여 공유된 메시지로부터 추출한 일정 정보를 Google Calendar에 이벤트로 생성하는 기능을 구현하는 단계별 가이드입니다.

## 사전 준비사항

### 1. Google Cloud Console 설정
1. **Google Cloud Console 접속**
   - https://console.cloud.google.com/ 접속
   - 프로젝트 생성 또는 기존 프로젝트 선택

2. **Calendar API 활성화**
   ```
   1. API 및 서비스 > 라이브러리 이동
   2. "Google Calendar API" 검색
   3. "사용 설정" 클릭
   ```

3. **OAuth 2.0 클라이언트 ID 생성**
   ```
   1. API 및 서비스 > 사용자 인증 정보 이동
   2. "사용자 인증 정보 만들기" > "OAuth 클라이언트 ID" 선택
   3. 애플리케이션 유형: "Android" 선택
   4. 패키지 이름: com.example.message_cal
   5. SHA-1 인증서 지문 추가 (개발용)
   ```

### 2. SHA-1 인증서 지문 생성
```bash
# 개발용 키스토어 생성 (없는 경우)
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# SHA-1 지문 추출
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# 출력된 SHA1 값을 Google Cloud Console에 등록
```

## 단계별 구현

### Step 1: Calendar Service 클래스 생성

`lib/services/calendar_service.dart` 파일을 생성합니다:

```dart
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:message_cal/services/auth_service.dart';

class CalendarService {
  final AuthService _authService = AuthService();
  calendar.CalendarApi? _calendarApi;

  Future<calendar.CalendarApi?> _getCalendarApi() async {
    final user = _authService.getCurrentUser();
    if (user == null) return null;

    final authHeaders = await user.authHeaders;
    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        authHeaders['Authorization']?.replaceAll('Bearer ', '') ?? '',
        DateTime.now().add(const Duration(hours: 1)),
      ),
      null,
      ['https://www.googleapis.com/auth/calendar.events'],
    );

    final client = authenticatedClient(
      httpClient: HttpClient(),
      credentials,
    );

    return calendar.CalendarApi(client);
  }

  Future<bool> createEvent({
    required String title,
    required DateTime startDate,
    TimeOfDay? startTime,
    String? location,
    String? description,
    String? category,
  }) async {
    try {
      _calendarApi = await _getCalendarApi();
      if (_calendarApi == null) {
        throw Exception('Google Calendar API 초기화 실패');
      }

      // 시작 시간 설정
      DateTime startDateTime = startDate;
      DateTime endDateTime = startDate.add(const Duration(hours: 1));
      
      if (startTime != null) {
        startDateTime = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          startTime.hour,
          startTime.minute,
        );
        endDateTime = startDateTime.add(const Duration(hours: 1));
      }

      // 이벤트 생성
      final event = calendar.Event()
        ..summary = title
        ..start = calendar.EventDateTime(
          dateTime: startDateTime,
          timeZone: 'Asia/Seoul',
        )
        ..end = calendar.EventDateTime(
          dateTime: endDateTime,
          timeZone: 'Asia/Seoul',
        )
        ..location = location
        ..description = description
        ..colorId = _getCategoryColorId(category);

      // Calendar에 이벤트 추가
      await _calendarApi!.events.insert(event, 'primary');
      return true;
    } catch (e) {
      print('Calendar event creation failed: $e');
      return false;
    }
  }

  String _getCategoryColorId(String? category) {
    switch (category) {
      case '업무':
        return '9'; // 파란색
      case '개인':
        return '10'; // 초록색
      case '건강':
        return '11'; // 빨간색
      case '금융':
        return '5'; // 노란색
      default:
        return '1'; // 기본 색상
    }
  }

  Future<List<calendar.Event>> getEvents({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      _calendarApi = await _getCalendarApi();
      if (_calendarApi == null) return [];

      final now = DateTime.now();
      final start = startDate ?? now.subtract(const Duration(days: 30));
      final end = endDate ?? now.add(const Duration(days: 30));

      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: start,
        timeMax: end,
        singleEvents: true,
        orderBy: 'startTime',
      );

      return events.items ?? [];
    } catch (e) {
      print('Failed to fetch events: $e');
      return [];
    }
  }
}
```

### Step 2: AuthService 개선

기존 `lib/services/auth_service.dart`를 업데이트합니다:

```dart
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/calendar.events',
      'https://www.googleapis.com/auth/calendar.readonly',
    ],
  );

  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        // 권한 확인
        final auth = await account.authentication;
        if (auth.accessToken != null) {
          print('Google sign-in successful');
          return account;
        }
      }
      return null;
    } catch (error) {
      print('Error signing in with Google: $error');
      return null;
    }
  }

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  GoogleSignInAccount? getCurrentUser() {
    return _googleSignIn.currentUser;
  }

  Future<Map<String, String>?> getAuthHeaders() async {
    final user = getCurrentUser();
    if (user == null) return null;
    
    try {
      return await user.authHeaders;
    } catch (e) {
      print('Failed to get auth headers: $e');
      return null;
    }
  }
}
```

### Step 3: ShareReceiverScreen 업데이트

`lib/screens/share_receiver_screen.dart`의 `_saveToCalendar` 메서드를 수정합니다:

```dart
import 'package:message_cal/services/calendar_service.dart';

class _ShareReceiverScreenState extends State<ShareReceiverScreen> {
  final CalendarService _calendarService = CalendarService();
  
  // ... 기존 코드 ...

  Future<void> _saveToCalendar() async {
    // 로그인 상태 확인
    final authService = AuthService();
    final isSignedIn = await authService.isSignedIn();
    
    if (!isSignedIn) {
      _showErrorSnackBar('Google 계정에 로그인이 필요합니다.');
      return;
    }

    // 필수 필드 검증
    if (_titleController.text.isEmpty) {
      _showErrorSnackBar('일정 제목을 입력해주세요.');
      return;
    }

    if (_selectedDate == null) {
      _showErrorSnackBar('날짜를 선택해주세요.');
      return;
    }

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await _calendarService.createEvent(
        title: _titleController.text,
        startDate: _selectedDate!,
        startTime: _selectedTime,
        location: _locationController.text.isNotEmpty 
            ? _locationController.text 
            : null,
        description: '원본 메시지: ${_textController.text}',
        category: _selectedCategory,
      );

      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정이 Google Calendar에 저장되었습니다: ${_titleController.text}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(); // 화면 닫기
      } else {
        _showErrorSnackBar('일정 저장에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      _showErrorSnackBar('오류가 발생했습니다: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ... 기존 코드 ...
}
```

### Step 4: CalendarScreen에서 실제 이벤트 표시

`lib/screens/calendar_screen.dart`를 업데이트하여 실제 Google Calendar 이벤트를 표시합니다:

```dart
import 'package:message_cal/services/calendar_service.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  final CalendarService _calendarService = CalendarService();
  List<calendar.Event> _events = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final events = await _calendarService.getEvents(
        startDate: DateTime(_selectedDate.year, _selectedDate.month, 1),
        endDate: DateTime(_selectedDate.year, _selectedDate.month + 1, 0),
      );
      
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Failed to load events: $e');
    }
  }

  // ... UI 코드에서 _events 사용 ...
}
```

### Step 5: 권한 및 네트워크 설정

#### Android 권한 추가 (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

#### HTTP 통신 허용 (`android/app/src/main/AndroidManifest.xml`):
```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```

## 테스트 및 검증

### 단위 테스트
1. **CalendarService 테스트**
   ```dart
   test('Calendar event creation', () async {
     // Mock 데이터로 이벤트 생성 테스트
   });
   ```

2. **AuthService 테스트**
   ```dart
   test('Google authentication', () async {
     // 인증 플로우 테스트
   });
   ```

### 통합 테스트
1. **전체 플로우 테스트**
   - 공유 → 분석 → 일정 생성 → Calendar 저장
   - 오프라인/온라인 상태 전환 테스트
   - 에러 상황 처리 테스트

## 주의사항 및 모범 사례

### 보안
- OAuth 토큰 안전한 저장
- API 키 노출 방지
- 사용자 권한 최소화

### 성능
- API 호출 최적화 (캐싱 활용)
- 네트워크 상태 확인
- 배치 처리 고려

### 사용자 경험
- 로딩 상태 표시
- 명확한 에러 메시지
- 오프라인 지원 (로컬 저장 후 동기화)

### 에러 처리
```dart
enum CalendarError {
  notAuthenticated,
  networkError,
  permissionDenied,
  quotaExceeded,
  unknown,
}

class CalendarException implements Exception {
  final CalendarError type;
  final String message;
  
  CalendarException(this.type, this.message);
}
```

## 배포 전 체크리스트

- [ ] Google Cloud Console OAuth 설정 완료
- [ ] 프로덕션 SHA-1 키 등록
- [ ] API 할당량 확인
- [ ] 개인정보처리방침 업데이트
- [ ] 권한 요청 다이얼로그 추가
- [ ] 에러 로깅 및 모니터링 설정
- [ ] 오프라인 모드 구현
- [ ] 성능 테스트 완료

## 참고 자료

- [Google Calendar API 문서](https://developers.google.com/calendar/api)
- [Flutter Google Sign-In 플러그인](https://pub.dev/packages/google_sign_in)
- [googleapis 패키지](https://pub.dev/packages/googleapis)
- [OAuth 2.0 가이드](https://developers.google.com/identity/protocols/oauth2)