import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AIService {
  // Zhipu AI API配置
  static const String zhipuApiUrl = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  static String zhipuApiKey = dotenv.env['ZHIPU_APIKEY']??'0';

  // DeepSeek API配置
  static const String deepseekApiUrl = 'https://api.deepseek.com/chat/completions';
  static String deepseekApiKey = dotenv.env['DEEPSEEK_APIKEY']??'0';

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
        yield 'Error: ${response}';
      }
    } catch (e) {
      yield 'Connection error: $e';
    }
  }

  // ========== DeepSeek API 实现 ==========

  // DeepSeek 流式响应（带有响应类型标识）
  static Stream<Map<String, dynamic>> generateDeepSeekResponseStream(
      List<Map<String, String>> messages, [String model = 'deepseek-chat']) async* {
    try {
      final request = http.Request('POST', Uri.parse(deepseekApiUrl));

      // DeepSeek API 使用Bearer Token认证
      request.headers.addAll({
        'Content-Type': 'application/json',
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
        String reasoningContent = '';
        String finalContent = '';

        await for (var chunk in response.stream.transform(utf8.decoder)) {
          // 处理DeepSeek SSE格式数据
          for (var line in chunk.split('\n')) {
            if (line.startsWith('data: ')) {
              var data = line.substring(6);
              if (data.trim() == '[DONE]') continue;

              try {
                var jsonData = jsonDecode(data);

                // 处理DeepSeek Reasoner模型的特殊结构
                if (model == 'deepseek-r1') {
                  // 检查是否有思维链内容
                  if (jsonData['choices'][0]['delta']['reasoning_content'] != null) {
                    reasoningContent += jsonData['choices'][0]['delta']['reasoning_content'];
                    yield {
                      'type': 'reasoning',
                      'content': jsonData['choices'][0]['delta']['reasoning_content']
                    };
                  }

                  // 检查是否有最终答案内容
                  if (jsonData['choices'][0]['delta']['content'] != null) {
                    finalContent += jsonData['choices'][0]['delta']['content'];
                    yield {
                      'type': 'final',
                      'content': jsonData['choices'][0]['delta']['content']
                    };
                  }
                } else {
                  // 常规DeepSeek模型处理
                  var content = jsonData['choices'][0]['delta']['content'];
                  if (content != null) {
                    yield {
                      'type': 'regular',
                      'content': content
                    };
                  }
                }
              } catch (e) {
                // print('Error parsing DeepSeek JSON: $e');
              }
            }
          }
        }
      } else {
        final errorBody = await response.stream.bytesToString();
        yield {
          'type': 'error',
          'content': 'DeepSeek API Error (${response.statusCode}): $errorBody'
        };
      }
    } catch (e) {
      yield {
        'type': 'error',
        'content': 'DeepSeek connection error: $e}'
      };
    }
  }
}