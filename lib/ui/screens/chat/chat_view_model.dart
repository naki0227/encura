import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/image_optimizer_service.dart';

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

  Future<void> initialize(String? initialImageUrl) async {
    if (initialImageUrl != null) {
      // Simulate sending the image
      _messages.add(ChatMessage(
        text: 'Sent a map',
        isUser: true,
        // We don't have bytes here easily without downloading, so we might need to adjust ChatMessage or just show text
        // For now, let's just start the conversation context
      ));
      _isLoading = true;
      notifyListeners();

      try {
        // We need to fetch the image bytes if we want to send it to Gemini
        // Or we can just send the URL if Gemini supports it (it doesn't directly via this SDK usually, needs bytes)
        // For simplicity, let's assume we just ask a question about the map context, 
        // but ideally we should download the image bytes from the URL.
        
        // TODO: Implement downloading image bytes from URL to send to Gemini
        // For now, we will just send a text prompt saying we are looking at a map.
        // Real implementation would require downloading the image.
        
        final response = await _chatService.sendMessage(
          'I am looking at this venue map: $initialImageUrl. Please help me navigate.',
        );
        _messages.add(ChatMessage(text: response, isUser: false));
      } catch (e) {
        _messages.add(ChatMessage(text: 'Error loading map context: $e', isUser: false));
      } finally {
        _isLoading = false;
        notifyListeners();
      }
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
        imageQuality: 100, // Send high quality to server for processing
      );
      if (image == null) return;

      final imageBytes = await image.readAsBytes();
      
      _messages.add(ChatMessage(
        text: 'Analyzing...',
        isUser: true,
        imageBytes: imageBytes,
      ));
      _isLoading = true;
      notifyListeners();

      // Optimize image using Rust Microservice
      final optimizedBytes = await ImageOptimizerService.optimizeImage(imageBytes);

      final response = await _chatService.sendMessage(
        'Analyze this image and explain it as an art curator.',
        imageBytes: optimizedBytes.toList(), // Convert back to List<int>
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
