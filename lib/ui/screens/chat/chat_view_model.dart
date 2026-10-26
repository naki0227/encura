import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../core/services/chat_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<int>? imageBytes;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.imageBytes,
  });
}

class ChatViewModel extends ChangeNotifier {
  static const _failureMessage = '答えを受け取れませんでした。通信状況を確かめて、もう一度お試しください。';

  final ChatService _chatService = ChatService();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  Future<void> initialize(String? initialImageUrl, {String? question}) async {
    if (question != null) {
      await sendMessage(question);
      return;
    }
    if (initialImageUrl == null) return;

    _isLoading = true;
    notifyListeners();
    try {
      // Send the map image itself; the model cannot open a URL.
      final res = await http.get(Uri.parse(initialImageUrl)).timeout(const Duration(seconds: 20));
      final isImage = res.statusCode == 200 &&
          (res.headers['content-type'] ?? '').startsWith('image/');
      if (!isImage) throw Exception('map image unavailable (${res.statusCode})');
      final imageBytes = res.bodyBytes;
      _messages.add(ChatMessage(text: 'この館内マップについて教えて', isUser: true, imageBytes: imageBytes));
      notifyListeners();

      final response = await _chatService.sendMessage(
        'これは美術館・博物館の館内マップです。主なエリアと見どころ、回り方を案内してください。',
        imageBytes: imageBytes,
      );
      _messages.add(ChatMessage(text: response, isUser: false));
    } catch (e) {
      debugPrint('Map chat error: $e');
      _messages.add(ChatMessage(text: 'マップ画像を読み込めませんでした。時間をおいて再度お試しください。', isUser: false));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _messages.add(ChatMessage(text: text, isUser: true));
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _chatService.sendMessage(text);
      _messages.add(ChatMessage(text: response, isUser: false));
    } catch (e) {
      debugPrint('Curator request failed: $e');
      _messages.add(ChatMessage(text: _failureMessage, isUser: false));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickImageAndSend() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        // Resized and compressed on the device: plenty for the curator to
        // recognise the work, and small enough to send quickly.
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image == null) return;

      final imageBytes = await image.readAsBytes();
      
      _messages.add(ChatMessage(
        text: 'この作品について教えて',
        isUser: true,
        imageBytes: imageBytes,
      ));
      _isLoading = true;
      notifyListeners();

      final response = await _chatService.sendMessage(
        'Analyze this image and explain it as an art curator.',
        imageBytes: imageBytes,
      );
      
      _messages.add(ChatMessage(text: response, isUser: false));
    } catch (e) {
      debugPrint('Curator request failed: $e');
      _messages.add(ChatMessage(text: _failureMessage, isUser: false));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
