import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:llm_chat/storage_helper.dart';
import 'package:llm_chat/api_service.dart'; // Import the new API service

import 'history.dart';

class ChatScreenArguments {
  final String conversationId; // 新增对话唯一标识
  final String title;

  ChatScreenArguments({
    required this.conversationId, // 必须传入对话ID
    required this.title,
  });
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  List<ChatMessage> _messages = [];
  bool _isComposing = false;
  String _chatTitle = 'AI对话';
  late String _conversationId;

  // 更新模型选择变量，添加DeepSeek模型
  String _selectedModel = 'glm-4-plus'; // 默认模型
  final List<String> _availableModels = [
    'glm-4-plus',
    'glm-4-long',
    'glm-4-flashx',
    'deepseek-r1',
    'deepseek-v3'
  ];

  late ChatScreenArguments _args;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 正确位置：在上下文依赖关系建立后获取参数
    _args = ModalRoute.of(context)!.settings.arguments as ChatScreenArguments;
    _conversationId = _args.conversationId;
    _loadMessages();
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadMessages() async {
    final messages = await StorageHelper.loadMessages(_conversationId);
    setState(() => _messages = messages.reversed.toList());
  }

  // 判断所选模型是否为DeepSeek模型
  bool _isDeepSeekModel(String model) {
    return model.startsWith('deepseek');
  }

  // 判断所选模型是否为DeepSeek Reasoner模型
  bool _isDeepSeekReasonerModel(String model) {
    return model == 'deepseek-r1';
  }

