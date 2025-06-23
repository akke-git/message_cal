import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:message_cal/screens/share_receiver_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late StreamSubscription _intentDataStreamSubscription;
  String _sharedText = '';

  @override
  void initState() {
    super.initState();

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
  }

  void _navigateToShareReceiver(String sharedText) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShareReceiverScreen(initialText: sharedText),
      ),
    );
  }

  @override
  void dispose() {
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
