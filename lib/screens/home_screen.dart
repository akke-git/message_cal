import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:message_cal/screens/share_receiver_screen.dart';
import 'package:message_cal/services/auth_service.dart';
import 'package:message_cal/services/calendar_service.dart';
import 'package:message_cal/services/database_service.dart';
import 'package:message_cal/main.dart' as main_app;
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSettings;

  const HomeScreen({super.key, this.onNavigateToSettings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late StreamSubscription _intentDataStreamSubscription;
  String _sharedText = '';
  final AuthService _authService = AuthService();
  final CalendarService _calendarService = CalendarService();
  bool _isSignedIn = false;
  List<calendar.Event> _upcomingEvents = [];
  bool _isLoadingEvents = false;
  String _userEmail = '';

  // 수동 등록 다이얼로그용 컨트롤러들
  final TextEditingController _manualTextController = TextEditingController();
  final TextEditingController _manualTitleController = TextEditingController();
  DateTime? _manualSelectedDate;
  TimeOfDay? _manualSelectedTime;
  String _manualSelectedCategory = '점심';
  int _manualReminderMinutes = 30;

  Future<void> _checkSignInStatus() async {
    try {
      print('HOME_SCREEN: Checking sign-in status...');
      
      // 먼저 현재 로그인 상태 확인
      bool isSignedIn = await _authService.isSignedIn();
      String userEmail = '';
      
      if (!isSignedIn) {
        print('HOME_SCREEN: Not signed in, attempting silent sign-in...');
        // 로그인되어 있지 않다면 자동 로그인 시도
        final account = await _authService.signInSilently();
        if (account != null) {
          isSignedIn = true;
          userEmail = account.email ?? '';
          print('HOME_SCREEN: Silent sign-in successful: $userEmail');
        } else {
          print('HOME_SCREEN: Silent sign-in failed');
        }
      } else {
        userEmail = await _authService.getUserEmail() ?? '';
        print('HOME_SCREEN: Already signed in: $userEmail');
      }
      
      if (mounted) {
        setState(() {
          _isSignedIn = isSignedIn;
          _userEmail = userEmail;
        });

        if (isSignedIn) {
          _loadUpcomingEvents();
        }
      }
    } catch (e) {
      print('HOME_SCREEN: Error checking sign-in status: $e');
    }
  }

  Future<void> _loadUpcomingEvents() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      final now = DateTime.now();
      // 조회 범위를 더 넓게 설정 (지난 6개월 ~ 앞으로 6개월)
      final startDate = DateTime(now.year, now.month - 6, 1);
      final endDate = DateTime(now.year, now.month + 6, 0);
      
      print('HOME_SCREEN: Fetching events from $startDate to $endDate');
      
      final events = await _calendarService.getEvents(
        startDate: startDate,
        endDate: endDate,
      );

      print('HOME_SCREEN: Found ${events.length} events in calendar');

      // 최근 일자부터 역순으로 정렬하여 최대 10개만 표시
      events.sort((a, b) {
        final aDate = a.start?.dateTime ?? a.start?.date ?? DateTime.now();
        final bDate = b.start?.dateTime ?? b.start?.date ?? DateTime.now();
        return bDate.compareTo(aDate); // 역순 정렬 (최신순)
      });

      if (mounted) {
        setState(() {
          _upcomingEvents = events.take(10).toList(); // 최대 10개만
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      print('Error loading events: $e');
      if (mounted) {
        setState(() {
          _isLoadingEvents = false;
        });
      }
    }
  }

  bool _isMobilePlatform() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSignInStatus();

    // 모바일 플랫폼에서만 공유 인텐트 초기화
    if (_isMobilePlatform()) {
      // 앱이 실행 중일 때 공유 데이터를 수신하는 리스너
      _intentDataStreamSubscription = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen(
            (List<SharedMediaFile> value) {
              final textFiles =
                  value
                      .where((file) => file.type == SharedMediaType.text)
                      .toList();
              if (textFiles.isNotEmpty) {
                final sharedText =
                    textFiles
                        .first
                        .path; // For text sharing, path contains the actual text
                setState(() {
                  _sharedText = sharedText;
                });
                _navigateToShareReceiver(sharedText);
              }
            },
            onError: (err) {
              debugPrint("getMediaStream error: $err");
            },
          );

      // 앱이 종료된 상태에서 공유를 통해 실행되었을 때 데이터를 수신
      ReceiveSharingIntent.instance.getInitialMedia().then((
        List<SharedMediaFile> value,
      ) {
        if (value.isNotEmpty) {
          final textFiles =
              value.where((file) => file.type == SharedMediaType.text).toList();
          if (textFiles.isNotEmpty) {
            final sharedText =
                textFiles
                    .first
                    .path; // For text sharing, path contains the actual text
            setState(() {
              _sharedText = sharedText;
            });
            _navigateToShareReceiver(sharedText);
          }
          ReceiveSharingIntent.instance.reset();
        }
      });
    } else {
      // 비모바일 플랫폼에서는 더미 스트림 구독
      _intentDataStreamSubscription = Stream<List<SharedMediaFile>>.empty()
          .listen((_) {});
    }
  }

  void _navigateToShareReceiver(String sharedText) async {
    // DB에 저장
    await DatabaseService.instance.createPendingEvent(sharedText);
    
    // 사용자에게 피드백 제공
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('일정이 추가되었습니다. 잠시 후 캘린더에 등록됩니다.'),
        backgroundColor: Colors.green,
      ),
    );
    
    // 백그라운드 처리 즉시 트리거
    _processNewPendingEvents();
  }
  
  void _processNewPendingEvents() async {
    try {
      // main.dart의 backgroundService 사용
      await main_app.backgroundService.processPendingEvents();
      // 처리 완료 후 이벤트 새로고침 (mounted 체크)
      if (mounted && _isSignedIn) {
        _loadUpcomingEvents();
      }
    } catch (e) {
      print('백그라운드 처리 오류: $e');
      // 오류 발생 시 사용자에게 알림 (mounted 체크)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정 처리 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showManualAddDialog() {
    // 다이얼로그 열 때마다 폼 초기화
    _manualTextController.clear();
    _manualTitleController.clear();
    _manualSelectedDate = null;
    _manualSelectedTime = null;
    _manualSelectedCategory = '점심';
    _manualReminderMinutes = 30;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  minHeight: 400,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 다이얼로그 헤더
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            '수동 일정 등록',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    // 다이얼로그 내용
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildManualAddForm(setDialogState),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildManualAddForm(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 메시지 입력 (크게)
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '일정 관련 메시지를 입력하세요',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12.0),
              Container(
                height: 300, // 고정 높이 설정
                child: TextField(
                  controller: _manualTextController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '예시:\n- 내일 오후 2시 회의\n- 다음주 월요일 점심약속\n- 12월 25일 크리스마스 파티\n\n입력하신 메시지는 AI가 자동으로 분석하여\n제목, 날짜, 시간, 카테고리를 추출한 후\nGoogle Calendar에 등록됩니다.',
                    alignLabelWithHint: true,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  onChanged: (text) {
                    setDialogState(() {}); // 텍스트 변경 시 버튼 상태 업데이트
                  },
                ),
              ),
            ],
          ),
        ),
        
        // 등록 버튼
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: ElevatedButton.icon(
            onPressed: _manualTextController.text.trim().isEmpty 
                ? null 
                : () => _saveManualToCalendarSimple(setDialogState),
            icon: const Icon(Icons.smart_toy),
            label: const Text('AI 분석 후 캘린더 등록'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSignInStatus();
    }
  }

  Future<void> _selectManualDate(StateSetter setDialogState) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _manualSelectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setDialogState(() {
        _manualSelectedDate = picked;
      });
    }
  }
  
  Future<void> _selectManualTime(StateSetter setDialogState) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _manualSelectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setDialogState(() {
        _manualSelectedTime = picked;
      });
    }
  }

  void _analyzeManualText(String text, StateSetter setDialogState) {
    if (text.isEmpty) return;
    
    final cleanText = text.toLowerCase().trim();
    
    // 제목 추출
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isNotEmpty) {
      String title = lines.first.trim();
      title = title.replaceAll(RegExp(r'^(안녕하세요|안녕|헤이|하이|[!@#$%^&*()])+'), '').trim();
      _manualTitleController.text = title.isNotEmpty ? title : '일정';
    }
    
    // 날짜 분석
    final now = DateTime.now();
    if (cleanText.contains('내일') || cleanText.contains('tomorrow')) {
      _manualSelectedDate = now.add(const Duration(days: 1));
    } else if (cleanText.contains('모레')) {
      _manualSelectedDate = now.add(const Duration(days: 2));
    } else if (cleanText.contains('오늘') || cleanText.contains('today')) {
      _manualSelectedDate = now;
    }
    
    // 시간 분석
    final timeRegex = RegExp(r'(\d{1,2}):(\d{2})|(\d{1,2})시');
    final timeMatch = timeRegex.firstMatch(cleanText);
    if (timeMatch != null) {
      int hour = 0;
      int minute = 0;
      
      if (timeMatch.group(1) != null && timeMatch.group(2) != null) {
        hour = int.tryParse(timeMatch.group(1)!) ?? 0;
        minute = int.tryParse(timeMatch.group(2)!) ?? 0;
      } else if (timeMatch.group(3) != null) {
        hour = int.tryParse(timeMatch.group(3)!) ?? 0;
      }
      
      _manualSelectedTime = TimeOfDay(hour: hour, minute: minute);
    }
    
    // 카테고리 분석
    if (cleanText.contains('회의') || cleanText.contains('미팅')) {
      _manualSelectedCategory = '회사';
    } else if (cleanText.contains('식사') || cleanText.contains('점심')) {
      _manualSelectedCategory = '점심';
    } else if (cleanText.contains('골프')) {
      _manualSelectedCategory = '골프';
    } else if (cleanText.contains('예약')) {
      _manualSelectedCategory = '예약';
    }
    
    setDialogState(() {});
  }

  Future<void> _saveManualToCalendarSimple(StateSetter setDialogState) async {
    if (!_isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google 계정에 로그인이 필요합니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final sharedText = _manualTextController.text.trim();
    if (sharedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('메시지를 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // 1. 로컬 DB에 저장 (기존 공유 방식과 동일)
      await DatabaseService.instance.createPendingEvent(sharedText);
      
      // 2. 다이얼로그 닫기
      Navigator.of(context).pop();
      
      // 3. 사용자에게 피드백 제공
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('일정이 추가되었습니다. AI가 분석하여 캘린더에 등록중입니다...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
      // 4. 백그라운드 처리 즉시 트리거 (기존 공유 방식과 동일)
      _processNewPendingEvents();
      
      // 5. 폼 초기화
      _manualTextController.clear();
      _manualTitleController.clear();
      _manualSelectedDate = null;
      _manualSelectedTime = null;
      _manualSelectedCategory = '점심';
      _manualReminderMinutes = 30;
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveManualToCalendar(StateSetter setDialogState) async {
    if (!_isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google 계정에 로그인이 필요합니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_manualTitleController.text.isEmpty || _manualSelectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('제목과 날짜를 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final success = await _calendarService.createEvent(
        title: _manualTitleController.text,
        startDate: _manualSelectedDate!,
        startTime: _manualSelectedTime,
        description: _manualTextController.text.isNotEmpty 
            ? '원본 메시지: ${_manualTextController.text}' 
            : '수동 입력으로 생성된 일정',
        category: _manualSelectedCategory,
        reminderMinutes: _manualReminderMinutes,
      );

      if (success) {
        Navigator.of(context).pop(); // 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정이 Google Calendar에 저장되었습니다: ${_manualTitleController.text}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 폼 초기화
        _manualTextController.clear();
        _manualTitleController.clear();
        _manualSelectedDate = null;
        _manualSelectedTime = null;
        _manualSelectedCategory = '점심';
        _manualReminderMinutes = 30;
        
        // 이벤트 새로고침
        if (_isSignedIn) {
          _loadUpcomingEvents();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('일정 저장에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentDataStreamSubscription.cancel();
    _manualTextController.dispose();
    _manualTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: null, // 제목 삭제
        actions: [
          // 로그인 상태와 사용자 이메일 표시
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isSignedIn ? Icons.check_circle : Icons.warning,
                  color: _isSignedIn ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _isSignedIn ? '연결됨' : '미연결',
                      style: TextStyle(
                        color: _isSignedIn ? Colors.green : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isSignedIn && _userEmail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _userEmail,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 배너 이미지
            Container(
              width: double.infinity,
              height: 200,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // 배경 이미지
                    Positioned.fill(
                      child: Image.asset(
                        'public/banner.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                    // svlet 텍스트 우하단
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Text(
                        'svlet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 2,
                              color: Colors.black45,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 이번 달 일정 (캘린더 화면에서 가져온 로직)
            if (_isSignedIn) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recents',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 수동 등록 버튼 (작은 크기)
                      SizedBox(
                        width: 100,
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: _showManualAddDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('수동등록', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 새로고침 버튼
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadUpcomingEvents,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildMonthlyEvents(),
            ] else ...[
              // 로그인 안내 카드
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.account_circle,
                        size: 50,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Google 계정 연결이 필요합니다',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '설정에서 Google 계정에 로그인하면\n일정을 확인할 수 있습니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: widget.onNavigateToSettings,
                        child: const Text('설정으로 이동'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  DateTime _convertToKoreanTime(DateTime utcTime, calendar.Event event) {
    // Google Calendar API가 Asia/Seoul 시간대 이벤트를 UTC로 반환하는 경우
    // 수동으로 9시간을 더해서 한국 시간으로 변환
    if (event.start?.timeZone == 'Asia/Seoul' && utcTime.isUtc) {
      return utcTime.add(const Duration(hours: 9));
    }

    // 이미 로컬 시간인 경우 그대로 반환
    return utcTime.toLocal();
  }

  Widget _buildMonthlyEvents() {
    if (_isLoadingEvents) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_upcomingEvents.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(Icons.event_note, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                '등록된 일정이 없습니다',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                '메신저에서 메시지를 공유하거나\n추가 탭에서 직접 일정을 만들어보세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _upcomingEvents.length,
        separatorBuilder:
            (context, index) => Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade200,
              indent: 16,
              endIndent: 16,
            ),
        itemBuilder: (context, index) {
          final event = _upcomingEvents[index];
          final category = _getEventCategory(event);
          final startTime = event.start?.dateTime ?? event.start?.date;

          return Container(
            color: Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: _getCategoryColor(category),
                child: Icon(
                  _getCategoryIcon(category),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                event.summary ?? '제목 없음',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (startTime != null)
                    Text(
                      '${DateFormat('MM월 dd일').format(_convertToKoreanTime(startTime, event))} ${DateFormat('HH:mm').format(_convertToKoreanTime(startTime, event))}',
                    ),
                  if (event.location != null && event.location!.isNotEmpty)
                    Text(
                      '📍 ${event.location}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                ],
              ),
              trailing: Text(
                category,
                style: TextStyle(
                  color: _getCategoryColor(category),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getEventCategory(calendar.Event event) {
    switch (event.colorId) {
      case '9':
        return '예약';
      case '10':
        return '점심';
      case '11':
        return '골프';
      case '5':
        return '결제';
      case '6':
        return '기념일';
      case '7':
        return '회사';
      default:
        return '기타';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '예약':
        return const Color(0xFF3788D8); // Google Calendar 파란색 (colorId: 9)
      case '점심':
        return const Color(0xFF0B8043); // Google Calendar 초록색 (colorId: 10)
      case '골프':
        return const Color(0xFFD50000); // Google Calendar 빨간색 (colorId: 11)
      case '결제':
        return const Color(0xFFFF6D01); // Google Calendar 주황색 (colorId: 5)
      case '기념일':
        return const Color(0xFFAD1457); // Google Calendar 자주색 (colorId: 6)
      case '회사':
        return const Color(0xFF8E24AA); // Google Calendar 보라색 (colorId: 7)
      default:
        return const Color(0xFF29B6F6); // 연한 하늘색
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '예약':
        return Icons.calendar_today;
      case '점심':
        return Icons.restaurant;
      case '골프':
        return Icons.golf_course;
      case '결제':
        return Icons.payment;
      case '기념일':
        return Icons.celebration;
      case '회사':
        return Icons.business;
      default:
        return Icons.event;
    }
  }
}

