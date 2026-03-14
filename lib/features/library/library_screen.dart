import 'dart:typed_data';

import 'package:adapted/core/services/ai_service.dart';
import 'package:adapted/core/services/firestore_service.dart';
import 'package:adapted/core/theme/dynamic_theme.dart';
import 'package:adapted/core/widgets/adapted_card.dart';
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
  String _searchQuery = '';

  // ── Generate topic tags from filename + summary ───────────────────────────
  List<String> _generateTags(Map<String, dynamic> data) {
    final List<String> tags = [];
    final title = (data['title'] ?? '').toString().toLowerCase();
    final summary = (data['summary'] ?? '').toString().toLowerCase();
    final combined = '$title $summary';

    final tagMap = {
      'Math': ['math', 'algebra', 'calculus', 'geometry', 'equation'],
      'Science': ['science', 'biology', 'chemistry', 'physics', 'molecule'],
      'History': ['history', 'war', 'century', 'ancient', 'civilization'],
      'English': ['english', 'literature', 'grammar', 'essay', 'poem'],
      'Computer': ['computer', 'programming', 'algorithm', 'code', 'software'],
      'Psychology': ['psychology', 'behavior', 'mind', 'cognitive', 'mental'],
      'Business': [
        'business',
        'marketing',
        'finance',
        'economics',
        'management'
      ],
      'Medicine': ['medicine', 'health', 'disease', 'treatment', 'clinical'],
    };

    for (final entry in tagMap.entries) {
      if (entry.value.any((keyword) => combined.contains(keyword))) {
        tags.add(entry.key);
      }
    }

    // Always add PDF tag
    if (title.endsWith('.pdf')) tags.add('PDF');

    return tags.isEmpty ? ['Document'] : tags.take(3).toList();
  }

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
    final theme = context.watch<DynamicTheme>();

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
                      color: theme.primaryColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ← Search bar
            TextField(
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search documents...",
                hintStyle: theme.bodyStyle.copyWith(
                  color: theme.onSurfaceTextColor.withValues(alpha: 0.4),
                ),
                prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.cardColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            _buildUploadCard(context, theme),
            const SizedBox(height: 16),

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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.library_books_outlined,
                              size: 48,
                              color: theme.onSurfaceTextColor
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            "No documents uploaded yet.",
                            style: theme.bodyStyle.copyWith(
                              color: theme.onSurfaceTextColor
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Filter by search
                  final docs = snapshot.data!.docs.where((doc) {
                    if (_searchQuery.isEmpty) return true;
                    final data = doc.data() as Map<String, dynamic>;
                    final title =
                        (data['title'] ?? '').toString().toLowerCase();
                    return title.contains(_searchQuery);
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        "No results for \"$_searchQuery\"",
                        style: theme.bodyStyle.copyWith(
                          color:
                              theme.onSurfaceTextColor.withValues(alpha: 0.5),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final tags = _generateTags(data);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdaptedCard(
                          child: ExpansionTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color:
                                    theme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.picture_as_pdf,
                                  color: theme.primaryColor, size: 20),
                            ),
                            title: Text(
                              data['title'] ?? 'Untitled',
                              style: theme.bodyStyle
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "For: ${data['adaptationMetadata']?['generatedFor'] ?? 'You'}",
                                  style: theme.bodyStyle.copyWith(
                                    fontSize: 11,
                                    color: theme.onSurfaceTextColor
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // ← Topic tags
                                Wrap(
                                  spacing: 6,
                                  children: tags.map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: theme.primaryColor
                                              .withValues(alpha: 0.3),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        tag,
                                        style: theme.bodyStyle.copyWith(
                                          fontSize: 10,
                                          color: theme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
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
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextButton.icon(
                                  onPressed: () {},
                                  icon: Icon(Icons.quiz_outlined,
                                      color: theme.primaryColor),
                                  label: Text(
                                    "Take Quiz on this Material",
                                    style: TextStyle(color: theme.primaryColor),
                                  ),
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
                  Icon(Icons.upload_file, color: theme.primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Upload Document",
                      style: theme.titleStyle.copyWith(fontSize: 16)),
                  Text(
                    "Tap to upload PDF — auto-tagged & summarized",
                    style: theme.bodyStyle.copyWith(
                      fontSize: 13,
                      color: theme.onSurfaceTextColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline, color: theme.primaryColor, size: 24),
          ],
        ),
      ),
    );
  }
}