  // 切换思维链显示状态
  void _toggleReasoningVisibility(int messageIndex) {
    setState(() {
      final message = _messages[messageIndex];
      if (message is ChatMessage && message.reasoningContent != null) {
        _messages[messageIndex] = ChatMessage(
          text: message.text,
          isUser: message.isUser,
          reasoningContent: message.reasoningContent,
          showReasoning: !(message.showReasoning),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_chatTitle),
        elevation: 0.0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        // 模型选择下拉框
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              value: _selectedModel,
              icon: const Icon(Icons.settings),
              underline: Container(), // 移除下划线
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedModel = newValue;
                  });
                }
              },
              items: _availableModels
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: TextStyle(fontSize: 14)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 显示当前使用的API提供商
          Container(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            color: Colors.grey[200],
            child: Center(
              child: Text(
                _isDeepSeekModel(_selectedModel) ? 'DeepSeek' : '智谱清言',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(8.0),
              reverse: true, // To display latest messages at the bottom
              itemCount: _messages.length,
              itemBuilder: (_, int index) => _messages[index],
            ),
          ),
          Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).primaryColor),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _textController,
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.isNotEmpty;
                  });
                },
                onSubmitted: _isComposing ? _handleSubmitted : null,
                decoration: InputDecoration.collapsed(
                  hintText: 'Send a message',
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: Icon(Icons.send),
                onPressed:
                _isComposing
                    ? () => _handleSubmitted(_textController.text)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmitted(String text) async {
    if (_messages.isEmpty) {
      _updateConversationTitle(text); // 第一条消息更新标题
    }

    // 添加用户消息
    _messages.insert(0, ChatMessage(text: text, isUser: true));
    _updateLastMessage(text);

    _textController.clear();
    setState(() {
      _isComposing = false;
    });

    // 从API获取流式回复
    try {
      final apiMessages = _buildApiMessages();
      // 显示加载状态
      setState(() {
        _messages.insert(0, ChatMessage(text: "思考中", isUser: false));
      });
      // 根据选择的模型决定使用哪个API
      if (_isDeepSeekModel(_selectedModel)) {
        // 处理DeepSeek模型响应
        await _handleDeepSeekResponse(apiMessages);
      } else {
        // 处理Zhipu AI模型响应
        await _handleZhipuResponse(apiMessages);
      }

      await _saveMessages();
    } catch (e) {
      // 发生错误时处理
      setState(() {
        _messages.removeAt(0);
        _messages.insert(
          0,
          ChatMessage(
            text: "Sorry, I encountered an error. Please try again.",
            isUser: false,
          ),
        );
      });
      // print('Error getting AI response: $e');
    }
  }

  // 处理DeepSeek模型响应
  Future<void> _handleDeepSeekResponse(List<Map<String, String>> apiMessages) async {
    final aiMessageIndex = 0;

    if (_isDeepSeekReasonerModel(_selectedModel)) {
      // DeepSeek Reasoner模型需要特殊处理
      String reasoningContent = '';
      String finalContent = '';

      // 将响应流转换为Map<String, dynamic>
      final responseStream = AIService.generateDeepSeekResponseStream(apiMessages, _selectedModel);

      await for (final chunk in responseStream) {
        // 解析响应数据
        if (chunk is Map<String, dynamic>) {
          final String type = chunk['type'] as String;
          final String content = chunk['content'] as String;

          setState(() {
            _messages.removeAt(aiMessageIndex);

            if (type == 'reasoning') {
              // 累积思维链内容
              reasoningContent += content;
              _messages.insert(
                aiMessageIndex,
                ChatMessage(
                  text: "思考中...",
                  isUser: false,
                  reasoningContent: reasoningContent,
                  showReasoning: true,
                ),
              );
            } else if (type == 'final') {
              // 累积最终回答
              finalContent += content;
              _messages.insert(
                aiMessageIndex,
                ChatMessage(
                  text: finalContent,
                  isUser: false,
                  reasoningContent: reasoningContent,
                  showReasoning: true,
                ),
              );
            } else {
              // 处理其他类型响应(如错误)
              _messages.insert(
                aiMessageIndex,
                ChatMessage(
                  text: content,
                  isUser: false,
                ),
              );
            }
          });

          // 添加小延迟，避免UI更新过于频繁
          await Future.delayed(Duration(milliseconds: 50));
        }
      }

      // 只保存最终回答到对话历史
      if (finalContent.isNotEmpty) {
        _updateLastMessage(finalContent);
      }
    } else {
      // 常规DeepSeek模型
      String currentResponse = '';

      // 常规DeepSeek模型响应流仍然是String
      final responseStream = AIService.generateDeepSeekResponseStream(apiMessages, _selectedModel);

      await for (final chunk in responseStream) {
        if (chunk is Map<String, dynamic> && chunk['type'] == 'regular') {
          final content = chunk['content'] as String;

          setState(() {
            _messages.removeAt(aiMessageIndex);
            currentResponse += content;
            _messages.insert(
              aiMessageIndex,
              ChatMessage(
                text: currentResponse,
                isUser: false,
              ),
            );
          });

          // 添加小延迟，避免UI更新过于频繁
          await Future.delayed(Duration(milliseconds: 50));
        }
      }

      _updateLastMessage(currentResponse);
    }
  }

  // 处理ZhipuAI模型响应
  Future<void> _handleZhipuResponse(List<Map<String, String>> apiMessages) async {
    final responseStream = AIService.generateZhipuResponseStream(apiMessages, _selectedModel);

    // 创建一个新的消息条目，用于显示流式回复
    final aiMessageIndex = 0;
    String currentResponse = '';

    await for (final String chunk in responseStream) {
      // 移除加载消息并逐步显示流式回复
      setState(() {
        _messages.removeAt(aiMessageIndex);
        currentResponse += chunk;
        _messages.insert(aiMessageIndex, ChatMessage(text: currentResponse, isUser: false));
      });

      // 添加小延迟，避免 UI 更新过于频繁
      await Future.delayed(Duration(milliseconds: 50));
    }

    _updateLastMessage(currentResponse);
  }

  // 构建API需要的消息格式
  List<Map<String, String>> _buildApiMessages() {
    // 对消息历史进行反转，因为当前显示顺序是最新的在最前面
    final historyMessages = _messages.reversed.toList();

    // 转换为API格式，排除思维链内容
    return historyMessages
        .map(
          (msg) => {
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text, // 只包含最终回答内容，不包含思维链
      },
    )
        .toList();
  }

  // 更新对话标题
  void _updateConversationTitle(String firstMessage) {
    final newTitle =
    firstMessage.length > 20
        ? '${firstMessage.substring(0, 20)}...'
        : firstMessage;
    final updated = ConversationItem(
      id: _conversationId,
      title: newTitle,
      lastMessage: firstMessage,
      timestamp: DateTime.now().toString().split('.')[0],
    );
    _updateConversationList(updated);
  }

  // 更新最后消息
  void _updateLastMessage(String message) {
    final updated = ConversationItem(
      id: _conversationId,
      title: _messages.isNotEmpty ? _messages.last.text : '',
      lastMessage: message,
      timestamp: DateTime.now().toString().split('.')[0],
    );
    _updateConversationList(updated);
  }

  Future<void> _updateConversationList(ConversationItem item) async {
    final list = await StorageHelper.loadConversations();
    final index = list.indexWhere((c) => c.id == item.id);
    if (index != -1) list[index] = item;
    await StorageHelper.saveConversations(list);
  }

  Future<void> _saveMessages() async {
    await StorageHelper.saveMessages(
      _conversationId,
      _messages.reversed.toList(),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final String? reasoningContent; // 新增思维链内容字段
  final bool showReasoning; // 是否显示思维链内容

  ChatMessage({
    required this.text,
    required this.isUser,
    this.reasoningContent,
    this.showReasoning = false,
  });

  // 手动实现 toJson - 只保存必要内容，不包含UI状态
  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'reasoningContent': reasoningContent,
  };

  // 手动实现 fromJson
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] as String,
    isUser: json['isUser'] as bool,
    reasoningContent: json['reasoningContent'] as String?,
    showReasoning: true, // 默认显示思维链
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          !isUser
              ? Container(
            margin: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text('AI', style: TextStyle(color: Colors.white)),
            ),
          )
              : Container(),
          Expanded(
            child: Column(
              crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? 'You' : 'AI Assistant',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                // 主要内容
                Container(
                  margin: EdgeInsets.only(top: 5.0),
                  padding: EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: MarkdownBody(
                    data: text,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                  ),
                ),
                // 思维链内容（如果有且显示状态为true）
                if (reasoningContent != null && reasoningContent!.isNotEmpty && showReasoning)
                  Container(
                    margin: EdgeInsets.only(top: 8.0),
                    padding: EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.psychology, size: 16, color: Colors.amber[700]),
                            SizedBox(width: 4),
                            Text(
                              '思维链',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.amber[900],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        MarkdownBody(
                          data: reasoningContent!,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                        ),
                      ],
                    ),
                  ),
                // 当有思维链但未显示时，添加一个展开/收起按钮
                if (reasoningContent != null && reasoningContent!.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      // 查找当前消息在列表中的索引
                      final chatScreen = context.findAncestorStateOfType<_ChatScreenState>();
                      if (chatScreen != null) {
                        final index = chatScreen._messages.indexOf(this);
                        if (index != -1) {
                          chatScreen._toggleReasoningVisibility(index);
                        }
                      }
                    },
                    icon: Icon(
                      showReasoning ? Icons.visibility_off : Icons.visibility,
                      size: 16,
                    ),
                    label: Text(
                      showReasoning ? '隐藏思维链' : '显示思维链',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size(0, 0),
                    ),
                  ),
              ],
            ),
          ),
          isUser
              ? Container(
            margin: EdgeInsets.only(left: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.blue[300],
              child: Text('You', style: TextStyle(color: Colors.white)),
            ),
          )
              : Container(),
        ],
      ),
    );
  }
}