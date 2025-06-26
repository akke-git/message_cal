
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class LlmService {
  final String? apiKey;

  LlmService({this.apiKey});

  Future<Map<String, dynamic>> extractEventDetails(String text) async {
    print('LLM_SERVICE: Starting extractEventDetails...');
    print('LLM_SERVICE: Input text: $text');
    
    if (apiKey == null) {
      print('LLM_SERVICE: ERROR - API key is null');
      throw Exception('API key is not provided.');
    }
    
    print('LLM_SERVICE: API key is set, length: ${apiKey!.length}');

    final model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: apiKey!,
    );
    
    print('LLM_SERVICE: GenerativeModel created successfully');

    final now = DateTime.now();
    final currentDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final prompt = '''
    다음 텍스트에서 일정 정보를 추출하여 JSON 형식으로 반환해줘.
    
    현재 날짜: $currentDate (${now.year}년 ${now.month}월 ${now.day}일)
    
    - title: 일정 제목 (필수)
    - date: 날짜 (YYYY-MM-DD 형식, 예: ${now.year}-07-28). 날짜 정보가 없으면 현재 날짜 ($currentDate)를 사용해줘. 반드시 ${now.year}년도를 사용해야 함.
    - time: 시간 (HH:mm 형식, 24시간 기준, 예: 14:30). 시간 정보가 없으면 null로 설정해줘.
    - category: 다음 카테고리 중 하나로 분류해줘: [예약, 점심, 골프, 결제, 기념일, 회사, 기타]. 가장 관련성 높은 카테고리를 선택하고, 애매하면 '기타'로 분류해줘.
    - description: 원본 메시지
    
    주의사항: 모든 날짜는 반드시 ${now.year}년도를 사용해야 합니다.
    
    텍스트:
    "$text"
    
    JSON 출력:
    ''';

    try {
      print('LLM_SERVICE: Calling Gemini API...');
      final response = await model.generateContent([Content.text(prompt)]);
      print('LLM_SERVICE: API call completed');
      print('LLM_SERVICE: Raw response: ${response.text}');
      
      final jsonString = response.text
          ?.replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      
      print('LLM_SERVICE: Cleaned JSON string: $jsonString');
      
      if (jsonString != null && jsonString.isNotEmpty) {
        final decodedJson = jsonDecode(jsonString);
        decodedJson['description'] = text; // 원본 메시지 추가
        print('LLM_SERVICE: Successfully parsed JSON: $decodedJson');
        return decodedJson;
      } else {
        print('LLM_SERVICE: Empty response, using fallback');
        return _fallbackParse(text);
      }
    } catch (e) {
      print('LLM_SERVICE: ERROR calling Gemini API: $e');
      print('LLM_SERVICE: Error type: ${e.runtimeType}');
      // API 호출 실패 시 기존 로직으로 대체
      return _fallbackParse(text);
    }
  }

  // Gemini API 호출 실패 시 사용할 대체 로직
  Map<String, dynamic> _fallbackParse(String text) {
    print('LLM_SERVICE: Using fallback parse for text: $text');
    final now = DateTime.now();
    final currentDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final result = {
      'title': text.split('\n').first.trim(),
      'date': currentDate,
      'time': null,
      'category': '기타',
      'description': text,
    };
    print('LLM_SERVICE: Fallback result: $result');
    return result;
  }
}
