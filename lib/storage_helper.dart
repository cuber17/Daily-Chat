import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'dialog.dart';
import 'history.dart';

class StorageHelper {
  static const _conversationsKey = 'conversations';
  static const _messagesKey = 'messages';

  // 保存对话列表
  static Future<void> saveConversations(List<ConversationItem> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedList = list.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_conversationsKey, encodedList);
  }

  // 加载对话列表
  static Future<List<ConversationItem>> loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_conversationsKey) ?? [];
    return list.map((str) => ConversationItem.fromJson(jsonDecode(str))).toList();
  }

  // 保存消息列表（按对话ID分组）
  static Future<void> saveMessages(String conversationId, List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_messagesKey-$conversationId';
    final encodedList = messages.map((msg) => jsonEncode(msg.toJson())).toList();
    await prefs.setStringList(key, encodedList);
  }

  // 加载消息列表
  static Future<List<ChatMessage>> loadMessages(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_messagesKey-$conversationId';
    final list = prefs.getStringList(key) ?? [];
    return list.map((str) => ChatMessage.fromJson(jsonDecode(str))).toList();
  }
}