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
      print('No current user found');
      return null;
    }

    try {
      final authentication = await user.authentication;
      if (authentication.accessToken == null) {
        print('No access token available');
        return null;
      }

      final authHeaders = await user.authHeaders;
      print('Auth headers: $authHeaders');
      
      final credentials = AccessCredentials(
        AccessToken(
          'Bearer',
          authentication.accessToken!,
          DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
        null,
        ['https://www.googleapis.com/auth/calendar.events'],
      );

      final client = authenticatedClient(
        http.Client(),
        credentials,
      );

      return calendar.CalendarApi(client);
    } catch (e) {
      print('Error getting calendar API: $e');
      return null;
    }
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
      _calendarApi = await _getCalendarApi();
      if (_calendarApi == null) {
        throw Exception('Google Calendar API 초기화 실패');
      }

      // 한국 시간대(UTC+9)를 고려한 시간 설정
      DateTime startDateTime = startDate;
      DateTime endDateTime = startDate.add(const Duration(hours: 1));
      
      if (startTime != null) {
        // 한국 시간으로 DateTime 생성 후 UTC로 변환
        final localDateTime = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          startTime.hour,
          startTime.minute,
        );
        
        // UTC로 변환 (한국은 UTC+9이므로 9시간을 빼서 UTC로 만듦)
        startDateTime = localDateTime.subtract(const Duration(hours: 9));
        endDateTime = startDateTime.add(const Duration(hours: 1));
      }
      
      print('Korean local time: ${startTime?.hour}:${startTime?.minute}');
      print('UTC start time for API: $startDateTime');
      print('UTC end time for API: $endDateTime');

      // 이벤트 생성 (시간대 문제 해결)
      final event = calendar.Event()
        ..summary = title
        ..start = calendar.EventDateTime()
        ..end = calendar.EventDateTime();

      // UTC 시간으로 설정 (timeZone 지정 안함)
      if (startTime != null) {
        // UTC 시간으로 설정
        event.start!.dateTime = startDateTime.toUtc();
        event.end!.dateTime = endDateTime.toUtc();
      } else {
        // 하루 종일 이벤트: date 사용  
        event.start!.date = DateTime(startDate.year, startDate.month, startDate.day);
        event.end!.date = DateTime(endDateTime.year, endDateTime.month, endDateTime.day);
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

      // 디버깅: 이벤트 시간 정보 출력
      for (final event in events.items ?? []) {
        final eventStartTime = event.start?.dateTime ?? event.start?.date;
        print('Event: ${event.summary}');
        print('  Raw start: ${event.start?.dateTime}');
        print('  Raw date: ${event.start?.date}');  
        print('  TimeZone: ${event.start?.timeZone}');
        print('  Computed startTime: $eventStartTime');
        print('  Local conversion: ${eventStartTime?.toLocal()}');
        print('---');
      }

      return events.items ?? [];
    } catch (e) {
      print('Failed to fetch events: $e');
      return [];
    }
  }
}