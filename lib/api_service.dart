import 'dart:convert';
import 'package:http/http.dart' as http;

class ZhipuAIService {
  static const String apiUrl = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  static const String apiKey = 'bc0f1f6ae22541558c5df849d128aaaf.RRJMNWUlzYbUEBFO';

  // Convert our ChatMessage to the API's message format
  static Map<String, String> _formatMessage(String content, bool isUser) {
    return {
      'role': isUser ? 'user' : 'assistant',
      'content': content,
    };
  }

  // Call the Zhipu AI API
  static Future<String> generateResponse(List<Map<String, String>> messages) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'glm-4-plus',
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return content;
      } else {
        // Handle error response
        // print('API Error: ${response.statusCode} - ${response.body}');
        return 'Sorry, I encountered an error. Please try again later. (Error: ${response.statusCode})';
      }
    } catch (e) {
      // Handle exceptions
      // print('Exception when calling API: $e');
      return 'Sorry, I encountered a connection error. Please check your internet connection and try again.';
    }
  }
}