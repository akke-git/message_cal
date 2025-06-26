import 'package:flutter/material.dart';
import 'package:message_cal/services/database_service.dart';
import 'package:message_cal/services/llm_service.dart';
import 'package:message_cal/services/calendar_service.dart';
import 'package:message_cal/services/auth_service.dart';

class BackgroundService {
  final DatabaseService _dbService = DatabaseService.instance;
  final LlmService _llmService;
  final CalendarService _calendarService = CalendarService();
  final AuthService _authService = AuthService();

  BackgroundService({required String apiKey}) 
      : _llmService = LlmService(apiKey: apiKey);

  Future<void> processPendingEvents() async {
    print("BG_SERVICE: Starting processPendingEvents...");

    // 1. 로그인 상태 확인
    final isSignedIn = await _authService.isSignedIn();
    if (!isSignedIn) {
      print("BG_SERVICE: User not signed in. Skipping processing.");
      return;
    }
    print("BG_SERVICE: User is signed in.");

    // 2. 처리 대기중인 이벤트 가져오기
    final pendingEvents = await _dbService.getPendingEvents();
    if (pendingEvents.isEmpty) {
      print("BG_SERVICE: No pending events to process.");
      return;
    }

    print("BG_SERVICE: Found ${pendingEvents.length} pending events. Starting loop...");

    for (final eventData in pendingEvents) {
      final eventId = eventData['id'] as int;
      final sharedText = eventData['shared_text'] as String;
      print("BG_SERVICE: Processing event #$eventId: $sharedText");

      try {
        // 3. 상태를 'processing'으로 변경
        await _dbService.updateEventStatus(eventId, 'processing');
        print("BG_SERVICE: Event #$eventId status updated to processing.");

        // 4. LLM으로 정보 추출
        print("BG_SERVICE: Calling LLM to extract details...");
        final details = await _llmService.extractEventDetails(sharedText);
        print("BG_SERVICE: LLM response received: $details");
        
        // API 키 존재 여부 확인
        if (_llmService.apiKey == null) {
          print("BG_SERVICE: ERROR - API key is null!");
          throw Exception('API key is not set');
        }
        print("BG_SERVICE: API key is set: ${_llmService.apiKey!.substring(0, 10)}...");

        final title = details['title'] as String?;
        final dateStr = details['date'] as String?;
        final timeStr = details['time'] as String?;

        if (title == null || dateStr == null) {
          throw Exception('Essential information (title, date) could not be extracted.');
        }

        final startDate = DateTime.parse(dateStr);
        TimeOfDay? startTime;
        if (timeStr != null) {
          final parts = timeStr.split(':');
          if (parts.length == 2) {
            startTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        }

        // 5. 구글 캘린더에 이벤트 생성
        print("BG_SERVICE: Calling CalendarService to create event...");
        final createdEvent = await _calendarService.createEventWithDetails(
          title: title,
          startDate: startDate,
          startTime: startTime,
          description: '원본 메시지: $sharedText',
          category: details['category'] as String?,
          reminderMinutes: 30, // 기본값
        );
        
        final success = createdEvent != null;
        print("BG_SERVICE: Calendar event creation result: $success");
        if (createdEvent != null) {
          print("BG_SERVICE: Created event ID: ${createdEvent.id}");
        }

        // 6. 결과에 따라 상태 업데이트
        if (success && createdEvent != null) {
          // 생성된 이벤트를 다시 조회해서 실제로 존재하는지 확인
          print("BG_SERVICE: Verifying created event ID: ${createdEvent.id}");
          final verifyEvent = await _calendarService.getEventById(createdEvent.id!);
          
          if (verifyEvent != null) {
            print("BG_SERVICE: Event verification SUCCESS - Event exists in calendar");
            try {
              // 캘린더 등록 정보와 이벤트 ID 저장
              await _dbService.updateEventWithDetailsAndId(
                eventId, 
                'completed',
                title,
                dateStr,
                timeStr,
                details['category'] as String? ?? '기타',
                createdEvent.id ?? '',
              );
              print("BG_SERVICE: Event #$eventId processed and added to calendar successfully with ID: ${createdEvent.id}");
            } catch (dbError) {
              // DB 업데이트 실패해도 캘린더 등록은 성공했으므로 completed로 설정
              print("BG_SERVICE: DB update failed but calendar creation succeeded: $dbError");
              await _dbService.updateEventStatus(eventId, 'completed');
              print("BG_SERVICE: Event #$eventId marked as completed despite DB schema issue.");
            }
          } else {
            print("BG_SERVICE: Event verification FAILED - Event does not exist in calendar!");
            await _dbService.updateEventStatus(eventId, 'failed');
            print("BG_SERVICE: Event #$eventId marked as failed due to verification failure.");
          }
        } else {
          await _dbService.updateEventStatus(eventId, 'failed');
          print("BG_SERVICE: Event #$eventId failed to be added to calendar.");
        }

      } catch (e) {
        print("BG_SERVICE: FATAL_ERROR processing event #$eventId: $e");
        await _dbService.updateEventStatus(eventId, 'failed');
      }
    }
    print("BG_SERVICE: Finished processing all events.");
  }
}
