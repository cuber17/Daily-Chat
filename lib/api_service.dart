import 'dart:convert';
import 'dart:io';
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

  static Stream<String> generateResponseStream(List<Map<String, String>> messages) async* {
    try {
      final request = http.Request('POST', Uri.parse(apiUrl));

      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });

      request.body = jsonEncode({
        'model': 'glm-4-plus',
        'messages': messages,
        'stream': true, // 启用流式传输
      });

      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        await for (var chunk in response.stream.transform(utf8.decoder)) {
          // 处理SSE格式数据
          for (var line in chunk.split('\n')) {
            if (line.startsWith('data: ')) {
              var data = line.substring(6);
              if (data.trim() == '[DONE]') continue;

              try {
                var jsonData = jsonDecode(data);
                var content = jsonData['choices'][0]['delta']['content'];
                if (content != null) {
                  yield content;
                }
              } catch (e) {
                // print('Error parsing JSON: $e');
              }
            }
          }
        }
      } else {
        yield 'Error: ${response.statusCode}';
      }
    } catch (e) {
      yield 'Connection error: $e';
    }
  }
}