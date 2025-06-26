import 'dart:async';
import 'package:flutter/material.dart';
import 'package:message_cal/layout/main_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(
      const Duration(seconds: 2),
      () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (BuildContext context) => const MainLayout(),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 화면 가로 사이즈의 2/3 계산
    final screenWidth = MediaQuery.of(context).size.width;
    final imageSize = screenWidth * 2 / 3;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // stoc.png 이미지 (화면 가로 2/3 사이즈)
            Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'public/stoc.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // 이미지 로딩 실패 시 기본 아이콘 표시
                    return Container(
                      color: Colors.blue,
                      child: Icon(
                        Icons.message,
                        size: imageSize * 0.5, // 이미지 크기에 비례한 아이콘 크기
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'S2C',
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '메시지를 캘린더로',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
