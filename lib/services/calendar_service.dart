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
      http.Client(),
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