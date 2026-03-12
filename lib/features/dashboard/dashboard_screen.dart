import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/dynamic_theme.dart';
import '../../core/services/ai_service.dart';

import '../../core/services/firestore_service.dart';
import '../quiz/assessment_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();
  final FirestoreService _firestoreService = FirestoreService();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  // Chat state
  List<Map<String, dynamic>> _messages = [];
  
  bool _isUploading = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _speechEnabled = false;
  String _extractedText = ""; 
 

  @override
  void initState() {
    super.initState();
    _initTts();
    _initStt();
    _loadChatHistory();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() {
      if(mounted) setState(() => _isSpeaking = false);
    });
  }

  void _initStt() async {
    _speechEnabled = await _speech.initialize(
      onError: (val) => debugPrint('STT Error: $val'),
      onStatus: (val) => debugPrint('STT Status: $val'),
    );
    if(mounted) setState(() {});
  }

  void _loadChatHistory() {
    _firestoreService.getChatMessages().listen((snapshot) {
       final messages = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
       if (mounted) {
         setState(() {
           _messages = messages;
           if (_messages.isEmpty) {
              _messages.add({'role': 'ai', 'text': 'Hello! I\'m your adaptive learning assistant. Upload a document to get a summary or ask me a question!'});
           }
         });
         _scrollToBottom();
       }
    });
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      if(mounted) setState(() => _isSpeaking = false);
    } else {
      if(mounted) setState(() => _isSpeaking = true);
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
            // Voice Commands
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No material to quiz on yet! Upload a PDF first.")));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => AssessmentScreen(content: _extractedText)),
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
            decoration: const InputDecoration(hintText: "How is your learning experience?"),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                // Mock review implementation
                if (reviewCtrl.text.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thanks for your feedback!")));
                }
                Navigator.pop(context);
              },
              child: const Text("Submit"),
            )
          ],
        );
      }
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final xp = data['xp'] ?? 0;
        final level = data['level'] ?? 1;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12)
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
               CircleAvatar(
                 backgroundColor: theme.primaryColor, 
                 radius: 16,
                 child: Text(level.toString(), style: const TextStyle(color: Colors.white, fontSize: 12))
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text("Level $level • $xp XP", style: theme.titleStyle.copyWith(fontSize: 14)),
                     LinearProgressIndicator(value: (xp % 500) / 500, backgroundColor: Colors.grey[300], color: theme.secondaryColor),
                   ],
                 ),
               ),
               IconButton(
                 icon: const Icon(Icons.rate_review_outlined, size: 20),
                 tooltip: "Leave Review",
                 onPressed: _showReviewDialog,
               )
            ],
          ),
        );
      }
    );
  }

  Widget _buildChatSection(DynamicTheme theme, {double? height}) {
    return Container(
      height: height ?? double.infinity,
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
                Text("Learning Assistant", style: theme.titleStyle.copyWith(fontSize: 18)),
                const Spacer(),
                if (theme.traits.isDyspraxic || true) // Always show for accessibility
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : null),
                    onPressed: _listen,
                    tooltip: "Voice Input",
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                final isAction = msg['role'] == 'system_action'; 

                if (isAction) {
                   return _buildActionButtons(theme, msg['text']);
                }

                // For the AI output, check if we need to chunk it. If it contains ### (our prompt chunk marker),
                // we'll render it as a series of cards.
                Widget messageContent;
                if (isUser) {
                  messageContent = Text(
                    msg['text'],
                    style: GoogleFonts.lexend(
                      textStyle: theme.bodyStyle.copyWith(color: Colors.white, height: 1.6, letterSpacing: 0.5)
                    ),
                  );
                } else {
                   // Try to parse JSON array
                   String rawText = msg['text'].toString().trim();
                   if (rawText.startsWith('```json')) rawText = rawText.substring(7);
                   if (rawText.startsWith('```')) rawText = rawText.substring(3);
                   if (rawText.endsWith('```')) rawText = rawText.substring(0, rawText.length - 3);
                   rawText = rawText.trim();
                   
                   try {
                     final parsed = jsonDecode(rawText);
                     if (parsed is List) {
                        messageContent = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: parsed.map((item) {
                            return _buildNeuroCard(
                              item['title']?.toString() ?? '', 
                              item['content']?.toString() ?? '', 
                              item['icon']?.toString() ?? '', 
                              theme
                            );
                          }).toList(),
                        );
                     } else {
                        messageContent = _buildStandardMarkdown(msg['text'], theme);
                     }
                   } catch (_) {
                     // Not JSON, or parsing failed, do standard fallback
                     messageContent = _buildStandardMarkdown(msg['text'], theme);
                   }
                }

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: isUser ? const EdgeInsets.all(16.0) : EdgeInsets.zero, // AI chunks bring their own padding via custom builder
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85), // Wider for Cards
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFFE3F2FD) : Colors.transparent, // Background handled by inner elements
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        messageContent,
                        if (!isUser) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _speak(msg['text']),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.volume_up, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text("Read Aloud", style: TextStyle(fontSize: 10, color: Colors.grey[600]))
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
          
          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
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
                    // Submit Document Button (Restored)
                    IconButton(
                        onPressed: () => _uploadDocument(context),
                        icon: const Icon(Icons.attach_file),
                        tooltip: "Submit Document",
                    ),
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        decoration: InputDecoration(
                          hintText: "Ask anything...",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(theme),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      onPressed: () => _sendMessage(theme),
                      backgroundColor: theme.primaryColor,
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
               Text("Awesome job! What's next?", style: theme.titleStyle.copyWith(fontSize: 16)),
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
                      style: ElevatedButton.styleFrom(backgroundColor: theme.secondaryColor, foregroundColor: Colors.black),
                    ),
                    ElevatedButton.icon(
                      onPressed: _navigateToQuiz,
                      icon: const Icon(Icons.quiz),
                      label: const Text("Take Quiz"),
                      style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white),
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
    
    // Save User Message
    await _firestoreService.saveChatMessage('user', text);
    _chatController.clear();
    
    _scrollToBottom();

    // Call AI Service
    try {
      final response = await _aiService.chatWithAI(text, theme.traits.learningProfileName);
      
      // Save AI Response
      await _firestoreService.saveChatMessage('ai', response);
      
      // Auto-speak if strict focus mode or dyspraxic? (Optional, kept manual for now to avoid annoyance)
      if (theme.traits.isDyslexic || theme.traits.isDyspraxic) {
        // Maybe toast "Tap to read"?
      }
      
    } catch (e) {
       if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Error: $e")));
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
          curve: Curves.easeOut
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
      // ── 1. Pick file — withData: true gives bytes on ALL platforms (web + native)
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

      // ── 2. Concurrent Execution: Storage Upload + Text Extraction
      String fileUrl = '';
      String extractedText = '';
      
      try {
        // Run both operations simultaneously
        final results = await Future.wait([
          _firestoreService.uploadPdfToStorage(bytes, fileName, user.uid).then((url) => url as String),
          Future(() {
            final PdfDocument document = PdfDocument(inputBytes: bytes);
            final text = PdfTextExtractor(document).extractText();
            document.dispose();
            return text;
          }),
        ]);
        
        fileUrl = results[0] as String;
        extractedText = results[1] as String;
        setState(() => _extractedText = extractedText);
      } catch (e) {
        extractedText = ''; // AI guard handles empty text with a user-facing message
      }

      if (!mounted) return;

      // \u2500\u2500 3. Trait-based adaptive summary — always call so the scanned-PDF \u2500\u2500\u2500\u2500\u2500\u2500
      //    error message flows into the chat bubble.
      final traits = Provider.of<DynamicTheme>(context, listen: false).traits;
      await _firestoreService.saveChatMessage(
        'ai', 'Reading $fileName and generating your personalised summary…');

      final String summary = await _aiService.generateAdaptiveSummary(
        extractedText,
        isADHD: traits.isADHD,
        isAutistic: traits.isAutistic,
        isDyslexic: traits.isDyslexic,
      );

      // ── 4. One-shot Firestore save (text + summary + fileUrl) ───────────────────────────
      if (!mounted) return;
      final materialId = await _firestoreService.saveLearningMaterial(
        title: fileName,
        summary: summary,
        fullText: extractedText,
        fileUrl: fileUrl,
        userTraits: traits,
      );


      if (!mounted) return;
      await _firestoreService.saveChatMessage(
        'ai', 'Here is your personalised summary for **$fileName**:');
      await _firestoreService.saveChatMessage(
        'ai', summary);
      await _firestoreService.saveChatMessage('system_action', 'prompt_upload_or_quiz');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload/Analyse failed: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Splits structured responses by header and wraps each in a visually distinct Card
  Widget _buildNeuroCard(String title, String content, String icon, DynamicTheme theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // Soft pastel background
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.grey.shade200), // Subtle border
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon.isNotEmpty) ...[
                    Text(icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.lexend(
                        textStyle: theme.titleStyle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.6,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            MarkdownBody(
              data: content.trim(),
              styleSheet: _getMarkdownStyle(theme),
              builders: {
                'strong': _AdhdHighlightBuilder(theme.traits.isADHD),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Builds standard non-chunked markdown (e.g. Chat/Errors)
  Widget _buildStandardMarkdown(String text, DynamicTheme theme) {
     return Container(
       padding: const EdgeInsets.all(16.0),
       decoration: BoxDecoration(
         color: const Color(0xFFF8FAFC),
         borderRadius: BorderRadius.circular(12),
       ),
       child: MarkdownBody(
          data: text,
          styleSheet: _getMarkdownStyle(theme),
       ),
     );
  }

  MarkdownStyleSheet _getMarkdownStyle(DynamicTheme theme) {
    // Dyslexia overrides
    final isDyslexic = theme.traits.isDyslexic;
    final double lSpacing = isDyslexic ? 1.5 : 0.5;
    final double wSpacing = isDyslexic ? 2.0 : 0.0;
    final double hght = 1.6;

    return MarkdownStyleSheet(
      p: GoogleFonts.lexend(textStyle: theme.bodyStyle.copyWith(color: Colors.black87, height: hght, letterSpacing: lSpacing, wordSpacing: wSpacing)),
      strong: GoogleFonts.lexend(textStyle: theme.bodyStyle.copyWith(color: Colors.black87, fontWeight: FontWeight.bold, height: hght, letterSpacing: lSpacing, wordSpacing: wSpacing)),
      h2: GoogleFonts.lexend(textStyle: theme.titleStyle.copyWith(fontSize: 16, color: Colors.black87, height: hght, letterSpacing: lSpacing, wordSpacing: wSpacing)),
      h3: GoogleFonts.lexend(textStyle: theme.titleStyle.copyWith(fontSize: 14, color: Colors.black87, height: hght, fontWeight: FontWeight.bold, letterSpacing: lSpacing, wordSpacing: wSpacing)),
      listBullet: GoogleFonts.lexend(textStyle: theme.bodyStyle.copyWith(color: Colors.black87, height: hght)),
      blockSpacing: 12.0,
    );
  }
}

// ── Custom Element Builders ───────────────────────────────────────────────────

/// Custom builder to render bold text with alternating highlight colors for ADHD
class _AdhdHighlightBuilder extends MarkdownElementBuilder {
  final bool isADHD;
  _AdhdHighlightBuilder(this.isADHD);

  // Counter to alternate highlights
  static int _colorIndex = 0;
  final List<Color> _highlightColors = [
    const Color(0xFFE3F2FD), // Light Blue
    const Color(0xFFFFF9C4), // Light Yellow
    const Color(0xFFE8F5E9), // Light Green
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
        child: Text(
          text.text,
          style: (preferredStyle ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      );
    }
    
    // Default bold styling if not ADHD
    return Text(
      text.text,
      style: (preferredStyle ?? const TextStyle()).copyWith(fontWeight: FontWeight.bold),
    );
  }
}
