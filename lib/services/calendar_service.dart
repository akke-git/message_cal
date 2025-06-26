import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:message_cal/services/auth_service.dart';
import 'package:http/http.dart' as http;

class CalendarService {
  final AuthService _authService = AuthService();
  calendar.CalendarApi? _calendarApi;

  Future<calendar.CalendarApi?> _getCalendarApi() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      print('CALENDAR_API: No current user found');
      return null;
    }

    print('CALENDAR_API: Current user email: ${user.email}');

    try {
      final authentication = await user.authentication;
      if (authentication.accessToken == null) {
        print('CALENDAR_API: No access token available');
        return null;
      }

      print('CALENDAR_API: Access token available (length: ${authentication.accessToken!.length})');
      
      final authHeaders = await user.authHeaders;
      print('CALENDAR_API: Auth headers keys: ${authHeaders.keys}');
      
      final credentials = AccessCredentials(
        AccessToken(
          'Bearer',
          authentication.accessToken!,
          DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
        authentication.idToken,
        [
          'https://www.googleapis.com/auth/calendar.events',
          'https://www.googleapis.com/auth/calendar.readonly',
        ],
      );

      final client = authenticatedClient(
        http.Client(),
        credentials,
      );

      print('CALENDAR_API: Calendar API client created successfully');
      return calendar.CalendarApi(client);
    } catch (e) {
      print('CALENDAR_API: Error getting calendar API: $e');
      print('CALENDAR_API: Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  Future<calendar.Event?> createEventWithDetails({
    required String title,
    required DateTime startDate,
    TimeOfDay? startTime,
    String? location,
    String? description,
    String? category,
    int? reminderMinutes,
  }) async {
    try {
      final createdEvent = await _createEventInternal(
        title: title,
        startDate: startDate,
        startTime: startTime,
        location: location,
        description: description,
        category: category,
        reminderMinutes: reminderMinutes,
      );
      return createdEvent;
    } catch (e) {
      print('Calendar event creation failed: $e');
      return null;
    }
  }

  Future<calendar.Event?> _createEventInternal({
    required String title,
    required DateTime startDate,
    TimeOfDay? startTime,
    String? location,
    String? description,
    String? category,
    int? reminderMinutes,
  }) async {
    _calendarApi = await _getCalendarApi();
    if (_calendarApi == null) {
      throw Exception('Google Calendar API 초기화 실패');
    }

    // 한국 시간대(Asia/Seoul)를 고려한 시간 설정
    DateTime startDateTime;
    DateTime endDateTime;
    
    if (startTime != null) {
      // 한국 시간으로 명시적 DateTime 생성 (UTC 변환하지 않음)
      // Google Calendar API에서 timeZone이 설정되면 이 시간을 해당 시간대의 로컬 시간으로 해석
      startDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        startTime.hour,
        startTime.minute,
        0, // seconds
        0, // milliseconds
      );
      endDateTime = startDateTime.add(const Duration(hours: 1));
      
      print('CALENDAR_SERVICE: Input time - ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}');
      print('CALENDAR_SERVICE: Created DateTime - $startDateTime');
      print('CALENDAR_SERVICE: isUtc: ${startDateTime.isUtc}');
    } else {
      // 하루 종일 이벤트
      startDateTime = DateTime(startDate.year, startDate.month, startDate.day);
      endDateTime = startDateTime.add(const Duration(days: 1));
    }

    // 이벤트 생성 (시간대 명시적 설정)
    final event = calendar.Event()
      ..summary = title
      ..start = calendar.EventDateTime()
      ..end = calendar.EventDateTime();

    if (startTime != null) {
      // 시간 지정 이벤트: RFC3339 형식으로 한국 시간대 직접 명시
      // Google Calendar API의 시간대 버그를 우회하기 위해 +09:00 오프셋 사용
      final startTimeStr = '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}T${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00+09:00';
      final endHour = (startTime.hour + 1) % 24;
      final endTimeStr = '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}T${endHour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00+09:00';
      
      try {
        event.start!.dateTime = DateTime.parse(startTimeStr);
        event.end!.dateTime = DateTime.parse(endTimeStr);
        
        print('CALENDAR_SERVICE: Using RFC3339 format with +09:00 timezone');
        print('CALENDAR_SERVICE: Start time string: $startTimeStr');
        print('CALENDAR_SERVICE: End time string: $endTimeStr');
        print('CALENDAR_SERVICE: Parsed start DateTime: ${event.start!.dateTime}');
      } catch (e) {
        print('CALENDAR_SERVICE: RFC3339 parsing failed, falling back to naive datetime: $e');
        // 실패하면 기존 방식
        event.start!.dateTime = startDateTime;
        event.start!.timeZone = 'Asia/Seoul';
        event.end!.dateTime = endDateTime;
        event.end!.timeZone = 'Asia/Seoul';
      }
    } else {
      // 하루 종일 이벤트: date 사용  
      event.start!.date = DateTime(startDate.year, startDate.month, startDate.day);
      event.end!.date = DateTime(startDate.year, startDate.month, startDate.day + 1);
      print('CALENDAR_SERVICE: All-day event from ${event.start!.date} to ${event.end!.date}');
    }

    event
      ..location = location
      ..description = description
      ..colorId = _getCategoryColorId(category);

    // 알림 설정
    if (reminderMinutes != null && reminderMinutes > 0) {
      event.reminders = calendar.EventReminders()
        ..useDefault = false
        ..overrides = [
          calendar.EventReminder()
            ..method = 'popup'
            ..minutes = reminderMinutes,
        ];
    }

    // Calendar에 이벤트 추가
    print('Creating event with title: $title');
    print('Event start: ${event.start?.dateTime} (${event.start?.timeZone})');
    print('Event end: ${event.end?.dateTime} (${event.end?.timeZone})');
    
    final createdEvent = await _calendarApi!.events.insert(event, 'primary');
    print('CALENDAR_SERVICE: Event created successfully with ID: ${createdEvent.id}');
    
    // 생성된 이벤트의 실제 시간 확인
    if (createdEvent.start?.dateTime != null) {
      print('CALENDAR_SERVICE: Created event start time: ${createdEvent.start!.dateTime}');
      print('CALENDAR_SERVICE: Created event timezone: ${createdEvent.start!.timeZone}');
    }
    if (createdEvent.end?.dateTime != null) {
      print('CALENDAR_SERVICE: Created event end time: ${createdEvent.end!.dateTime}');
      print('CALENDAR_SERVICE: Created event end timezone: ${createdEvent.end!.timeZone}');
    }
    
    return createdEvent;
  }

  Future<bool> createEvent({
    required String title,
    required DateTime startDate,
    TimeOfDay? startTime,
    String? location,
    String? description,
    String? category,
    int? reminderMinutes,
  }) async {
    try {
      final createdEvent = await _createEventInternal(
        title: title,
        startDate: startDate,
        startTime: startTime,
        location: location,
        description: description,
        category: category,
        reminderMinutes: reminderMinutes,
      );
      return createdEvent != null;
    } catch (e) {
      print('Calendar event creation failed: $e');
      print('Stack trace: ${StackTrace.current}');
      if (e.toString().contains('403')) {
        print('Permission denied - check Google Calendar API permissions');
      } else if (e.toString().contains('401')) {
        print('Authentication failed - token may be expired');
      } else if (e.toString().contains('400')) {
        print('Bad request - check event data format');
      }
      return false;
    }
  }

  String _getCategoryColorId(String? category) {
    switch (category) {
      case '예약':
        return '9'; // 파란색
      case '점심':
        return '10'; // 초록색
      case '골프':
        return '11'; // 빨간색
      case '결제':
        return '5'; // 주황색
      case '기념일':
        return '6'; // 자주색
      case '회사':
        return '7'; // 보라색
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
      if (_calendarApi == null) {
        print('CALENDAR_SERVICE: Calendar API is null');
        return [];
      }

      final now = DateTime.now();
      final start = startDate ?? now.subtract(const Duration(days: 30));
      final end = endDate ?? now.add(const Duration(days: 30));

      print('CALENDAR_SERVICE: Fetching events from $start to $end');

      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: start,
        timeMax: end,
        singleEvents: true,
        orderBy: 'startTime',
      );

      final eventList = events.items ?? [];
      print('CALENDAR_SERVICE: Found ${eventList.length} events');
      
      // 각 이벤트의 기본 정보 출력
      for (int i = 0; i < eventList.length && i < 5; i++) {
        final event = eventList[i];
        print('CALENDAR_SERVICE: Event $i - ID: ${event.id}, Title: ${event.summary}');
        print('CALENDAR_SERVICE: Event $i - Start: ${event.start?.dateTime ?? event.start?.date}');
      }

      return eventList;
    } catch (e) {
      print('CALENDAR_SERVICE: Failed to fetch events: $e');
      print('CALENDAR_SERVICE: Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  Future<calendar.Event?> getEventById(String eventId) async {
    try {
      _calendarApi = await _getCalendarApi();
      if (_calendarApi == null) {
        print('CALENDAR_SERVICE: Calendar API is null for getEventById');
        return null;
      }

      print('CALENDAR_SERVICE: Fetching event by ID: $eventId');
      final event = await _calendarApi!.events.get('primary', eventId);
      print('CALENDAR_SERVICE: Found event by ID - Title: ${event.summary}');
      return event;
    } catch (e) {
      print('CALENDAR_SERVICE: Failed to fetch event by ID $eventId: $e');
      return null;
    }
  }
}