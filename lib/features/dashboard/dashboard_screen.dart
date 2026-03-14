import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:adapted/core/services/ai_service.dart';
import 'package:adapted/core/services/firestore_service.dart';
import 'package:adapted/core/theme/dynamic_theme.dart';
import 'package:adapted/core/widgets/adapted_card.dart';
import 'package:adapted/core/widgets/xp_bar.dart';
import 'package:adapted/features/quiz/assessment_screen.dart';
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
  const DashboardScreen({super.key});

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

  // ── State ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _messages = [];
  bool _isUploading = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _isAiTyping = false;
  String _extractedText = "";

  // ── Typing animation ──────────────────────────────────────────────────────
  int? _typingMessageIndex;
  String _typingDisplayText = '';
  Timer? _typingTimer;

  // ── Review ────────────────────────────────────────────────────────────────
  int _reviewStars = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _reviewSubmitted = false;

  // ← NEW: Reactions & Confetti
  final Map<int, String?> _messageReactions = {};
  bool _showConfetti = false;

  // ← NEW: Reading ruler
  double _rulerY = 200.0;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initStt();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _reviewController.dispose();
    super.dispose();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
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

  void _loadChatHistory() {
    _firestoreService.getChatMessages().listen((snapshot) {
      final messages = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
      if (mounted) {
        setState(() {
          _messages = messages;
          if (_messages.isEmpty) {
            _messages.add({
              'role': 'ai',
              'text':
                  'Hello! I\'m your adaptive learning assistant. Upload a document to get a summary or ask me a question!',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          }
        });
        _scrollToBottom();
      }
    });
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

  // ← NEW: Confetti trigger
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
            if (val.recognizedWords.toLowerCase().contains("upload")) {
              _speech.stop();
              _uploadDocument(context);
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        localeId: "en_US",
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
          content: Text("No material to quiz on yet! Upload a PDF first.")));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (context) => AssessmentScreen(content: _extractedText)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DynamicTheme>();

    // ← Wrap in Stack for confetti + reading ruler overlays
    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.backgroundColor,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(theme.interactivePadding),
              child: Column(
                children: [
                  if (_firestoreService.currentUser != null)
                    _buildProfileHeader(
                        theme, _firestoreService.currentUser!.uid),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _buildChatSection(theme)),
                        const SizedBox(height: 12),
                        _buildReviewSection(theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ← Reading ruler overlay
        if (theme.readingRuler)
          _ReadingRuler(
            rulerY: _rulerY,
            color: theme.primaryColor,
            onDrag: (y) => setState(() => _rulerY = y),
          ),

        // ← Confetti overlay
        if (_showConfetti)
          IgnorePointer(
            child: _ConfettiOverlay(color: theme.xpAccentColor),
          ),
      ],
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

        // Check XP milestone
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
                        Text("Level $level • $xp XP",
                            style: theme.titleStyle.copyWith(fontSize: 14)),
                        const Spacer(),
                        if (streak > 0) ...[
                          const Text("🔥", style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            "$streak day${streak == 1 ? '' : 's'}",
                            style: theme.bodyStyle.copyWith(
                              fontSize: 12,
                              color: theme.xpAccentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

  // ── Chat Section ──────────────────────────────────────────────────────────
  Widget _buildChatSection(DynamicTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: theme.onSurfaceTextColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Text("Learning Assistant",
                    style: theme.titleStyle.copyWith(fontSize: 17)),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : theme.primaryColor,
                  ),
                  onPressed: _listen,
                  tooltip: "Voice Input",
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: theme.onSurfaceTextColor.withValues(alpha: 0.08)),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length + (_isAiTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isAiTyping && index == _messages.length) {
                  return _buildTypingIndicator(theme);
                }

                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                final isAction = msg['role'] == 'system_action';

                if (isAction) return _buildActionButtons(theme, msg['text']);

                final isCurrentlyTyping = _typingMessageIndex == index;
                final displayText = isCurrentlyTyping
                    ? _typingDisplayText
                    : msg['text'].toString();

                return _buildMessageBubble(
                  context,
                  theme,
                  msg,
                  isUser,
                  displayText,
                  isCurrentlyTyping,
                  index,
                );
              },
            ),
          ),
          _buildQuickActionChips(theme),
          _buildInputArea(theme),
        ],
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
                    color: isUser ? theme.primaryColor : theme.backgroundColor,
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

                // ← Timestamp + Read aloud + Reactions
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
                      // Read aloud
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
                            Text("Read aloud",
                                style: theme.bodyStyle.copyWith(
                                  fontSize: 10,
                                  color:
                                      theme.primaryColor.withValues(alpha: 0.6),
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // ← 👍 reaction
                      GestureDetector(
                        onTap: () => setState(() {
                          _messageReactions[index] =
                              _messageReactions[index] == 'up' ? null : 'up';
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _messageReactions[index] == 'up'
                                ? theme.primaryColor.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text("👍",
                              style: TextStyle(
                                fontSize: 14,
                                color: _messageReactions[index] == 'up'
                                    ? theme.primaryColor
                                    : null,
                              )),
                        ),
                      ),
                      const SizedBox(width: 2),

                      // ← 👎 reaction
                      GestureDetector(
                        onTap: () => setState(() {
                          _messageReactions[index] =
                              _messageReactions[index] == 'down'
                                  ? null
                                  : 'down';
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _messageReactions[index] == 'down'
                                ? Colors.red.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text("👎",
                              style: TextStyle(
                                fontSize: 14,
                                color: _messageReactions[index] == 'down'
                                    ? Colors.red
                                    : null,
                              )),
                        ),
                      ),
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
        child: Text(
          displayText,
          style: theme.bodyStyle.copyWith(color: Colors.white, height: 1.5),
        ),
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
            children: parsed.map((item) {
              return _buildNeuroCard(
                item['title']?.toString() ?? '',
                item['content']?.toString() ?? '',
                item['icon']?.toString() ?? '',
                theme,
              );
            }).toList(),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: _TypingDots(color: theme.primaryColor),
          ),
        ],
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

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return GestureDetector(
            onTap: () {
              _chatController.text = chip['prompt']!;
              _sendMessage(theme);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.6)),
              ),
              child: Text(
                chip['label']!,
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Input Area ────────────────────────────────────────────────────────────
  Widget _buildInputArea(DynamicTheme theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
            top: BorderSide(
                color: theme.onSurfaceTextColor.withValues(alpha: 0.06))),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(
                color: theme.xpAccentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          Row(
            children: [
              IconButton(
                onPressed: () => _uploadDocument(context),
                icon: Icon(Icons.attach_file, color: theme.primaryColor),
                tooltip: "Upload PDF",
              ),
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: "Ask anything...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(theme),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: () => _sendMessage(theme),
                backgroundColor: theme.primaryColor,
                elevation: 0,
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ],
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
            Text("Thanks for your feedback!",
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
              Text("Rate this session",
                  style: theme.titleStyle.copyWith(fontSize: 15)),
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
                hintText: "Tell us about your experience (optional)...",
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("⭐ ${"★" * _reviewStars} — Thank you!"),
                      backgroundColor: theme.primaryColor,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text("Submit Review", style: theme.buttonTextStyle),
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
            Text("Awesome job! What's next?",
                style: theme.titleStyle.copyWith(fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _uploadDocument(context),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text("Upload More"),
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
                  label: const Text("Take Quiz"),
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
    if (_chatController.text.trim().isEmpty) return;
    final text = _chatController.text;
    await _firestoreService.saveChatMessage('user', text);
    _chatController.clear();

    setState(() => _isAiTyping = true);
    _scrollToBottom();

    try {
      final response =
          await _aiService.chatWithAI(text, theme.traits.learningProfileName);
      await _firestoreService.saveChatMessage('ai', response);

      if (mounted) {
        setState(() => _isAiTyping = false);
        final newIndex = _messages.length - 1;
        if (newIndex >= 0) {
          _startTypingAnimation(newIndex, response);
        }
      }
    } catch (e) {
      setState(() => _isAiTyping = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("AI Error: $e")));
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

  Future<void> _uploadDocument(BuildContext context) async {
    final user = _firestoreService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to upload.")));
      return;
    }

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

      if (!mounted) return;

      setState(() => _isAiTyping = true);
      final traits = Provider.of<DynamicTheme>(context, listen: false).traits;
      await _firestoreService.saveChatMessage(
          'ai', 'Reading $fileName and generating your personalised summary…');

      final String summary = await _aiService.generateAdaptiveSummary(
        extractedText,
        isADHD: traits.isADHD,
        isAutistic: traits.isAutistic,
        isDyslexic: traits.isDyslexic,
      );

      if (!mounted) return;
      setState(() => _isAiTyping = false);

      await _firestoreService.saveLearningMaterial(
        title: fileName,
        summary: summary,
        fullText: extractedText,
        fileUrl: fileUrl,
        userTraits: traits,
      );

      await _firestoreService.saveChatMessage(
          'ai', 'Here is your personalised summary for **$fileName**:');
      await _firestoreService.saveChatMessage('ai', summary);
      await _firestoreService.saveChatMessage(
          'system_action', 'prompt_upload_or_quiz');
    } catch (e) {
      setState(() => _isAiTyping = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Upload/Analyse failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildNeuroCard(
      String title, String content, String icon, DynamicTheme theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14.0),
        border:
            Border.all(color: theme.onSurfaceTextColor.withValues(alpha: 0.08)),
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
                        style: GoogleFonts.lexend(
                          textStyle: theme.titleStyle.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            MarkdownBody(
              data: content.trim(),
              styleSheet: _getMarkdownStyle(theme),
              builders: {'strong': _AdhdHighlightBuilder(theme.traits.isADHD)},
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

    return MarkdownStyleSheet(
      p: GoogleFonts.lexend(
          textStyle: theme.bodyStyle.copyWith(
              height: hght, letterSpacing: lSpacing, wordSpacing: wSpacing)),
      strong: GoogleFonts.lexend(
          textStyle: theme.bodyStyle.copyWith(
              fontWeight: FontWeight.bold,
              height: hght,
              letterSpacing: lSpacing,
              wordSpacing: wSpacing)),
      h2: GoogleFonts.lexend(
          textStyle: theme.titleStyle.copyWith(
              fontSize: 16,
              height: hght,
              letterSpacing: lSpacing,
              wordSpacing: wSpacing)),
      h3: GoogleFonts.lexend(
          textStyle: theme.titleStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: hght,
              letterSpacing: lSpacing,
              wordSpacing: wSpacing)),
      listBullet:
          GoogleFonts.lexend(textStyle: theme.bodyStyle.copyWith(height: hght)),
      blockSpacing: 10.0,
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
          final newY = (rulerY + details.delta.dy).clamp(
            0.0,
            MediaQuery.of(context).size.height - 40,
          );
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

// ── ADHD Highlight Builder ────────────────────────────────────────────────────
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
