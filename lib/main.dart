import 'package:flutter/material.dart';
import 'package:message_cal/screens/splash_screen.dart';
import 'package:message_cal/screens/share_receiver_screen.dart';
import 'package:message_cal/services/background_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 백그라운드에서 공유된 텍스트를 처리하기 위한 글로벌 인스턴스
late final BackgroundService backgroundService;

void main() async {
  // Flutter 엔진과 위젯 바인딩이 초기화되었는지 확인
  WidgetsFlutterBinding.ensureInitialized();
  
  // 환경변수 로드
  await dotenv.load(fileName: ".env");
  
  // 환경변수에서 API 키 가져오기
  final apiKey = dotenv.env['GOOGLE_GENERATIVE_AI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    throw Exception('GOOGLE_GENERATIVE_AI_API_KEY가 .env 파일에 설정되지 않았습니다.');
  }
  
  // BackgroundService 초기화
  backgroundService = BackgroundService(apiKey: apiKey);

  // 백그라운드 이벤트 처리 시작
  backgroundService.processPendingEvents();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MessageCal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'AppleSDGothicNeo',
      ),
      // 라우팅 설정
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/share': (context) => const ShareReceiverScreen(),
      },
    );
  }
}
