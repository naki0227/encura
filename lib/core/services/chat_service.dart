import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to the AI curator through the `curator` Edge Function.
/// The Gemini API key stays on the server.
class ChatService {
  ChatService({FunctionsClient? functions}) : _functions = functions;

  final FunctionsClient? _functions;
  final List<Map<String, String>> _history = [];

  FunctionsClient get _client => _functions ?? Supabase.instance.client.functions;

  Future<String> sendMessage(String message, {List<int>? imageBytes}) async {
    try {
      final response = await _client.invoke(
        'curator',
        body: {
          'task': 'chat',
          'message': message,
          'history': _history,
          if (imageBytes != null) 'image': base64Encode(imageBytes),
        },
      );
      final data = response.data;
      final text = data is Map ? data['text'] as String? : null;
      if (text == null || text.isEmpty) {
        return '申し訳ありません。回答を生成できませんでした。';
      }
      _history
        ..add({'role': 'user', 'text': message})
        ..add({'role': 'model', 'text': text});
      return text;
    } catch (e) {
      debugPrint('ChatService error: $e');
      return '申し訳ありません。ただいまAI学芸員に接続できません。時間をおいて再度お試しください。';
    }
  }
}
