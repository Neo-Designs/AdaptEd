import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/theme/dynamic_theme.dart';

class PdfViewerScreen extends StatelessWidget {
  final String title;
  final String url;
  final DynamicTheme theme;

  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.url,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: theme.titleStyle.copyWith(fontSize: 18)),
        backgroundColor: theme.backgroundColor,
        iconTheme: IconThemeData(color: theme.primaryColor),
        elevation: 0,
      ),
      body: url.isNotEmpty
          ? SfPdfViewer.network(
              url,
              canShowScrollHead: true,
              canShowPaginationDialog: true,
            )
          : const Center(
              child: Text("Invalid PDF URL"),
            ),
    );
  }
}