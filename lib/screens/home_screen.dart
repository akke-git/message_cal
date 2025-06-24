import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:message_cal/screens/share_receiver_screen.dart';
import 'package:message_cal/services/auth_service.dart';
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
  bool _isSignedIn = false;

  Future<void> _checkSignInStatus() async {
    try {
      final isSignedIn = await _authService.isSignedIn();
      setState(() {
        _isSignedIn = isSignedIn;
      });
    } catch (e) {
      print('Error checking sign-in status: $e');
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
      _intentDataStreamSubscription =
          ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
        final textFiles = value.where((file) => file.type == SharedMediaType.text).toList();
        if (textFiles.isNotEmpty) {
          final sharedText = textFiles.first.path; // For text sharing, path contains the actual text
          setState(() {
            _sharedText = sharedText;
          });
          _navigateToShareReceiver(sharedText);
        }
      }, onError: (err) {
        debugPrint("getMediaStream error: $err");
      });

      // 앱이 종료된 상태에서 공유를 통해 실행되었을 때 데이터를 수신
      ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          final textFiles = value.where((file) => file.type == SharedMediaType.text).toList();
          if (textFiles.isNotEmpty) {
            final sharedText = textFiles.first.path; // For text sharing, path contains the actual text
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
      _intentDataStreamSubscription = Stream<List<SharedMediaFile>>.empty().listen((_) {});
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
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Login Status Card
              Card(
                margin: const EdgeInsets.only(bottom: 30),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        _isSignedIn ? Icons.check_circle : Icons.warning,
                        color: _isSignedIn ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSignedIn ? 'Google 계정 연결됨' : 'Google 계정 연결 필요',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isSignedIn ? Colors.green : Colors.orange,
                              ),
                            ),
                            Text(
                              _isSignedIn 
                                  ? '캘린더 동기화가 활성화되었습니다'
                                  : '설정에서 Google 계정에 로그인하세요',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      if (!_isSignedIn)
                        TextButton(
                          onPressed: widget.onNavigateToSettings,
                          child: const Text('설정'),
                        ),
                    ],
                  ),
                ),
              ),
              
              const Icon(
                Icons.share,
                size: 60,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              const Text(
                '메신저에서 공유하여 일정을 추가하세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              const Text(
                '메시지를 선택하고 공유 버튼을 눌러\nMessageCal을 선택하세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              if (_sharedText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 30.0),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '최근 수신된 메시지:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _sharedText,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
