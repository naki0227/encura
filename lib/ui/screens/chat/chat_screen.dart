import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_view_model.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion.dart';

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
  final Set<Object> _revealed = {};

  static const _suggestions = [
    '印象派ってどんな絵？',
    '浮世絵の見どころを教えて',
    '美術館を楽しむコツは？',
    '仏像の見分け方を知りたい',
  ];

  void _send(ChatViewModel viewModel, String text) {
    if (text.trim().isEmpty) return;
    viewModel.sendMessage(text.trim());
    _controller.clear();
  }

  Widget _buildIntro(BuildContext context, ChatViewModel viewModel) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 100, 28, 24),
        child: Reveal(
          id: 'intro',
          seen: _revealed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ASK THE CURATOR',
                style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, letterSpacing: 2.4, color: Palette.gold),
              ),
              const SizedBox(height: 10),
              Text(
                '作品のこと、\nなんでも聞いてください。',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Palette.text,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                      letterSpacing: 1,
                    ),
              ),
              const SizedBox(height: 12),
              const Text(
                '左下のカメラで作品を撮ると、その作品を解説します。',
                style: TextStyle(color: Palette.textSub, fontSize: 13, height: 1.8),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in _suggestions)
                    Pressable(
                      onTap: () => _send(viewModel, q),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Palette.line),
                          color: Palette.wall,
                        ),
                        child: Text(q, style: const TextStyle(color: Palette.text, fontSize: 13)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('学芸員に聞く'),
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
          Column(
            children: [
              Expanded(
                child: viewModel.messages.isEmpty && !viewModel.isLoading
                    ? _buildIntro(context, viewModel)
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                  itemCount: viewModel.messages.length,
                  itemBuilder: (context, index) {
                    final message = viewModel.messages[index];
                    final isUser = message.isUser;
                    return Reveal(
                      id: index,
                      seen: _revealed,
                      offset: 12,
                      child: Padding(
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
                      strokeWidth: 2,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: const BoxDecoration(
                  color: Palette.wall,
                  border: Border(top: BorderSide(color: Palette.line)),
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
                          hintText: '作品について質問する…',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onSubmitted: (value) => _send(viewModel, value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                      onPressed: () => _send(viewModel, _controller.text),
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
