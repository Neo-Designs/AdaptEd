import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/ai_service.dart';
import '../../core/theme/dynamic_theme.dart';
import '../../core/utils/logger.dart';

class QuickChatScreen extends StatefulWidget {
  const QuickChatScreen({super.key});

  @override
  State<QuickChatScreen> createState() => _QuickChatScreenState();
}

class _QuickChatScreenState extends State<QuickChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [
    ChatMessage(
        role: 'ai',
        text: 'Hi! I\'m AdaptEd AI. How can I assist your learning today?'),
  ];
  bool _isStreaming = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String style, AIService aiService) async {
    if (_controller.text.trim().isEmpty || _isStreaming) return;

    final text = _controller.text;
    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _controller.clear();
      _isStreaming = true;
      _messages.add(ChatMessage(role: 'ai', text: '', isStreaming: true));
    });
    _scrollToBottom();

    try {
      String fullResponse = '';
      await for (final chunk in aiService.chatWithAIStream(text, style)) {
        fullResponse += chunk;
        setState(() {
          _messages.last =
              ChatMessage(role: 'ai', text: fullResponse, isStreaming: true);
        });
        _scrollToBottom();
      }

      setState(() {
        _messages.last =
            ChatMessage(role: 'ai', text: fullResponse, isStreaming: false);
        _isStreaming = false;
      });
    } catch (e, stack) {
      AppLogger.error('Chat Error',
          tag: 'QuickChat', error: e, stackTrace: stack);
      setState(() {
        _messages.last = ChatMessage(
            role: 'ai', text: 'I encountered an error. Please try again.');
        _isStreaming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DynamicTheme>(context);
    final aiService = Provider.of<AIService>(context, listen: false);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return ChatBubble(msg: msg, theme: theme);
            },
          ),
        ),
        _buildInputArea(theme, aiService),
      ],
    );
  }

  Widget _buildInputArea(DynamicTheme theme, AIService aiService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: theme.bodyStyle,
                decoration: InputDecoration(
                  hintText: 'Ask anything...',
                  hintStyle: theme.bodyStyle.copyWith(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                        color: theme.primaryColor.withValues(alpha: 0.2)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.8),
                ),
                onSubmitted: (_) =>
                    _sendMessage(theme.traits.learningProfileName, aiService),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () =>
                  _sendMessage(theme.traits.learningProfileName, aiService),
              child: CircleAvatar(
                radius: 24,
                backgroundColor:
                    _isStreaming ? Colors.grey : theme.primaryColor,
                child: _isStreaming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String role;
  final String text;
  final bool isStreaming;

  ChatMessage(
      {required this.role, required this.text, this.isStreaming = false});
}

class ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  final DynamicTheme theme;

  const ChatBubble({super.key, required this.msg, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUser ? theme.primaryColor : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
            border: !isUser
                ? Border.all(color: theme.primaryColor.withValues(alpha: 0.1))
                : null,
          ),
          child: Text(
            msg.text,
            style: theme.bodyStyle.copyWith(
              color: isUser ? Colors.white : Colors.black87,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
