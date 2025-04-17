import 'package:flutter/material.dart';
import 'package:llm_chat/storage_helper.dart';
import 'dialog.dart';

// 历史界面（改为StatefulWidget）
class ConversationHistoryScreen extends StatefulWidget {
  @override
  _ConversationHistoryScreenState createState() => _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState extends State<ConversationHistoryScreen> {
  List<ConversationItem> _conversations = [];



  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final list = await StorageHelper.loadConversations();
    setState(() => _conversations = list);
  }

  // 创建新对话
  void _createNewConversation() async {
    final newConversation = ConversationItem(
      id: DateTime.now().toIso8601String(),
      title: 'New Conversation',
      lastMessage: '',
      timestamp: DateTime.now().toString(),
    );
    _conversations.insert(0, newConversation);
    await StorageHelper.saveConversations(_conversations);
    Navigator.pushNamed(context, '/chat', arguments: ChatScreenArguments(
      conversationId: newConversation.id,
      title: newConversation.title,
    )).then((_) => _loadConversations());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Conversation History')),
      body: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) => ConversationListItem(
          conversation: _conversations[index],
          onTap: () => Navigator.pushNamed(
            context,
            '/chat',
            arguments: ChatScreenArguments(
              conversationId: _conversations[index].id,
              title: _conversations[index].title,
            ),
          ).then((_) => _loadConversations()),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewConversation,
        child: Icon(Icons.add),
      ),
    );
  }
}

// 对话项数据模型（新增ID字段）
class ConversationItem {
  final String id;
  final String title;
  final String lastMessage;
  final String timestamp;

  ConversationItem({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.timestamp,
  });

  // 序列化方法
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'lastMessage': lastMessage,
    'timestamp': timestamp,
  };

  factory ConversationItem.fromJson(Map<String, dynamic> json) => ConversationItem(
    id: json['id'],
    title: json['title'],
    lastMessage: json['lastMessage'],
    timestamp: json['timestamp'],
  );
}

class ConversationListItem extends StatelessWidget {
  final ConversationItem conversation;
  final VoidCallback onTap;

  ConversationListItem({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        conversation.title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16.0,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conversation.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 4.0),
          Text(
            conversation.timestamp,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12.0,
            ),
          ),
        ],
      ),
      leading: CircleAvatar(
        backgroundColor: Colors.blue,
        child: Text('AI', style: TextStyle(color: Colors.white)),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      onTap: onTap,
    );
  }
}