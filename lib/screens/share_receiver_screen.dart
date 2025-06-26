import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:message_cal/services/database_service.dart';
import 'dart:io'; // for exit()

class ShareReceiverScreen extends StatefulWidget {
  const ShareReceiverScreen({super.key});

  @override
  State<ShareReceiverScreen> createState() => _ShareReceiverScreenState();
}

class _ShareReceiverScreenState extends State<ShareReceiverScreen> {
  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _handleInitialAndStreamIntents();
  }

  void _handleInitialAndStreamIntents() {
    // 앱이 실행 중일 때 공유 인텐트를 처리
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      _handleSharedText(value);
    }, onError: (err) {
      debugPrint("getMediaStream error: $err");
    });

    // 앱이 종료된 상태에서 공유 인텐트로 시작될 때 처리
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      _handleSharedText(value, isInitial: true);
    });
  }

  Future<void> _handleSharedText(List<SharedMediaFile> sharedFiles, {bool isInitial = false}) async {
    final textFiles = sharedFiles.where((file) => file.type == SharedMediaType.text).toList();

    if (textFiles.isNotEmpty) {
      final sharedText = textFiles.first.path;
      await DatabaseService.instance.createPendingEvent(sharedText);
      
      // 사용자에게 빠른 피드백 제공
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('일정이 추가되었습니다. 잠시 후 캘린더에 등록됩니다.'),
          backgroundColor: Colors.green,
        ),
      );

      // 잠시 후 앱 종료
      if (isInitial) {
        Future.delayed(const Duration(seconds: 1), () {
          exit(0);
        });
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 이제 이 화면은 사용자에게 직접 보이지 않으므로 간단한 로딩 인디케이터만 표시합니다.
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('메시지를 처리 중입니다...'),
          ],
        ),
      ),
    );
  }
}