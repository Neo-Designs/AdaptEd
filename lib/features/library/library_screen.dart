import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/dynamic_theme.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/ai_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AIService _aiService = AIService();
  bool _isUploading = false;

  Future<void> _uploadDocument(BuildContext context, DynamicTheme theme) async {
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

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Processing $fileName — generating summary…")));

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
      } catch (e) {
        extractedText = ''; // AI guard handles empty/short text with a user-facing message
      }

      // ── 3. Trait-based adaptive AI summary (RAG trigger) ──────────────────
      final traits = theme.traits;
      // generateAdaptiveSummary handles the < 10 char case internally and
      // returns the formatted scanned-PDF error message, so we always call it.
      final String summary = await _aiService.generateAdaptiveSummary(
        extractedText,
        isADHD: traits.isADHD,
        isAutistic: traits.isAutistic,
        isDyslexic: traits.isDyslexic,
      );

      // ── 4. One-shot Firestore save (text + fileUrl) ────────────────
      await _firestoreService.saveLearningMaterial(
        title: fileName,
        summary: summary,
        fullText: extractedText,
        fileUrl: fileUrl,
        userTraits: traits,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✓ $fileName added to your library!")));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DynamicTheme>(context);
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text("Your Library", style: theme.titleStyle.copyWith(fontSize: 24)),
                 if (_isUploading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
               ],
             ),
             const SizedBox(height: 16),
             _buildUploadCard(context, theme),
             const SizedBox(height: 24),
             Expanded(
               child: StreamBuilder<QuerySnapshot>(
                 stream: _firestoreService.getLearningMaterials(),
                 builder: (context, snapshot) {
                   if (snapshot.connectionState == ConnectionState.waiting) {
                     return const Center(child: CircularProgressIndicator());
                   }
                   if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                     return Center(
                       child: Text(
                         "No documents uploaded yet.",
                         style: theme.bodyStyle.copyWith(color: Colors.grey),
                       ),
                     );
                   }

                   final docs = snapshot.data!.docs;
                   return ListView.builder(
                     itemCount: docs.length,
                     itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                  Row(
                                     children: [
                                        Icon(Icons.picture_as_pdf, color: theme.primaryColor, size: 28),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(data['title'] ?? 'Untitled', style: theme.titleStyle.copyWith(fontSize: 16)),
                                              const SizedBox(height: 4),
                                              Text("Added: ${_formatDate(data['createdAt'])}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                            ],
                                          )
                                        ),
                                     ]
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                     mainAxisAlignment: MainAxisAlignment.end,
                                     children: [
                                        TextButton.icon(
                                           onPressed: () {
                                              Navigator.pushReplacementNamed(
                                                 context, 
                                                 '/dashboard',
                                                 arguments: {
                                                    'reSummarizeText': data['fullText'],
                                                    'fileName': data['title'] ?? 'Document'
                                                 }
                                              );
                                           },
                                           icon: const Icon(Icons.refresh),
                                           label: const Text("Re-summarize"),
                                           style: TextButton.styleFrom(foregroundColor: theme.primaryColor),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                           onPressed: () {
                                              _showSummaryModal(context, data['title'] ?? 'Summary', data['summary'] ?? '', theme);
                                           },
                                           icon: const Icon(Icons.auto_awesome),
                                           label: const Text("View Summary")
                                        )
                                     ]
                                  )
                               ]
                            )
                          )
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

  Widget _buildUploadCard(BuildContext context, DynamicTheme theme) {
    return InkWell(
      onTap: () => _uploadDocument(context, theme),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
          boxShadow: [
             BoxShadow(color: theme.primaryColor.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.upload_file, color: theme.primaryColor, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Upload Document", style: theme.titleStyle.copyWith(fontSize: 18)),
                Text("Tap to upload PDF for summarization", style: theme.bodyStyle.copyWith(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
     if (timestamp == null) return "Unknown date";
     if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return "${date.day}/${date.month}/${date.year}";
     }
     return "Unknown date";
  }

  void _showSummaryModal(BuildContext context, String title, String summary, DynamicTheme theme) {
      showModalBottomSheet(
         context: context,
         isScrollControlled: true,
         backgroundColor: Colors.transparent,
         builder: (ctx) {
            return Container(
               height: MediaQuery.of(context).size.height * 0.85,
               decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
               ),
               padding: const EdgeInsets.all(24),
               child: Column(
                  children: [
                     Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Expanded(child: Text(title, style: theme.titleStyle.copyWith(fontSize: 20), maxLines: 2, overflow: TextOverflow.ellipsis)),
                           IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))
                        ]
                     ),
                     const Divider(),
                     const SizedBox(height: 8),
                     Expanded(
                        child: SingleChildScrollView(
                           child: _parseAndRenderSummary(summary, theme)
                        )
                     )
                  ]
               )
            );
         }
      );
  }

  Widget _parseAndRenderSummary(String summary, DynamicTheme theme) {
      try {
        String rawText = summary.trim();
        if (rawText.startsWith('```json')) rawText = rawText.substring(7);
        if (rawText.startsWith('```')) rawText = rawText.substring(3);
        if (rawText.endsWith('```')) rawText = rawText.substring(0, rawText.length - 3);
        rawText = rawText.trim();
        
        final parsed = jsonDecode(rawText);
        if (parsed is List) {
           return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: parsed.map((item) {
                  return _buildNeuroCard(
                    item['title']?.toString() ?? '', 
                    item['content']?.toString() ?? '', 
                    item['icon']?.toString() ?? '', 
                    theme
                  );
              }).toList()
           );
        }
      } catch (_) {}
      
      return MarkdownBody(
          data: summary,
          styleSheet: MarkdownStyleSheet(
            p: theme.bodyStyle,
            h2: theme.titleStyle.copyWith(fontSize: 16),
            listBullet: theme.bodyStyle,
          ),
      );
  }

  Widget _buildNeuroCard(String title, String content, String icon, DynamicTheme theme) {
    Color bgColor = const Color(0xFFF8FAFC);
    if (theme.traits.isADHD) {
      bgColor = const Color(0xFFFDF2F2); 
    } else if (theme.traits.isAutistic) {
      bgColor = const Color(0xFFF0F4FF); 
    }

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
        border: Border.all(color: Colors.grey.shade200),
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
                     Text(icon, style: const TextStyle(fontSize: 24)),
                     const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: baseTextStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            MarkdownBody(
              data: content,
              styleSheet: MarkdownStyleSheet(
                p: baseTextStyle,
                strong: baseTextStyle.copyWith(fontWeight: FontWeight.bold),
                listBullet: baseTextStyle,
                blockSpacing: 12.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
