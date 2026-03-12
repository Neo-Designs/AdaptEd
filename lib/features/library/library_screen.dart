import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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

      if (!mounted) return;
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
        
        fileUrl = results[0] as String;
        extractedText = results[1] as String;
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✓ $fileName added to your library!")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")));
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
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         child: ExpansionTile(
                           leading: Icon(Icons.picture_as_pdf, color: theme.primaryColor),
                           title: Text(data['title'] ?? 'Untitled', style: theme.bodyStyle.copyWith(fontWeight: FontWeight.bold)),
                           subtitle: Text("Generated for: ${data['adaptationMetadata']?['generatedFor'] ?? 'You'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                           children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                              // MarkdownBody renders bold, bullets, headings from AI output
                              child: MarkdownBody(
                                data: data['summary'] ?? 'No summary available.',
                                styleSheet: MarkdownStyleSheet(
                                  p: theme.bodyStyle,
                                  h2: theme.titleStyle.copyWith(fontSize: 16),
                                  listBullet: theme.bodyStyle,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.quiz_outlined),
                              label: const Text("Take Quiz on this Material"),
                            ),
                          ],
                         ),
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
          border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
          boxShadow: [
             BoxShadow(color: theme.primaryColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
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
}
