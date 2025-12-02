import 'package:flutter/material.dart';
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
  final ChatService _chatService = ChatService();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _messages.add(ChatMessage(text: text, isUser: true));
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _chatService.sendMessage(text);
      _messages.add(ChatMessage(text: response, isUser: false));
    } catch (e) {
      _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickImageAndSend() async {
    try {
      final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
      if (image == null) return;

      final imageBytes = await image.readAsBytes();
      
      _messages.add(ChatMessage(
        text: 'Sent an image',
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
      _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
