import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/theme/dynamic_theme.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/gamification_service.dart';
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

  bool _isInitializingStt = false;
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
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() {
      if(mounted) setState(() => _isSpeaking = false);
    });
  }

  void _initStt() async {
  if (_isInitializingStt) return; // Exit if already initializing
  
  _isInitializingStt = true; 
  try {
    _speechEnabled = await _speech.initialize(
      onError: (val) {
        debugPrint('STT Error: $val');
        _isInitializingStt = false; // Reset on error
      },
      onStatus: (val) {
        debugPrint('STT Status: $val');
        if (val == 'done' || val == 'notListening') _isInitializingStt = false;
      },
    );
  } catch (e) {
    debugPrint("STT Init Failed: $e");
  } finally {
    _isInitializingStt = false;
    if (mounted) setState(() {});
  }
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
    if (_isInitializingStt) return;
    if (!_speechEnabled) {
      _initStt();
          return;
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

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? theme.primaryColor : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['text'],
                          style: theme.bodyStyle.copyWith(
                            color: isUser ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (!isUser) ...[
                           const SizedBox(height: 4),
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
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You must be logged in to upload.")));
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
        
        // 1. Extract Text
        String extractedText = "";
        try {
          extractedText = await ReadPdfText.getPDFtext(file.path);
          setState(() {
            _extractedText = extractedText; 
          });
        } catch (e) {
          extractedText = "Could not extract text. Ensure it is a text-based PDF.";
        }

        // 2. Upload to Firebase
        String filePath = 'uploads/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
        await FirebaseStorage.instance.ref(filePath).putFile(file);

        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Uploaded $fileName. Analyzing...")));
        
        // 3. Generate Summary
        final traits = Provider.of<DynamicTheme>(context, listen: false).traits;
        await _firestoreService.saveChatMessage('ai', "Compiling summary for $fileName...");

        if (extractedText.length > 50) {
           final summary = await _aiService.generateSummary(extractedText, learningStyle: traits.learningProfileName);
           
           final materialId = await _firestoreService.saveLearningMaterial(
              title: fileName, 
              summary: summary, 
              fullText: extractedText, 
              userTraits: traits
           );
           _currentMaterialId = materialId;

           await _firestoreService.saveChatMessage('ai', "Here is the summary:\n\n$summary");
           await _firestoreService.saveChatMessage('system_action', 'prompt_upload_or_quiz');

        } else {
           await _firestoreService.saveChatMessage('ai', "The document appears to be empty or image-based. I couldn't read the text.");
        }
      }
    } catch (e) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload/Analyze failed: $e")));
    } finally {
      if(mounted) setState(() => _isUploading = false);
    }
  }
}
