import 'dart:convert';

import 'package:encura/core/services/chat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<http.Request> requests;

  FunctionsClient functionsReturning(http.Response Function(Map<String, dynamic> body) reply) {
    final client = MockClient((request) async {
      requests.add(request);
      return reply(jsonDecode(request.body) as Map<String, dynamic>);
    });
    return FunctionsClient('https://project.example/functions/v1', {}, httpClient: client);
  }

  setUp(() => requests = []);

  test('sends chat to the curator function, never to Gemini directly', () async {
    final service = ChatService(
      functions: functionsReturning((_) => http.Response(
          jsonEncode({'text': 'モネの睡蓮です。'}), 200,
          headers: {'content-type': 'application/json'})),
    );

    final reply = await service.sendMessage('この絵は？', imageBytes: [1, 2, 3]);

    expect(reply, 'モネの睡蓮です。');
    expect(requests.single.url.path, '/functions/v1/curator');
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['task'], 'chat');
    expect(body['message'], 'この絵は？');
    expect(body['image'], base64Encode([1, 2, 3]));
    expect(requests.single.url.host, isNot(contains('googleapis')));
  });

  test('carries the conversation history into the next turn', () async {
    final service = ChatService(
      functions: functionsReturning((body) => http.Response(
          jsonEncode({'text': 'answer ${(body['history'] as List).length}'}), 200,
          headers: {'content-type': 'application/json'})),
    );

    await service.sendMessage('first');
    final second = await service.sendMessage('second');

    expect(second, 'answer 2');
    final history = (jsonDecode(requests.last.body) as Map<String, dynamic>)['history'] as List;
    expect(history, [
      {'role': 'user', 'text': 'first'},
      {'role': 'model', 'text': 'answer 0'},
    ]);
  });

  test('shows a friendly message instead of a raw error when the function fails', () async {
    final service = ChatService(
      functions: functionsReturning((_) => http.Response(
          jsonEncode({'error': 'upstream error'}), 502,
          headers: {'content-type': 'application/json'})),
    );

    final reply = await service.sendMessage('hello');

    expect(reply, contains('接続できません'));
    expect(reply, isNot(contains('Exception')));
  });
}
