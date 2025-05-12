import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:llm_chat/storage_helper.dart';
import 'package:llm_chat/api_service.dart'; // Import the new API service

import 'dialog.dart' as _textController;
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

    // 显示加载状态
    setState(() {
      _messages.insert(0, ChatMessage(text: "思考中", isUser: false));
    });

    // 从API获取流式回复
    try {
      final apiMessages = _buildApiMessages();
      Stream<String> responseStream;

      // 根据选择的模型决定使用哪个API
      if (_isDeepSeekModel(_selectedModel)) {
        // 使用DeepSeek API
        responseStream = AIService.generateDeepSeekResponseStream(apiMessages, _selectedModel);
      } else {
        // 使用Zhipu AI API
        responseStream = AIService.generateZhipuResponseStream(apiMessages, _selectedModel);
      }

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

  // 构建API需要的消息格式
  List<Map<String, String>> _buildApiMessages() {
    // 对消息历史进行反转，因为当前显示顺序是最新的在最前面
    final historyMessages = _messages.reversed.toList();

    // 转换为API格式
    return historyMessages
        .map(
          (msg) => {
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text,
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

  ChatMessage({
    required this.text,
    required this.isUser,
  });

  // 手动实现 toJson
  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
  };

  // 手动实现 fromJson
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] as String,
    isUser: json['isUser'] as bool,
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