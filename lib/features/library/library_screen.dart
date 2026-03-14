import 'dart:typed_data';

import 'package:adapted/core/services/ai_service.dart';
import 'package:adapted/core/services/firestore_service.dart';
import 'package:adapted/core/theme/dynamic_theme.dart';
import 'package:adapted/core/widgets/adapted_card.dart'; // ← NEW
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Processing $fileName — generating summary…")));

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
      } catch (e) {
        extractedText = '';
      }

      final traits = theme.traits;
      final String summary = await _aiService.generateAdaptiveSummary(
        extractedText,
        isADHD: traits.isADHD,
        isAutistic: traits.isAutistic,
        isDyslexic: traits.isDyslexic,
      );

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DynamicTheme>(); // ← watch for reactivity

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
                Text("Your Library",
                    style: theme.titleStyle.copyWith(fontSize: 24)),
                if (_isUploading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.primaryColor, // ← theme-aware
                    ),
                  ),
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
                    return Center(
                      child:
                          CircularProgressIndicator(color: theme.primaryColor),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        "No documents uploaded yet.",
                        style: theme.bodyStyle.copyWith(
                          color:
                              theme.onSurfaceTextColor.withValues(alpha: 0.5),
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      // ← AdaptedCard wraps each library item
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdaptedCard(
                          child: ExpansionTile(
                            leading: Icon(Icons.picture_as_pdf,
                                color: theme.primaryColor),
                            title: Text(
                              data['title'] ?? 'Untitled',
                              style: theme.bodyStyle
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "Generated for: ${data['adaptationMetadata']?['generatedFor'] ?? 'You'}",
                              style: theme.bodyStyle.copyWith(
                                fontSize: 12,
                                color: theme.onSurfaceTextColor
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                child: MarkdownBody(
                                  data: data['summary'] ??
                                      'No summary available.',
                                  styleSheet: MarkdownStyleSheet(
                                    p: theme.bodyStyle,
                                    h2: theme.titleStyle.copyWith(fontSize: 16),
                                    listBullet: theme.bodyStyle,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {},
                                icon: Icon(Icons.quiz_outlined,
                                    color: theme.primaryColor),
                                label: Text(
                                  "Take Quiz on this Material",
                                  style: TextStyle(color: theme.primaryColor),
                                ),
                              ),
                            ],
                          ),
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
      // ← AdaptedCard handles decoration automatically
      child: AdaptedCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(Icons.upload_file, color: theme.primaryColor, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Upload Document",
                    style: theme.titleStyle.copyWith(fontSize: 18)),
                Text(
                  "Tap to upload PDF for summarization",
                  style: theme.bodyStyle.copyWith(
                    fontSize: 14,
                    color: theme.onSurfaceTextColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
