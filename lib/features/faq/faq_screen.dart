import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/dynamic_theme.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DynamicTheme>(context);
    
    final faqs = [
      {
        'q': "What is AdaptEd?",
        'a': "AdaptEd is a neuro-inclusive learning platform that adapts its interface and AI tutoring style to your unique learning profile."
      },
      {
        'q': "How does the quiz help?",
        'a': "The quiz identifies your learning traits (Visual, Auditory, etc.) and preferences, allowing us to customize font sizes, colors, and content structure."
      },
      {
        'q': "Can I change my learning profile?",
        'a': "Yes! You can retake the quiz anytime from your Profile page to update your preferences."
      },
      {
        'q': "What files can I upload?",
        'a': "Currently, we support PDF documents. Our AI will summarize them according to your learning style."
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: faqs.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ExpansionTile(
            title: Text(faqs[index]['q']!, style: theme.titleStyle.copyWith(fontSize: 16)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(faqs[index]['a']!, style: theme.bodyStyle),
              )
            ],
          ),
        );
      },
    );
  }
}
