import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:adapted/core/services/ai_service.dart';
import 'package:adapted/core/services/firestore_service.dart';
import 'package:adapted/core/theme/dynamic_theme.dart';
import 'package:adapted/core/utils/logger.dart';
import 'package:adapted/core/widgets/adapted_card.dart';
import 'package:adapted/core/widgets/xp_bar.dart';
import 'package:adapted/features/quiz/assessment_screen.dart';
import 'package:adapted/features/screening/scoring_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? initialArguments;
  const DashboardScreen({super.key, this.initialArguments});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();
  final FirestoreService _firestoreService = FirestoreService();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<Map<String, dynamic>> _messages = [];

  // ── Session management ────────────────────────────────────────────────────
  String? _activeSessionId;
  StreamSubscription<QuerySnapshot>? _chatSubscription;

  bool _isUploading = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _isAiTyping = false;
  String _extractedText = '';

  // ── Typing animation ──────────────────────────────────────────────────────
  int? _typingMessageIndex;
  String _typingDisplayText = '';
  Timer? _typingTimer;
  bool _userIsTyping = false;

  // ── Review ────────────────────────────────────────────────────────────────
  int _reviewStars = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _reviewSubmitted = false;

  // ── Reactions & Confetti ──────────────────────────────────────────────────
  final Map<int, String?> _messageReactions = {};
  bool _showConfetti = false;

  // ── Reading ruler ─────────────────────────────────────────────────────────
  double _rulerY = 200.0;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initStt();

    // Session routing
    if (widget.initialArguments != null &&
        widget.initialArguments!['reSummarizeText'] != null) {
      _createNewSession();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _uploadDocumentFromText(
          widget.initialArguments!['reSummarizeText'],
          widget.initialArguments!['fileName'] ?? 'Document',
        );
      });
    } else if (widget.initialArguments != null &&
        widget.initialArguments!['sessionId'] != null) {
      _setActiveSession(widget.initialArguments!['sessionId']);
    } else {
      _loadInitialSession();
    }

    // Typing state listener
    _chatController.addListener(() {
      final typing = _chatController.text.isNotEmpty;
      if (typing != _userIsTyping) {
        setState(() => _userIsTyping = typing);
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _chatSubscription?.cancel();
    _reviewController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // ── Session Management ────────────────────────────────────────────────────
  void _loadInitialSession() async {
    if (_firestoreService.currentUser == null) return;

    final sessionsSnap = await FirebaseFirestore.instance
        .collection('sessions')
        .where('userId', isEqualTo: _firestoreService.currentUser!.uid)
        .orderBy('lastActive', descending: true)
        .limit(1)
        .get();

    if (sessionsSnap.docs.isNotEmpty) {
      _setActiveSession(sessionsSnap.docs.first.id);
    } else {
      _createNewSession();
    }
  }

  void _createNewSession() async {
    final newId = await _firestoreService.createChatSession(title: 'New Chat');
    _setActiveSession(newId);
    await _firestoreService.saveChatMessage(newId, 'ai',
        'Hello! I\'m your adaptive learning assistant. Upload a document to get a summary or ask me a question!');
  }

  void _setActiveSession(String sessionId) {
    _chatSubscription?.cancel();
    if (mounted) {
      setState(() {
        _activeSessionId = sessionId;
        _messages = [];
      });
    }

    _chatSubscription =
        _firestoreService.getChatMessages(sessionId).listen((snapshot) {
      final messages = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
      if (mounted) {
        setState(() => _messages = messages);
        _scrollToBottom();
      }
    });
  }

  void _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  void _initStt() async {
    _speechEnabled = await _speech.initialize(
      onError: (val) => debugPrint('STT Error: $val'),
      onStatus: (val) => debugPrint('STT Status: $val'),
    );
    if (mounted) setState(() {});
  }

  void _showChatHistory(DynamicTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.onSurfaceTextColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      color: theme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text('Chat History',
                      style: theme.titleStyle.copyWith(fontSize: 18)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _createNewSession();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text('New chat',
                              style: theme.bodyStyle
                                  .copyWith(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: theme.onSurfaceTextColor.withValues(alpha: 0.1)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestoreService.getChatSessions(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded,
                              size: 48,
                              color: theme.onSurfaceTextColor
                                  .withValues(alpha: 0.2)),
                          const SizedBox(height: 12),
                          Text('No sessions yet',
                              style: theme.bodyStyle.copyWith(
                                color: theme.onSurfaceTextColor
                                    .withValues(alpha: 0.4),
                              )),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final isSelected = _activeSessionId == docs[index].id;
                      return ListTile(
                        selected: isSelected,
                        selectedColor: theme.primaryColor,
                        selectedTileColor:
                            theme.primaryColor.withValues(alpha: 0.1),
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(data['title'] ?? 'New Chat',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          Navigator.pop(ctx);
                          _setActiveSession(docs[index].id);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startTypingAnimation(int messageIndex, String fullText) {
    _typingTimer?.cancel();
    setState(() {
      _typingMessageIndex = messageIndex;
      _typingDisplayText = '';
    });

    int charIndex = 0;
    final delay = fullText.length > 200
        ? const Duration(milliseconds: 8)
        : const Duration(milliseconds: 18);

    _typingTimer = Timer.periodic(delay, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (charIndex < fullText.length) {
        setState(() {
          _typingDisplayText = fullText.substring(0, charIndex + 1);
          charIndex++;
        });
        _scrollToBottom();
      } else {
        timer.cancel();
        setState(() {
          _typingMessageIndex = null;
          _typingDisplayText = '';
        });
      }
    });
  }

  void _checkXpMilestone(int xp) {
    if (xp > 0 && xp % 100 == 0) {
      setState(() => _showConfetti = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showConfetti = false);
      });
    }
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      if (mounted) setState(() => _isSpeaking = true);
      await _flutterTts.speak(text);
    }
  }

  void _listen() async {
    if (!_speechEnabled) await _speech.initialize();
    if (_speech.isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          setState(() => _chatController.text = val.recognizedWords);
          if (val.hasConfidenceRating && val.confidence > 0) {
            if (val.recognizedWords.toLowerCase().contains('upload')) {
              _speech.stop();
              _uploadDocument(context);
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        localeId: 'en_US',
        onSoundLevelChange: (level) {},
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );
    }
  }

  void _navigateToQuiz() {
    if (_extractedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No material to quiz on yet! Upload a PDF first.')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (context) => AssessmentScreen(content: _extractedText)),
    );
  }

  void _showReviewDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final reviewCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Leave a Review'),
          content: TextField(
            controller: reviewCtrl,
            decoration: const InputDecoration(
                hintText: 'How is your learning experience?'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reviewCtrl.text.isNotEmpty) {
                  try {
                    await FirebaseFirestore.instance.collection('reviews').add({
                      'userId': _firestoreService.currentUser?.uid,
                      'text': reviewCtrl.text,
                      'rating': 5,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Thanks for your feedback!')));
                    }
                  } catch (e) {
                    AppLogger.error('Failed to save review', error: e);
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DynamicTheme>();
    final user = _firestoreService.currentUser;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.backgroundColor,
          drawer: _buildChatsDrawer(theme),
          body: SafeArea(
            child: Column(
              children: [
                if (user != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(theme.interactivePadding,
                        theme.interactivePadding, theme.interactivePadding, 0),
                    child: _buildProfileHeader(theme, user.uid),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: theme.interactivePadding),
                    child: _buildChatArea(theme),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(theme.interactivePadding, 8,
                      theme.interactivePadding, theme.interactivePadding),
                  child: _buildReviewSection(theme),
                ),
              ],
            ),
          ),
        ),
        if (theme.readingRuler)
          _ReadingRuler(
            rulerY: _rulerY,
            color: theme.primaryColor,
            onDrag: (y) => setState(() => _rulerY = y),
          ),
        if (_showConfetti)
          IgnorePointer(child: _ConfettiOverlay(color: theme.xpAccentColor)),
      ],
    );
  }

  // ── Chats Drawer ──────────────────────────────────────────────────────────
  Widget _buildChatsDrawer(DynamicTheme theme) {
    return Drawer(
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.only(top: 50, bottom: 20, left: 16, right: 16),
            color: theme.primaryColor,
            child: Row(
              children: [
                const Icon(Icons.forum, color: Colors.white),
                const SizedBox(width: 12),
                Text('Chats',
                    style: theme.titleStyle
                        .copyWith(color: Colors.white, fontSize: 20)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    _createNewSession();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getChatSessions(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No chats yet.'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isSelected = _activeSessionId == docs[index].id;
                    return ListTile(
                      selected: isSelected,
                      selectedColor: theme.primaryColor,
                      selectedTileColor:
                          theme.primaryColor.withValues(alpha: 0.1),
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(data['title'] ?? 'New Chat',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pop(context);
                        _setActiveSession(docs[index].id);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile Header ────────────────────────────────────────────────────────
  Widget _buildProfileHeader(DynamicTheme theme, String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final xp = (data['xp'] ?? 0) as int;
        final level = data['level'] ?? 1;
        final streak = data['streak'] ?? 0;
        final xpProgress = (xp % 500) / 500;

        WidgetsBinding.instance
            .addPostFrameCallback((_) => _checkXpMilestone(xp));

        return AdaptedCard(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.primaryColor,
                radius: 18,
                child: Text(level.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Level $level • $xp XP',
                            style: theme.titleStyle.copyWith(fontSize: 14)),
                        const Spacer(),
                        if (streak > 0) ...[
                          const Text('🔥', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text('$streak day${streak == 1 ? '' : 's'}',
                              style: theme.bodyStyle.copyWith(
                                fontSize: 12,
                                color: theme.xpAccentColor,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    XpBar(progress: xpProgress),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Main Chat Area ────────────────────────────────────────────────────────
  Widget _buildChatArea(DynamicTheme theme) {
    final hasMessages = _messages.isNotEmpty;
    return Column(
      children: [
        Expanded(
          child:
              hasMessages ? _buildMessagesList(theme) : _buildEmptyState(theme),
        ),
        const SizedBox(height: 8),
        _buildBottomInputBar(theme),
      ],
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(DynamicTheme theme) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.3)),
              ),
              child:
                  Icon(Icons.auto_awesome, size: 32, color: theme.primaryColor),
            ),
            const SizedBox(height: 20),
            Text('$greeting! ✨',
                style: theme.titleStyle.copyWith(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              'Upload a document or ask me anything',
              style: theme.bodyStyle.copyWith(
                color: theme.onSurfaceTextColor.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionCard(theme, '📄', 'Upload a PDF',
                    'Upload a document to get started'),
                _buildSuggestionCard(
                    theme, '🧠', 'Quiz me', 'Test your knowledge'),
                _buildSuggestionCard(
                    theme, '💬', 'Ask anything', 'I\'m here to help you learn'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(
      DynamicTheme theme, String emoji, String title, String subtitle) {
    return GestureDetector(
      onTap: () {
        if (title == 'Upload a PDF') {
          _uploadDocument(context);
        } else {
          _chatController.text = subtitle;
          FocusScope.of(context).requestFocus(FocusNode());
        }
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: theme.onSurfaceTextColor.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 8),
            Text(title,
                style: theme.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: theme.bodyStyle.copyWith(
                  fontSize: 11,
                  color: theme.onSurfaceTextColor.withValues(alpha: 0.5),
                )),
          ],
        ),
      ),
    );
  }

  // ── Messages List ─────────────────────────────────────────────────────────
  Widget _buildMessagesList(DynamicTheme theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      itemCount:
          _messages.length + (_isAiTyping ? 1 : 0) + (_userIsTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (_userIsTyping &&
            index == _messages.length + (_isAiTyping ? 1 : 0)) {
          return _buildUserTypingBubble(theme);
        }
        if (_isAiTyping && index == _messages.length) {
          return _buildTypingIndicator(theme);
        }

        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        final isAction = msg['role'] == 'system_action';

        if (isAction) return _buildActionButtons(theme, msg['text']);

        final isCurrentlyTyping = _typingMessageIndex == index;
        final displayText =
            isCurrentlyTyping ? _typingDisplayText : msg['text'].toString();

        return _buildMessageBubble(
            context, theme, msg, isUser, displayText, isCurrentlyTyping, index);
      },
    );
  }

  Widget _buildUserTypingBubble(DynamicTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
              border:
                  Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              _chatController.text,
              style: theme.bodyStyle.copyWith(
                color: theme.primaryColor,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person, size: 14, color: theme.primaryColor),
          ),
        ],
      ),
    );
  }

  // ── Bottom Input Bar ──────────────────────────────────────────────────────
  Widget _buildBottomInputBar(DynamicTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: theme.onSurfaceTextColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: _buildQuickActionChips(theme),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _inputIconButton(
                  icon: Icons.attach_file_rounded,
                  color: theme.primaryColor,
                  tooltip: 'Upload PDF',
                  onTap: () => _uploadDocument(context),
                ),
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Ask anything...',
                      hintStyle: theme.bodyStyle.copyWith(
                        color: theme.onSurfaceTextColor.withValues(alpha: 0.35),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                    ),
                    style: theme.bodyStyle,
                    onSubmitted: (_) => _sendMessage(theme),
                  ),
                ),
                _inputIconButton(
                  icon: _isListening ? Icons.mic : Icons.mic_none_rounded,
                  color: _isListening
                      ? Colors.red
                      : theme.onSurfaceTextColor.withValues(alpha: 0.4),
                  tooltip: 'Voice input',
                  onTap: _listen,
                ),
                _inputIconButton(
                  icon: Icons.history_rounded,
                  color: theme.onSurfaceTextColor.withValues(alpha: 0.4),
                  tooltip: 'Chat history',
                  onTap: () => _showChatHistory(theme),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _userIsTyping
                      ? GestureDetector(
                          key: const ValueKey('send'),
                          onTap: () => _sendMessage(theme),
                          child: Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_upward_rounded,
                                color: Colors.white, size: 18),
                          ),
                        )
                      : const SizedBox(key: ValueKey('empty'), width: 4),
                ),
              ],
            ),
          ),
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: LinearProgressIndicator(
                color: theme.xpAccentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inputIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  // ── Quick Action Chips ────────────────────────────────────────────────────
  Widget _buildQuickActionChips(DynamicTheme theme) {
    final chips = [
      {
        'label': '📝 Summarize',
        'prompt': 'Please summarize my uploaded material'
      },
      {
        'label': '🧪 Quiz me',
        'prompt': 'Create a short quiz based on my material'
      },
      {
        'label': '🔍 Explain simpler',
        'prompt': 'Explain the main concepts in simpler terms'
      },
      {
        'label': '💡 Key points',
        'prompt': 'What are the key points I should remember?'
      },
    ];

    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return GestureDetector(
            onTap: () {
              _chatController.text = chip['prompt']!;
              _sendMessage(theme);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                chip['label']!,
                style: GoogleFonts.lexend(
                  fontSize: 11,
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Message Bubble ────────────────────────────────────────────────────────
  Widget _buildMessageBubble(
    BuildContext context,
    DynamicTheme theme,
    Map<String, dynamic> msg,
    bool isUser,
    String displayText,
    bool isCurrentlyTyping,
    int index,
  ) {
    DateTime? timestamp;
    try {
      final ts = msg['timestamp'];
      if (ts != null) {
        if (ts is int) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(ts);
        } else {
          timestamp = (ts as dynamic).toDate() as DateTime;
        }
      }
    } catch (_) {
      timestamp = null;
    }

    final timeStr = timestamp != null
        ? '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.2)),
              ),
              child:
                  Icon(Icons.auto_awesome, size: 16, color: theme.primaryColor),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.primaryColor
                        : theme.isDarkMode
                            ? const Color(
                                0xFF2A2A3E) // ← visible dark card color
                            : theme.backgroundColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isUser
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: theme.onSurfaceTextColor
                                .withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: (isUser ? theme.primaryColor : Colors.black)
                            .withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildBubbleContent(
                      theme, msg, isUser, displayText, isCurrentlyTyping),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (timeStr.isNotEmpty)
                      Text(timeStr,
                          style: theme.bodyStyle.copyWith(
                            fontSize: 10,
                            color:
                                theme.onSurfaceTextColor.withValues(alpha: 0.4),
                          )),
                    if (!isUser) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _speak(msg['text']),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isSpeaking
                                  ? Icons.volume_up
                                  : Icons.volume_up_outlined,
                              size: 12,
                              color: theme.primaryColor.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 2),
                            Text('Read aloud',
                                style: theme.bodyStyle.copyWith(
                                  fontSize: 10,
                                  color:
                                      theme.primaryColor.withValues(alpha: 0.6),
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _reactionButton(theme, index, 'up', '👍'),
                      const SizedBox(width: 2),
                      _reactionButton(theme, index, 'down', '👎'),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reactionButton(
      DynamicTheme theme, int index, String type, String emoji) {
    final isActive = _messageReactions[index] == type;
    return GestureDetector(
      onTap: () => setState(() {
        _messageReactions[index] = isActive ? null : type;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isActive
              ? (type == 'up'
                  ? theme.primaryColor.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(emoji,
            style: TextStyle(
              fontSize: 14,
              color: isActive
                  ? (type == 'up' ? theme.primaryColor : Colors.red)
                  : null,
            )),
      ),
    );
  }

  // ── Bubble Content ────────────────────────────────────────────────────────
  Widget _buildBubbleContent(
    DynamicTheme theme,
    Map<String, dynamic> msg,
    bool isUser,
    String displayText,
    bool isCurrentlyTyping,
  ) {
    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(displayText,
            style: theme.bodyStyle.copyWith(color: Colors.white, height: 1.5)),
      );
    }

    String rawText = displayText.trim();
    if (rawText.startsWith('```json')) {
      rawText = rawText.substring(7);
    }
    if (rawText.startsWith('```')) {
      rawText = rawText.substring(3);
    }
    if (rawText.endsWith('```')) {
      rawText = rawText.substring(0, rawText.length - 3);
    }
    rawText = rawText.trim();

    try {
      final parsed = jsonDecode(rawText);
      if (parsed is List) {
        return Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: parsed
                .map((item) => _buildNeuroCard(
                      item['title']?.toString() ?? '',
                      item['content']?.toString() ?? '',
                      item['icon']?.toString() ?? '',
                      theme,
                    ))
                .toList(),
          ),
        );
      }
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: isCurrentlyTyping ? displayText : msg['text'].toString(),
            styleSheet: _getMarkdownStyle(theme),
            builders: {'strong': _AdhdHighlightBuilder(theme.traits.isADHD)},
          ),
          if (isCurrentlyTyping)
            Container(
              width: 2,
              height: 16,
              margin: const EdgeInsets.only(top: 2),
              color: theme.primaryColor,
            ),
        ],
      ),
    );
  }

  // ── Typing Indicator ──────────────────────────────────────────────────────
  Widget _buildTypingIndicator(DynamicTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
            ),
            child:
                Icon(Icons.auto_awesome, size: 16, color: theme.primaryColor),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                  color: theme.onSurfaceTextColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDots(color: theme.primaryColor),
                const SizedBox(width: 8),
                Text('thinking...',
                    style: theme.bodyStyle.copyWith(
                      fontSize: 12,
                      color: theme.onSurfaceTextColor.withValues(alpha: 0.5),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Review Section ────────────────────────────────────────────────────────
  Widget _buildReviewSection(DynamicTheme theme) {
    if (_reviewSubmitted) {
      return AdaptedCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: theme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text('Thanks for your feedback!',
                style: theme.bodyStyle.copyWith(
                    color: theme.primaryColor, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return AdaptedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rate_rounded,
                  color: theme.xpAccentColor, size: 20),
              const SizedBox(width: 8),
              Text('Rate this session',
                  style: theme.titleStyle.copyWith(fontSize: 15)),
              const Spacer(),
              GestureDetector(
                onTap: _showReviewDialog,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 13, color: theme.primaryColor),
                      const SizedBox(width: 4),
                      Text('Write a review',
                          style: theme.bodyStyle.copyWith(
                              fontSize: 12, color: theme.primaryColor)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _reviewStars = starIndex),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    starIndex <= _reviewStars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: starIndex <= _reviewStars
                        ? theme.xpAccentColor
                        : theme.onSurfaceTextColor.withValues(alpha: 0.3),
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          if (_reviewStars > 0) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _reviewController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Tell us about your experience (optional)...',
                hintStyle: theme.bodyStyle.copyWith(
                  fontSize: 13,
                  color: theme.onSurfaceTextColor.withValues(alpha: 0.4),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: theme.onSurfaceTextColor.withValues(alpha: 0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: theme.onSurfaceTextColor.withValues(alpha: 0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.primaryColor),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _reviewSubmitted = true);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('⭐ ${'★' * _reviewStars} — Thank you!'),
                    backgroundColor: theme.primaryColor,
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Submit Review', style: theme.buttonTextStyle),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Action Buttons ────────────────────────────────────────────────────────
  Widget _buildActionButtons(DynamicTheme theme, String type) {
    if (type == 'prompt_upload_or_quiz') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          children: [
            Text('Awesome job! What\'s next?',
                style: theme.titleStyle.copyWith(fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _uploadDocument(context),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Upload More'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.secondaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _navigateToQuiz,
                  icon: const Icon(Icons.quiz, size: 16),
                  label: const Text('Take Quiz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ── Send Message ──────────────────────────────────────────────────────────
  void _sendMessage(DynamicTheme theme) async {
    if (_chatController.text.trim().isEmpty || _activeSessionId == null) return;

    final text = _chatController.text.trim();
    final sessionId = _activeSessionId!;

    // Auto-title session on first user message
    if (_messages.where((m) => m['role'] == 'user').isEmpty) {
      final words = text.split(' ');
      final newTitle =
          words.take(5).join(' ') + (words.length > 5 ? '...' : '');
      FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .update({'title': newTitle});
    }

    _chatController.clear();
    await _firestoreService.saveChatMessage(sessionId, 'user', text);
    setState(() => _isAiTyping = true);
    _scrollToBottom();

    try {
      final response = await _aiService.chatWithAI(
        text,
        theme.traits.learningProfileName,
        onWait: (msg) {
          if (mounted) {
            _firestoreService.saveChatMessage(sessionId, 'ai', msg);
          }
        },
      );
      await _firestoreService.saveChatMessage(sessionId, 'ai', response);

      if (mounted) {
        setState(() => _isAiTyping = false);
        final newIndex = _messages.length - 1;
        if (newIndex >= 0) _startTypingAnimation(newIndex, response);
      }
    } catch (e) {
      setState(() => _isAiTyping = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AI Error: $e')));
      }
    }
    _scrollToBottom();
  }

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

  // ── Upload Document ───────────────────────────────────────────────────────
  Future<void> _uploadDocument(BuildContext context) async {
    final user = _firestoreService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to upload.')));
      return;
    }

    if (_activeSessionId == null) {
      _createNewSession();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    final sessionId = _activeSessionId!;

    setState(() => _isUploading = true);

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null) return;

      final pickedFile = result.files.single;
      final String fileName = pickedFile.name;
      final Uint8List? bytes = pickedFile.bytes;
      if (bytes == null) throw Exception('Could not read file bytes.');

      String fileUrl = '';
      String extractedText = '';

      try {
        final results = await Future.wait([
          _firestoreService.uploadPdfToStorage(bytes, fileName, user.uid),
          Future(() {
            final PdfDocument document = PdfDocument(inputBytes: bytes);
            final text = PdfTextExtractor(document).extractText();
            document.dispose();
            return text;
          }),
        ]);
        fileUrl = results[0];
        extractedText = results[1];
        setState(() => _extractedText = extractedText);
      } catch (e) {
        extractedText = '';
      }

      if (!context.mounted) return;
      final traits = Provider.of<DynamicTheme>(context, listen: false).traits;
      await _firestoreService.saveChatMessage(sessionId, 'ai',
          'Reading $fileName and generating your personalised summary…');

      final String summary = await _aiService.generateAdaptiveSummary(
        extractedText,
        isADHD: traits.isADHD,
        isAutistic: traits.isAutistic,
        isDyslexic: traits.isDyslexic,
        isDyspraxic: traits.isDyspraxic,
        onWait: (msg) {
          if (mounted) {
            _firestoreService.saveChatMessage(sessionId, 'ai', msg);
          }
        },
      );

      if (!mounted) return;
      await _firestoreService.saveLearningMaterial(
        title: fileName,
        summary: summary,
        fullText: extractedText,
        fileUrl: fileUrl,
        userTraits: traits,
        sessionId: sessionId,
      );

      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .update({'title': fileName, 'pdfName': fileName});

      if (!mounted) return;
      await _firestoreService.saveChatMessage(sessionId, 'ai',
          'Here is your personalised summary for **$fileName**:');

      try {
        String rawText = summary.trim();
        if (rawText.startsWith('```json')) {
          rawText = rawText.substring(7);
        }
        if (rawText.startsWith('```')) {
          rawText = rawText.substring(3);
        }
        if (rawText.endsWith('```')) {
          rawText = rawText.substring(0, rawText.length - 3);
        }
        rawText = rawText.trim();

        final List<dynamic> parsedChunks = jsonDecode(rawText);
        for (var chunk in parsedChunks) {
          if (!mounted) break;
          final chunkString = jsonEncode([chunk]);
          await _firestoreService.saveChatMessage(sessionId, 'ai', chunkString);
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      } catch (e) {
        if (!mounted) return;
        await _firestoreService.saveChatMessage(sessionId, 'ai', summary);
        // ← ADD typing animation
        if (mounted) {
          final newIndex = _messages.length - 1;
          if (newIndex >= 0) {
            _startTypingAnimation(newIndex, summary);
          }
        }
      }

      await _firestoreService.saveChatMessage(
          sessionId, 'system_action', 'prompt_upload_or_quiz');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload/Analyse failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadDocumentFromText(
      String extractedText, String fileName) async {
    final user = _firestoreService.currentUser;
    if (user == null || _activeSessionId == null) return;
    final sessionId = _activeSessionId!;

    setState(() => _isUploading = true);
    if (!mounted) return;
    final traits = Provider.of<DynamicTheme>(context, listen: false).traits;

    await _firestoreService.saveChatMessage(
        sessionId, 'ai', 'Re-analyzing $fileName for a new summary...');

    try {
      final String summary = await _aiService.generateAdaptiveSummary(
        extractedText,
        isADHD: traits.isADHD,
        isAutistic: traits.isAutistic,
        isDyslexic: traits.isDyslexic,
        isDyspraxic: traits.isDyspraxic,
        onWait: (msg) {
          if (mounted) {
            _firestoreService.saveChatMessage(sessionId, 'ai', msg);
          }
        },
      );

      if (!mounted) return;
      FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .update({'title': 'Re-Summary: $fileName'});

      await _firestoreService.saveChatMessage(sessionId, 'ai',
          'Here is your re-generated summary for **$fileName**:');

      try {
        String rawText = summary.trim();
        if (rawText.startsWith('```json')) {
          rawText = rawText.substring(7);
        }
        if (rawText.startsWith('```')) {
          rawText = rawText.substring(3);
        }
        if (rawText.endsWith('```')) {
          rawText = rawText.substring(0, rawText.length - 3);
        }
        rawText = rawText.trim();

        final List<dynamic> parsedChunks = jsonDecode(rawText);
        for (var chunk in parsedChunks) {
          if (!mounted) break;
          final chunkString = jsonEncode([chunk]);
          await _firestoreService.saveChatMessage(sessionId, 'ai', chunkString);
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      } catch (e) {
        if (!mounted) return;
        await _firestoreService.saveChatMessage(sessionId, 'ai', summary);
      }
      await _firestoreService.saveChatMessage(
          sessionId, 'system_action', 'prompt_upload_or_quiz');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Re-summarize failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Neuro Card ────────────────────────────────────────────────────────────
  Widget _buildNeuroCard(
      String title, String content, String icon, DynamicTheme theme) {
    Color bgColor = const Color(0xFFF8FAFC);
    if (theme.traits.isADHD) bgColor = const Color(0xFFFDF2F2);
    if (theme.traits.isAutistic) bgColor = const Color(0xFFF0F4FF);

    final cardTextColor = theme.isDarkMode ? Colors.white : Colors.black87;
    TextStyle baseTextStyle;
    if (theme.traits.isDyslexic) {
      baseTextStyle = TextStyle(
        fontFamily: 'OpenDyslexic',
        height: 1.6,
        color: cardTextColor, // ← fixed
      );
    } else {
      baseTextStyle = GoogleFonts.lexend(
          textStyle: TextStyle(height: 1.6, color: cardTextColor)); // ← fixed
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon.isNotEmpty) ...[
                    Text(icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(title,
                        style: baseTextStyle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            TypewriterMarkdown(
              data: content.trim(),
              styleSheet: _getMarkdownStyle(theme),
              builders: {
                'strong': _HighlightBuilder(theme.traits),
              },
            ),
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _getMarkdownStyle(DynamicTheme theme) {
    final isDyslexic = theme.traits.isDyslexic;
    final double lSpacing = isDyslexic ? 1.5 : 0.3;
    final double wSpacing = isDyslexic ? 2.0 : 0.0;
    const double hght = 1.6;

    // ← Fix: use white in dark mode, black87 in light mode
    final textColor = theme.isDarkMode ? Colors.white : Colors.black87;

    TextStyle baseTextStyle;
    if (isDyslexic) {
      baseTextStyle = TextStyle(
        fontFamily: 'OpenDyslexic',
        color: textColor, // ← was Colors.black87
        height: hght,
        letterSpacing: lSpacing,
        wordSpacing: wSpacing,
      );
    } else {
      baseTextStyle = GoogleFonts.lexend(
          textStyle: theme.bodyStyle.copyWith(
              color: textColor, // ← was Colors.black87
              height: hght,
              letterSpacing: lSpacing,
              wordSpacing: wSpacing));
    }

    return MarkdownStyleSheet(
      p: baseTextStyle,
      strong: baseTextStyle.copyWith(fontWeight: FontWeight.bold),
      h2: baseTextStyle.copyWith(fontSize: 16),
      h3: baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
      listBullet: baseTextStyle,
      blockSpacing: 12.0,
    );
  }
}

// ── Reading Ruler ─────────────────────────────────────────────────────────────
class _ReadingRuler extends StatelessWidget {
  final double rulerY;
  final Color color;
  final Function(double) onDrag;

  const _ReadingRuler({
    required this.rulerY,
    required this.color,
    required this.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: rulerY,
      left: 0,
      right: 0,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          final newY = (rulerY + details.delta.dy)
              .clamp(0.0, MediaQuery.of(context).size.height - 40);
          onDrag(newY);
        },
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.symmetric(
              horizontal:
                  BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.drag_handle,
                    color: color.withValues(alpha: 0.6), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Typing Dots ───────────────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index / 3;
            final animValue = ((_controller.value - delay) % 1.0 + 1.0) % 1.0;
            final opacity =
                animValue < 0.5 ? animValue * 2 : (1.0 - animValue) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.3 + opacity * 0.7),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Confetti Overlay ──────────────────────────────────────────────────────────
class _ConfettiOverlay extends StatefulWidget {
  final Color color;
  const _ConfettiOverlay({required this.color});

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ConfettiParticle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(80, (_) => _ConfettiParticle(_random));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double speed;
  final double size;
  final double rotation;
  final Color color;

  _ConfettiParticle(Random random)
      : x = random.nextDouble(),
        speed = 0.3 + random.nextDouble() * 0.7,
        size = 6 + random.nextDouble() * 8,
        rotation = random.nextDouble() * 2 * pi,
        color = [
          Colors.pink,
          Colors.blue,
          Colors.yellow,
          Colors.green,
          Colors.orange,
          Colors.purple,
          Colors.red,
          Colors.teal,
        ][random.nextInt(8)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;
  final Color color;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = size.height * progress * p.speed;
      final x = size.width * p.x;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * 5);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ── ADHD Highlight Builder (used in chat bubbles) ─────────────────────────────
class _AdhdHighlightBuilder extends MarkdownElementBuilder {
  final bool isADHD;
  _AdhdHighlightBuilder(this.isADHD);

  static int _colorIndex = 0;
  final List<Color> _highlightColors = [
    const Color(0xFFE3F2FD),
    const Color(0xFFFFF9C4),
    const Color(0xFFE8F5E9),
  ];

  @override
  Widget visitText(text, TextStyle? preferredStyle) {
    if (isADHD) {
      final color = _highlightColors[_colorIndex % _highlightColors.length];
      _colorIndex++;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(text.text,
            style: (preferredStyle ?? const TextStyle()).copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            )),
      );
    }
    return Text(text.text,
        style: (preferredStyle ?? const TextStyle())
            .copyWith(fontWeight: FontWeight.bold));
  }
}

// ── General Highlight Builder (used in neuro cards) ───────────────────────────
class _HighlightBuilder extends MarkdownElementBuilder {
  final UserTraits traits;
  _HighlightBuilder(this.traits);

  @override
  Widget visitText(text, TextStyle? preferredStyle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Colors.yellow.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        text.text,
        style: (preferredStyle ?? const TextStyle())
            .copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Typewriter Markdown ───────────────────────────────────────────────────────
class TypewriterMarkdown extends StatefulWidget {
  final String data;
  final MarkdownStyleSheet? styleSheet;
  final Map<String, MarkdownElementBuilder>? builders;

  const TypewriterMarkdown({
    super.key,
    required this.data,
    this.styleSheet,
    this.builders,
  });

  @override
  State<TypewriterMarkdown> createState() => _TypewriterMarkdownState();
}

class _TypewriterMarkdownState extends State<TypewriterMarkdown> {
  String _displayedText = '';
  int _currentIndex = 0;
  bool _isTyping = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(TypewriterMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _timer?.cancel();
      _displayedText = '';
      _currentIndex = 0;
      _isTyping = true;
      _startTyping();
    }
  }

  void _startTyping() {
    _timer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (!mounted || !_isTyping || _currentIndex >= widget.data.length - 1) {
        timer.cancel();
        if (mounted && _isTyping) {
          setState(() {
            _isTyping = false;
            _displayedText = widget.data;
          });
        }
        return;
      }
      setState(() {
        _currentIndex++;
        _displayedText = widget.data.substring(0, _currentIndex);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _isTyping = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: _displayedText,
      styleSheet: widget.styleSheet,
      builders: widget.builders ?? const {},
    );
  }
}
