import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:message_cal/screens/share_receiver_screen.dart';
import 'package:message_cal/services/auth_service.dart';
import 'package:message_cal/services/calendar_service.dart';
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

  Future<void> _checkSignInStatus() async {
    try {
      final isSignedIn = await _authService.isSignedIn();
      setState(() {
        _isSignedIn = isSignedIn;
      });

      if (isSignedIn) {
        _loadUpcomingEvents();
      }
    } catch (e) {
      print('Error checking sign-in status: $e');
    }
  }

  Future<void> _loadUpcomingEvents() async {
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      final now = DateTime.now();
      final events = await _calendarService.getEvents(
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
      );

      setState(() {
        _upcomingEvents = events;
        _isLoadingEvents = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        _isLoadingEvents = false;
      });
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

  void _navigateToShareReceiver(String sharedText) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShareReceiverScreen(initialText: sharedText),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSignInStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MessageCal'),
        actions: [
          // 간단한 로그인 상태 표시
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
                const SizedBox(width: 4),
                Text(
                  _isSignedIn ? '연결됨' : '미연결',
                  style: TextStyle(
                    color: _isSignedIn ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
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
                gradient: LinearGradient(
                  colors: [Colors.blue[400]!, Colors.blue[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 배경 패턴
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: CustomPaint(painter: _BannerPatternPainter()),
                    ),
                  ),
                  // 텍스트 내용
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Colors.white,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'MessageCal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '메시지를 공유하면\n자동으로 일정이 생성됩니다',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.share, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                '공유하기',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadUpcomingEvents,
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

// 배너용 패턴 페인터
class _BannerPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.1)
          ..strokeWidth = 1;

    // 격자 패턴 그리기
    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
