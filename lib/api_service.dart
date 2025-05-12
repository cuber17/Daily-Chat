import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AIService {
  // Zhipu AI API配置
  static const String zhipuApiUrl = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  static const String zhipuApiKey = 'bc0f1f6ae22541558c5df849d128aaaf.RRJMNWUlzYbUEBFO';

  // DeepSeek API配置
  static const String deepseekApiUrl = 'https://api.deepseek.com/chat/completions';
  static const String deepseekApiKey = 'sk-b3493c79407d48c58455eaef4a4f6673';

  // 映射DeepSeek模型名称
  static String _mapDeepSeekModel(String model) {
    switch (model) {
      case 'deepseek-r1':
        return 'deepseek-reasoner'; // 实际DeepSeek API中的模型名称
      case 'deepseek-v3':
        return 'deepseek-chat'; // 实际DeepSeek API中的模型名称
      default:
        return model;
    }
  }

  // ========== Zhipu AI 实现 ==========

  // Zhipu AI 流式响应
  static Stream<String> generateZhipuResponseStream(List<Map<String, String>> messages, [String model = 'glm-4-plus']) async* {
    try {
      final request = http.Request('POST', Uri.parse(zhipuApiUrl));

      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $zhipuApiKey',
      });

      request.body = jsonEncode({
        'model': model,
        'messages': messages,
        'stream': true,
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

  // ========== DeepSeek API 实现 ==========

  // DeepSeek 流式响应
  static Stream<String> generateDeepSeekResponseStream(List<Map<String, String>> messages, [String model = 'deepseek-chat']) async* {
    try {
      final request = http.Request('POST', Uri.parse(deepseekApiUrl));

      // DeepSeek API 使用Bearer Token认证
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $deepseekApiKey',
      });

      // 转换为DeepSeek API模型名称
      final actualModel = _mapDeepSeekModel(model);

      request.body = jsonEncode({
        'model': actualModel,
        'messages': messages,
        'stream': true,
      });

      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        await for (var chunk in response.stream.transform(utf8.decoder)) {
          // 处理DeepSeek SSE格式数据
          for (var line in chunk.split('\n')) {
            if (line.startsWith('data: ')) {
              var data = line.substring(6);
              if (data.trim() == '[DONE]') continue;

              try {
                var jsonData = jsonDecode(data);
                // DeepSeek API 返回格式可能与智谱API不同，根据文档调整
                var content = jsonData['choices'][0]['delta']['content'];
                if (content != null) {
                  yield content;
                }
              } catch (e) {
                // print('Error parsing DeepSeek JSON: $e');
              }
            }
          }
        }
      } else {
        yield 'DeepSeek API Error: ${response.statusCode}';
      }
    } catch (e) {
      yield 'DeepSeek connection error: $e}';
    }
  }
}