import 'package:flutter/material.dart';
import 'package:llm_chat/storage_helper.dart';

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
  String _chatTitle = 'AI Assistant';
  late String _conversationId;


  late ChatScreenArguments _args;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ 正确位置：在上下文依赖关系建立后获取参数
    _args = ModalRoute.of(context)!.settings.arguments as ChatScreenArguments;
    _conversationId = _args.conversationId;
    _loadMessages();
  }

  @override
  void initState() {
    super.initState();
    // final args = ModalRoute.of(context)!.settings.arguments as ChatScreenArguments;
    // _conversationId = args.conversationId;
    // _loadMessages();
  }

  Future<void> _loadMessages() async {
    final messages = await StorageHelper.loadMessages(_conversationId);
    setState(() => _messages = messages.reversed.toList());
  }

  // @override
  // void initState() {
  //   super.initState();
  //   // Add some initial messages for demo purposes
  //   Future.delayed(Duration.zero, () {
  //     final args = ModalRoute.of(context)!.settings.arguments as ChatScreenArguments?;
  //     if (args != null) {
  //       setState(() {
  //         _chatTitle = args.title;
  //       });
  //
  //       // Add initial messages based on the conversation topic
  //       if (args.title == "Project Planning") {
  //         _messages.add(ChatMessage(
  //           text: "Hi, I'd like to discuss our project timeline.",
  //           isUser: true,
  //         ));
  //         _messages.add(ChatMessage(
  //           text: "Of course! What aspects of the timeline would you like to focus on?",
  //           isUser: false,
  //         ));
  //         _messages.add(ChatMessage(
  //           text: "Let's discuss the timeline for the next sprint",
  //           isUser: true,
  //         ));
  //       } else if (args.title == "Code Review Help") {
  //         _messages.add(ChatMessage(
  //           text: "I'm having trouble understanding this algorithm.",
  //           isUser: true,
  //         ));
  //         _messages.add(ChatMessage(
  //           text: "I'd be happy to help. Which part is confusing you?",
  //           isUser: false,
  //         ));
  //         _messages.add(ChatMessage(
  //           text: "Can you explain how this algorithm works?",
  //           isUser: true,
  //         ));
  //       } else if (args.title == "Learning Flutter") {
  //         _messages.add(ChatMessage(
  //           text: "I'm new to Flutter and need some guidance.",
  //           isUser: true,
  //         ));
  //         _messages.add(ChatMessage(
  //           text: "Flutter is a great framework! What would you like to know?",
  //           isUser: false,
  //         ));
  //         _messages.add(ChatMessage(
  //           text: "What are the best practices for state management?",
  //           isUser: true,
  //         ));
  //       }
  //     }
  //   });
  // }

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
      ),
      body: Column(
        children: [
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
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
            ),
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
                onPressed: _isComposing
                    ? () => _handleSubmitted(_textController.text)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 发送消息（动态更新标题）
  void _handleSubmitted(String text) async {
    print('_handleSubmitted is called');
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
    // 模拟AI回复
    Future.delayed(Duration(milliseconds: 800), () {
      final aiMsg = ChatMessage(text: generateAIResponse(text), isUser: false);
      setState(() {
        _messages.insert(0, aiMsg);
      });
      _updateLastMessage(aiMsg.text);
      _saveMessages();
    });

    await _saveMessages();
  }

  void _simulateAIResponse(String userMessage) {
    String aiResponse = generateAIResponse(userMessage);
    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          text: aiResponse,
          isUser: false,
        ),
      );
    });
  }

  String generateAIResponse(String userMessage) {
    // This is a very simple response generator
    // In a real app, you would connect to an AI API
    if (userMessage.toLowerCase().contains('hello') ||
        userMessage.toLowerCase().contains('hi')) {
      return 'Hello! How can I assist you today?';
    } else if (userMessage.toLowerCase().contains('how are you')) {
      return 'I\'m just a program, but I\'m functioning well! How can I help you?';
    } else if (userMessage.toLowerCase().contains('thank')) {
      return 'You\'re welcome! Is there anything else you\'d like to know?';
    } else if (userMessage.contains('?')) {
      return 'That\'s an interesting question. In a full implementation, I would connect to an AI service to provide a detailed answer.';
    } else {
      return 'I understand you said: "$userMessage". How can I help you with that?';
    }
  }

// 更新对话标题[9,11](@ref)
void _updateConversationTitle(String firstMessage) {
  final newTitle = firstMessage.length > 20
      ? '${firstMessage.substring(0, 20)}...'
      : firstMessage;
  final updated = ConversationItem(
    id: _conversationId,
    title: newTitle,
    lastMessage: firstMessage,
    timestamp: DateTime.now().toString(),
  );
  _updateConversationList(updated);
}

// 更新最后消息
void _updateLastMessage(String message) {
  final updated = ConversationItem(
    id: _conversationId,
    title: _messages.isNotEmpty ? _messages.last.text : '',
    lastMessage: message,
    timestamp: DateTime.now().toString(),
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
    await StorageHelper.saveMessages(_conversationId, _messages.reversed.toList());
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
  //final DateTime timestamp; // 示例字段

  ChatMessage({
    required this.text,
    required this.isUser,
    //this.timestamp = DateTime.now(),
  });

  // 手动实现 toJson
  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    //'timestamp': timestamp.toIso8601String(), // 处理 DateTime 类型[5](@ref)
  };

  // 手动实现 fromJson
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] as String,
    isUser: json['isUser'] as bool,
    //timestamp: DateTime.parse(json['timestamp'] as String),
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 5.0),
                  padding: EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(text),
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