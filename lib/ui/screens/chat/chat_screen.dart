import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_view_model.dart';

class ChatScreen extends StatelessWidget {
  final String? initialImageUrl;

  const ChatScreen({super.key, this.initialImageUrl});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatViewModel()..initialize(initialImageUrl),
      child: const _ChatScreenContent(),
    );
  }
}

class _ChatScreenContent extends StatefulWidget {
  const _ChatScreenContent();

  @override
  State<_ChatScreenContent> createState() => _ChatScreenContentState();
}

class _ChatScreenContentState extends State<_ChatScreenContent> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Anytime Curator'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
                Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Washi Texture Background
          Positioned.fill(
            child: CustomPaint(
              painter: WashiTexturePainter(
                baseColor: Theme.of(context).scaffoldBackgroundColor,
                textureColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                  itemCount: viewModel.messages.length,
                  itemBuilder: (context, index) {
                    final message = viewModel.messages[index];
                    final isUser = message.isUser;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser) ...[
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                                image: const DecorationImage(
                                  image: AssetImage('assets/images/curator_icon.png'), // Placeholder or use Icon
                                  fit: BoxFit.cover,
                                ),
                                color: Colors.black,
                              ),
                              child: const Icon(Icons.account_balance, color: Colors.white, size: 20), // Fallback icon
                            ),
                            const SizedBox(width: 12),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                                    : Theme.of(context).cardTheme.color,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                                  bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                                ),
                                border: Border.all(
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (message.imageBytes != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8.0),
                                        child: Image.memory(
                                          Uint8List.fromList(message.imageBytes!),
                                          width: 200,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    message.text,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      height: 1.6,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (viewModel.isLoading)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.camera_alt, color: Theme.of(context).primaryColor),
                      onPressed: () => viewModel.pickImageAndSend(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Ask about art...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            viewModel.sendMessage(value);
                            _controller.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                      onPressed: () {
                        if (_controller.text.isNotEmpty) {
                          viewModel.sendMessage(_controller.text);
                          _controller.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WashiTexturePainter extends CustomPainter {
  final Color baseColor;
  final Color textureColor;

  WashiTexturePainter({required this.baseColor, required this.textureColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = baseColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final noisePaint = Paint()
      ..color = textureColor
      ..style = PaintingStyle.fill;

    // Simple noise generation (simulated)
    // In a real app, you might use an image shader or a more complex noise algorithm.
    // Here we draw random small circles to simulate paper fibers.
    final random = Random(42); // Fixed seed for consistency
    for (int i = 0; i < 5000; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5;
      canvas.drawCircle(Offset(x, y), radius, noisePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
