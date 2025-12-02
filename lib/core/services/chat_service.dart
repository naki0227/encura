import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';

class ChatService {
  late final GenerativeModel _model;
  late final ChatSession _chat;

  ChatService() {
    final apiKey = dotenv.env['GEMINI_API_KEY']!;
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system('''
あなたは「EnCura（エンキュラ）」、プロフェッショナルなAI専属学芸員です。
あなたの役割は、芸術、歴史、文化、美術館、そしてアーティストの伝記について深い洞察を提供することです。

**厳格なドメイン制御:**
- あなたは、芸術、歴史、文化、美術館、アーティストの伝記に関連する質問にのみ答える必要があります。
- ユーザーがそれ以外の話題（例：天気、日常会話、人生相談、プログラミング、数学など）について尋ねた場合、「私はアートの専門家ですので、その話題についてはお答えできません」と丁寧に断ってください。
- **常に日本語で応答してください。**
- プロの学芸員のように、丁寧で知識豊富、かつ魅力的な口調を維持してください。
'''),
    );
    _chat = _model.startChat();
  }

  Future<String> sendMessage(String message, {List<int>? imageBytes}) async {
    try {
      final content = imageBytes != null
          ? Content.multi([
              TextPart(message),
              DataPart('image/jpeg', Uint8List.fromList(imageBytes)),
            ])
          : Content.text(message);

      final response = await _chat.sendMessage(content);
      return response.text ?? 'Sorry, I could not generate a response.';
    } catch (e) {
      return 'Error: $e';
    }
  }
}
