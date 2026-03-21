import 'dart:io';
import 'package:adapted/core/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/theme/dynamic_theme.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/gamification_service.dart';
import '../../core/services/firestore_service.dart';
import '../quiz/assessment_screen.dart';
import '../../core/services/user_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  final GlobalKey _progressKey = GlobalKey();
  final GlobalKey _chatKey = GlobalKey();
  final GlobalKey _voiceKey = GlobalKey();
  final GlobalKey _uploadKey = GlobalKey();
  final GlobalKey _sendKey = GlobalKey();
  final GlobalKey _summaryKey = GlobalKey();

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();
  final FirestoreService _firestoreService = FirestoreService();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final GamificationService _gamificationService = GamificationService();

  List<Map<String, dynamic>> _messages = [];

  bool _isUploading = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _speechEnabled = false;
  String _extractedText = "";
  String? _currentMaterialId;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initStt();
    _loadChatHistory();
    _handleDailyLogin();
  }

  Future<void> _handleDailyLogin() async {
    await _gamificationService.handleEvent('daily_login');

    // Check if streak was reset and show friendly message
    if (!mounted) return;
    final doc = await _gamificationService.getUserStats().first;
    final data = doc.data() as Map<String, dynamic>?;
    if (data != null && data['streak'] == 1 && mounted) {
      final lastLogin = data['last_login_date'] as Timestamp?;
      if (lastLogin != null) {
        final daysSince = DateTime.now()
            .difference(lastLogin.toDate())
            .inDays;
        if (daysSince > 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Welcome back! Your streak reset — start a new one today! 🔥"),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userService = Provider.of<UserService>(context);

    if (userService.manualTutorialTrigger) {
      userService.clearTutorialTrigger();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            try {
              ShowCaseWidget.of(context).startShowCase([
                _progressKey,
                _chatKey,
                _summaryKey,
                _uploadKey,
                _voiceKey,
                _sendKey,
              ]);
            } catch (e) {
              debugPrint('Tutorial could not start: $e');
            }
          });
        });
      });
    }
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
      if (!mounted) return;
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
              'Hello! I\'m your learning assistant 👋 Upload a PDF using the 📎 button below and I\'ll summarise it for you!'
            });
          }
        });
        _scrollToBottom();
      }
    });
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
    if (!_speechEnabled) {
      await _speech.initialize();
    }

    if (_speech.isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          setState(() {
            _chatController.text = val.recognizedWords;
          });

          if (val.hasConfidenceRating && val.confidence > 0) {
            String command = val.recognizedWords.toLowerCase();
            if (command.contains("upload")) {
              _speech.stop();
              _uploadDocument(context);
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        localeId: "en_US",
        onSoundLevelChange: (level) {},
        cancelOnError: true,
        partialResults: true,
      );
    }
  }

  void _navigateToQuiz() {
    if (_extractedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
          Text("No material to quiz on yet! Upload a PDF first.")));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (context) =>
              AssessmentScreen(content: _extractedText)),
    );
  }

  void _showReviewDialog() {
    showDialog(
        context: context,
        builder: (context) {
          final reviewCtrl = TextEditingController();
          return AlertDialog(
            title: const Text("Leave a Review"),
            content: TextField(
              controller: reviewCtrl,
              decoration: const InputDecoration(
                  hintText: "How is your learning experience?"),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (reviewCtrl.text.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Thanks for your feedback!")));
                  }
                  Navigator.pop(context);
                },
                child: const Text("Submit"),
              )
            ],
          );
        });
  }

  void _showBadgeDialog(List<String> badges) {
    if (badges.isEmpty || !mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text("🏆 Badge Earned!",
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events,
                color: Colors.amber, size: 60),
            const SizedBox(height: 12),
            Text(
              "You earned the '${badges.first}' badge!",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (badges.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                "and ${badges.length - 1} more!",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: Colors.grey),
              ),
            ]
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text("Awesome! 🎉"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DynamicTheme>(context);
    final user = _firestoreService.currentUser;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(theme.interactivePadding),
          child: Column(
            children: [
              if (user != null) _buildProfileHeader(theme, user.uid),
              Expanded(child: _buildChatSection(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(DynamicTheme theme, String uid) {
    return Showcase(
      key: _progressKey,
      title: 'Progress Tracker',
      description:
      'Track your XP and Level here. You get XP for uploading materials and taking quizzes!',
      child: StreamBuilder<DocumentSnapshot>(
        stream: _gamificationService.getUserStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              height: 70,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: LinearProgressIndicator()),
            );
          }
          final data =
          snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) return const SizedBox.shrink();

          final totalXP = data['total_xp'] ?? 20;
          final level = data['level'] ?? 1;
          final streak = data['streak'] ?? 0;
          double progressInLevel = (totalXP % 500) / 500.0;

          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4)
              ],
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.primaryColor,
                  radius: 20,
                  child: Text(level.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Level $level",
                              style: theme.titleStyle
                                  .copyWith(fontSize: 14)),
                          Text("$totalXP Total XP",
                              style: theme.bodyStyle.copyWith(
                                  fontSize: 12,
                                  color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progressInLevel.clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                              theme.primaryColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              "${(totalXP % 500)} / 500 XP to next level",
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey)),
                          // Streak display
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                color: streak > 0
                                    ? Colors.orange
                                    : Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "$streak day streak",
                                style: theme.bodyStyle.copyWith(
                                    fontSize: 12,
                                    color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatSection(DynamicTheme theme, {double? height}) {
    return Showcase(
      key: _chatKey,
      title: 'Learning Assistant',
      description:
      'This is your AI study buddy! You can ask questions about your documents here.',
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 20),
                  const SizedBox(width: 8),
                  Text("Learning Assistant",
                      style:
                      theme.titleStyle.copyWith(fontSize: 18)),
                  const Spacer(),
                  Showcase(
                    key: _voiceKey,
                    title: 'Voice Input',
                    description:
                    'Too tired to type? Tap the mic and just speak your questions!',
                    child: IconButton(
                      icon: Icon(
                          _isListening
                              ? Icons.mic
                              : Icons.mic_none,
                          color:
                          _isListening ? Colors.red : null),
                      onPressed: _listen,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Chat messages
            Expanded(
              child: Showcase(
                key: _summaryKey,
                title: 'AI Summaries',
                description:
                'When you upload a PDF, I will automatically generate a summary here in the chat!',
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg['role'] == 'user';
                    final isAction =
                        msg['role'] == 'system_action';

                    if (isAction) {
                      return _buildActionButtons(
                          theme, msg['text']);
                    }

                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin:
                        const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        constraints: BoxConstraints(
                            maxWidth:
                            MediaQuery.of(context).size.width *
                                0.75),
                        decoration: BoxDecoration(
                          color: isUser
                              ? theme.primaryColor
                              : Colors.grey[100],
                          borderRadius:
                          BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['text'],
                              style: theme.bodyStyle.copyWith(
                                color: isUser
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            if (!isUser) ...[
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () =>
                                    _speak(msg['text']),
                                child: Row(
                                  mainAxisSize:
                                  MainAxisSize.min,
                                  children: [
                                    Icon(Icons.volume_up,
                                        size: 14,
                                        color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text("Read Aloud",
                                        style: TextStyle(
                                            fontSize: 10,
                                            color:
                                            Colors.grey[600]))
                                  ],
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Input area
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(
                        color: Colors.grey.withOpacity(0.1))),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  if (_isUploading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(),
                    ),
                  Row(
                    children: [
                      Showcase(
                        key: _uploadKey,
                        title: 'Upload Materials',
                        description:
                        'Click here to upload your PDFs.',
                        child: IconButton(
                          onPressed: () =>
                              _uploadDocument(context),
                          icon: const Icon(Icons.attach_file),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          decoration: InputDecoration(
                            hintText: "Ask anything...",
                            border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(30),
                                borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12),
                          ),
                          onSubmitted: (_) =>
                              _sendMessage(theme),
                          maxLines: null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Showcase(
                        key: _sendKey,
                        title: 'Send Message',
                        description:
                        'Tap here to send your question to the AI.',
                        child: FloatingActionButton.small(
                          onPressed: () => _sendMessage(theme),
                          backgroundColor: theme.primaryColor,
                          child: const Icon(Icons.send,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(DynamicTheme theme, String type) {
    if (type == 'prompt_upload_or_quiz') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              Text("Awesome job! What's next?",
                  style: theme.titleStyle.copyWith(fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _uploadDocument(context),
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Upload More"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: theme.secondaryColor,
                        foregroundColor: Colors.black),
                  ),
                  ElevatedButton.icon(
                    onPressed: _navigateToQuiz,
                    icon: const Icon(Icons.quiz),
                    label: const Text("Take Quiz"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white),
                  )
                ],
              )
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _sendMessage(DynamicTheme theme) async {
    if (_chatController.text.trim().isEmpty) return;

    final text = _chatController.text;
    await _firestoreService.saveChatMessage('user', text);
    _chatController.clear();
    _scrollToBottom();

    try {
      final response = await _aiService.chatWithAI(
          text, theme.traits.learningProfileName);
      await _firestoreService.saveChatMessage('ai', response);
    } catch (e) {
      if (mounted) {
        await _firestoreService.saveChatMessage('ai',
            "Sorry, I had a little trouble with that. Could you try asking me again?");
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
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _uploadDocument(BuildContext context) async {
    final user = _firestoreService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
          Text("You must be logged in to upload.")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;

        String extractedText = "";
        try {
          extractedText =
          await ReadPdfText.getPDFtext(file.path);
          setState(() => _extractedText = extractedText);
        } catch (e) {
          extractedText =
          "Could not extract text. Ensure it is a text-based PDF.";
        }

        String filePath =
            'uploads/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
        await FirebaseStorage.instance
            .ref(filePath)
            .putFile(file);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
            Text("Uploaded $fileName. Analyzing...")));

        final traits =
            Provider.of<DynamicTheme>(context, listen: false)
                .traits;
        await _firestoreService.saveChatMessage(
            'ai', "Compiling summary for $fileName...");

        if (extractedText.length > 50) {
          final summary = await _aiService.generateSummary(
              extractedText,
              learningStyle: traits.learningProfileName);

          final materialId =
          await _firestoreService.saveLearningMaterial(
              title: fileName,
              summary: summary,
              fullText: extractedText,
              userTraits: traits);
          _currentMaterialId = materialId;

          // Handle event and show badge dialog if earned
          final earnedBadges = await _gamificationService
              .handleEvent('revision');
          if (mounted && earnedBadges.isNotEmpty) {
            _showBadgeDialog(earnedBadges);
          }

          await _firestoreService.saveChatMessage(
              'ai', "Here is the summary:\n\n$summary");
          await _firestoreService.saveChatMessage(
              'system_action', 'prompt_upload_or_quiz');
        } else {
          await _firestoreService.saveChatMessage('ai',
              "The document appears to be empty or image-based. I couldn't read the text.");
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload/Analyze failed: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _startTutorial() {
    ShowCaseWidget.of(context).startShowCase([
      _progressKey,
      _chatKey,
      _summaryKey,
      _uploadKey,
      _voiceKey,
      _sendKey,
    ]);
  }
}