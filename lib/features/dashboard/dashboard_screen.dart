import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
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
import '../../core/utils/logger.dart';

import '../../core/services/firestore_service.dart';
import '../quiz/assessment_screen.dart';
import '../screening/scoring_engine.dart';
import '../library/library_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? initialArguments;
  const DashboardScreen({super.key, this.initialArguments});

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
  String? _activeSessionId;
  StreamSubscription<QuerySnapshot>? _chatSubscription; // Requires dart:async import (already there)
  
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

    // Check for re-summarize intent
    if (widget.initialArguments != null && widget.initialArguments!['reSummarizeText'] != null) {
       _createNewSession();
       WidgetsBinding.instance.addPostFrameCallback((_) {
          _uploadDocumentFromText(
             widget.initialArguments!['reSummarizeText'], 
             widget.initialArguments!['fileName'] ?? 'Document',
          );
       });
    } else if (widget.initialArguments != null && widget.initialArguments!['sessionId'] != null) {
       _setActiveSession(widget.initialArguments!['sessionId']);
    } else {
       _loadInitialSession();
    }
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _loadInitialSession() async {
    // Attempt to load the most recent session
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
    final newId = await _firestoreService.createChatSession(title: "New Chat");
    _setActiveSession(newId);
    await _firestoreService.saveChatMessage(newId, 'ai', 'Hello! I\'m your adaptive learning assistant. Upload a document to get a summary or ask me a question!');
  }

  void _setActiveSession(String sessionId) {
     _chatSubscription?.cancel();
     if (mounted) {
       setState(() {
          _activeSessionId = sessionId;
          _messages = [];
       });
     }
     
     _chatSubscription = _firestoreService.getChatMessages(sessionId).listen((snapshot) {
         final messages = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
         if (mounted) {
           setState(() {
             _messages = messages;
           });
           _scrollToBottom();
         }
     });
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
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
        ),
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
              onPressed: () async {
                if (reviewCtrl.text.isNotEmpty) {
                  try {
                    await FirebaseFirestore.instance.collection('reviews').add({
                      'userId': _firestoreService.currentUser?.uid,
                      'text': reviewCtrl.text,
                      'rating': 5, // Defaulting to 5 for now, can add a star picker later
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thanks for your feedback!")));
                    }
                  } catch (e) {
                     AppLogger.error("Failed to save review", error: e);
                  }
                }
                if (context.mounted) Navigator.pop(context);
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
      drawer: _buildChatsDrawer(theme),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(theme.interactivePadding),
          child: Column(
            children: [
               // Replace Profile header with a simple AppBar-like row to open drawer
               Row(
                 children: [
                   Builder(
                     builder: (ctx) => IconButton(
                       icon: const Icon(Icons.menu),
                       onPressed: () => Scaffold.of(ctx).openDrawer(),
                     ),
                   ),
                   Expanded(child: Center(child: Text("Learning Assistant", style: theme.titleStyle.copyWith(fontSize: 18)))),
                   const SizedBox(width: 48), // Balance the menu icon
                 ],
               ),
               const SizedBox(height: 8),
               if (user != null) _buildProfileHeader(theme, user.uid), 
               Expanded(child: _buildChatSection(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatsDrawer(DynamicTheme theme) {
    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20, left: 16, right: 16),
            color: theme.primaryColor,
            child: Row(
              children: [
                 const Icon(Icons.forum, color: Colors.white),
                 const SizedBox(width: 12),
                 Text("Chats", style: theme.titleStyle.copyWith(color: Colors.white, fontSize: 20)),
                 const Spacer(),
                 IconButton(
                   icon: const Icon(Icons.add, color: Colors.white),
                   onPressed: () {
                      Navigator.pop(context);
                      _createNewSession();
                   }
                 )
              ]
            )
          ),
          ListTile(
  leading: const Icon(Icons.library_books),
  title: const Text("Library"),
  onTap: () {
    Navigator.pop(context); // Close drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LibraryScreen()),
    );
  },
),
const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getChatSessions(),
              builder: (context, snapshot) {
                 if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                 final docs = snapshot.data!.docs;
                 if (docs.isEmpty) return const Center(child: Text("No chats yet."));
                 
                 return ListView.builder(
                   itemCount: docs.length,
                   itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final isSelected = _activeSessionId == data['sessionId'];
                      return ListTile(
                        selected: isSelected,
                        selectedColor: theme.primaryColor,
                        selectedTileColor: theme.primaryColor.withValues(alpha: 0.1),
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(data['title'] ?? 'New Chat', maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () {
                           Navigator.pop(context);
                           _setActiveSession(data['sessionId']);
                        },
                      );
                   }
                 );
              }
            )
          )
        ]
      )
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
            color: theme.cardColor.withValues(alpha: 0.5),
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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
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
              border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
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
    if (_chatController.text.trim().isEmpty || _activeSessionId == null) return;
    
    final text = _chatController.text;
    final sessionId = _activeSessionId!;
    
    // Set title if it's the first message
    if (_messages.where((m) => m['role'] == 'user').isEmpty) {
        final words = text.split(' ');
        final newTitle = words.take(5).join(' ') + (words.length > 5 ? '...' : '');
        FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({'title': newTitle});
    }

    // Save User Message
    await _firestoreService.saveChatMessage(sessionId, 'user', text);
    _chatController.clear();
    
    _scrollToBottom();

    // Call AI Service
    try {
      final response = await _aiService.chatWithAI(
         text, 
         theme.traits.learningProfileName,
         onWait: (msg) {
            if (mounted) _firestoreService.saveChatMessage(sessionId, 'ai', msg);
         }
      );
      
      // Save AI Response
      await _firestoreService.saveChatMessage(sessionId, 'ai', response);
      
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

    if (_activeSessionId == null) {
       _createNewSession();
       // Give it a brief moment to initialize
       await Future.delayed(const Duration(milliseconds: 300));
    }
    
    final sessionId = _activeSessionId!;

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
        extractedText = ''; // AI guard handles empty text with a user-facing message
      }

      if (!context.mounted) return;

      // ── 3. Trait-based adaptive summary — always call so the scanned-PDF ────────
      //    error message flows into the chat bubble.
      if (!context.mounted) return;
      final traits = Provider.of<DynamicTheme>(context, listen: false).traits;
      await _firestoreService.saveChatMessage(
        sessionId, 'ai', 'Reading $fileName and generating your personalised summary…');

      final String summary = await _aiService.generateAdaptiveSummary(
        extractedText,
        isADHD: traits.isADHD,
        isAutistic: traits.isAutistic,
        isDyslexic: traits.isDyslexic,
        isDyspraxic: traits.isDyspraxic,
        onWait: (msg) {
           if (mounted) _firestoreService.saveChatMessage(sessionId, 'ai', msg);
        }
      );

      // ── 4. Parse the summary and feed to UI sequentially ───────────────────────────
      if (!mounted) return;
      await _firestoreService.saveLearningMaterial(
        title: fileName,
        summary: summary,
        fullText: extractedText,
        fileUrl: fileUrl,
        userTraits: traits,
        sessionId: sessionId,
      );

      // Update session title with the PDF name
      await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
        'title': fileName, // PDF name becomes the session title
        'pdfName': fileName, // Specifically store the PDF name too
      });

      if (!mounted) return;
      await _firestoreService.saveChatMessage(
        sessionId, 'ai', 'Here is your personalised summary for **$fileName**:');
        
      try {
        // Attempt to parse the response as a JSON array
        String rawText = summary.trim();
        if (rawText.startsWith('```json')) rawText = rawText.substring(7);
        if (rawText.startsWith('```')) rawText = rawText.substring(3);
        if (rawText.endsWith('```')) rawText = rawText.substring(0, rawText.length - 3);
        rawText = rawText.trim();
        
        final List<dynamic> parsedChunks = jsonDecode(rawText);
        
        for (var chunk in parsedChunks) {
          if (!mounted) break;
          // Ensure chunk is passed as a valid JSON string map
          final chunkString = jsonEncode([chunk]); // wrapping in list to trick the existing UI parser
          await _firestoreService.saveChatMessage(sessionId, 'ai', chunkString);
          await Future.delayed(const Duration(milliseconds: 1000));
        }

      } catch (e) {
        // Fallback if parsing fails - just save the raw text
        if (!mounted) return;
        await _firestoreService.saveChatMessage(sessionId, 'ai', summary);
      }

      await _firestoreService.saveChatMessage(sessionId, 'system_action', 'prompt_upload_or_quiz');

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload/Analyse failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadDocumentFromText(String extractedText, String fileName) async {
    final user = _firestoreService.currentUser;
    if (user == null || _activeSessionId == null) return;
    
    final sessionId = _activeSessionId!;
    setState(() => _isUploading = true);

    if (!mounted) return;
    final traits = Provider.of<DynamicTheme>(context, listen: false).traits;
    
    await _firestoreService.saveChatMessage(sessionId, 'ai', 'Re-analyzing $fileName for a new summary...');

    try {
      final String summary = await _aiService.generateAdaptiveSummary(
        extractedText,
        isADHD: traits.isADHD,
        isAutistic: traits.isAutistic,
        isDyslexic: traits.isDyslexic,
        isDyspraxic: traits.isDyspraxic,
        onWait: (msg) {
           if (mounted) _firestoreService.saveChatMessage(sessionId, 'ai', msg);
        }
      );

      if (!mounted) return;
      
      // Update session title
      FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({'title': 'Re-Summary: $fileName'});

      await _firestoreService.saveChatMessage(sessionId, 'ai', 'Here is your re-generated summary for **$fileName**:');
        
      try {
        String rawText = summary.trim();
        if (rawText.startsWith('```json')) rawText = rawText.substring(7);
        if (rawText.startsWith('```')) rawText = rawText.substring(3);
        if (rawText.endsWith('```')) rawText = rawText.substring(0, rawText.length - 3);
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
      await _firestoreService.saveChatMessage(sessionId, 'system_action', 'prompt_upload_or_quiz');

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Re-summarize failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Splits structured responses by header and wraps each in a visually distinct Card
  Widget _buildNeuroCard(String title, String content, String icon, DynamicTheme theme) {
    // Determine Background Color
    Color bgColor = const Color(0xFFF8FAFC);
    if (theme.traits.isADHD) {
      bgColor = const Color(0xFFFDF2F2); // Light Pastel Red/Pink
    } else if (theme.traits.isAutistic) {
      bgColor = const Color(0xFFF0F4FF); // Light Pastel Blue
    }

    // Determine Typography
    TextStyle baseTextStyle;
    if (theme.traits.isDyslexic) {
      baseTextStyle = const TextStyle(
        fontFamily: 'OpenDyslexic',
        height: 1.6,
        color: Colors.black87,
      );
    } else {
      baseTextStyle = GoogleFonts.lexend(
        textStyle: const TextStyle(
          height: 1.6,
          color: Colors.black87,
        )
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: bgColor,
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
                      style: baseTextStyle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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

  /// Builds standard non-chunked markdown (e.g. Chat/Errors)
  Widget _buildStandardMarkdown(String text, DynamicTheme theme) {
   return Container(
     padding: const EdgeInsets.all(16.0),
     decoration: BoxDecoration(
       color: const Color(0xFFF8FAFC),
       borderRadius: BorderRadius.circular(12),
     ),
     child: TypewriterMarkdown(
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

    TextStyle baseTextStyle;
    if (isDyslexic) {
      baseTextStyle = TextStyle(
        fontFamily: 'OpenDyslexic',
        color: Colors.black87,
        height: hght,
        letterSpacing: lSpacing,
        wordSpacing: wSpacing,
      );
    } else {
      baseTextStyle = GoogleFonts.lexend(
        textStyle: theme.bodyStyle.copyWith(
          color: Colors.black87, 
          height: hght, 
          letterSpacing: lSpacing, 
          wordSpacing: wSpacing
        )
      );
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

// ── Custom Element Builders ───────────────────────────────────────────────────

class _HighlightBuilder extends MarkdownElementBuilder {
  final UserTraits traits;
  _HighlightBuilder(this.traits);

  @override
  Widget visitText(text, TextStyle? preferredStyle) {
    // Default yellow highlight for bold text
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Colors.yellow.withValues(alpha: 0.3), // using withValues per deprecation
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        text.text,
        style: (preferredStyle ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

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
  String _displayedText = "";
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
      _displayedText = "";
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
