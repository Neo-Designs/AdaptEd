import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';

class AIService {
  // --- SYNC PROMPTS WITH FIRESTORE ---
  Future<void> initializePrompts() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('ai_prompts')
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          if (data['summaryPrompt'] != null)
            summaryPrompt = data['summaryPrompt'];
          if (data['chatbotPersonaPrompt'] != null)
            chatbotPersonaPrompt = data['chatbotPersonaPrompt'];
          AppLogger.info('Prompts initialized from Firestore',
              tag: 'AIService');
        }
      }
    } catch (e) {
      AppLogger.error('Failed to initialize prompts from Firestore',
          tag: 'AIService', error: e);
    }
  }

  // --- API KEYS ---
  static String get _groqApiKey => dotenv.env['GROQ_API_KEY'] ?? "";
  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? "";

  // --- PROMPTS ---
  static String summaryPrompt =
      "You are an expert educational assistant designed to help neurodivergent users learn. "
      "Analyze the following text and provide a summary. "
      "The summary should be structured, easy to read, and highlight key points. ";

  static String chatbotPersonaPrompt =
      "You are AdaptEd AI, a friendly and patient learning companion. "
      "You help users understanding complex topics. "
      "Keep answers concise but helpful. Break information into bite-sized chunks using bullet points and short paragraphs. Adaptation style: ";

  // --- METHODS ---

  static void updateSummaryPrompt(String newPrompt) {
    summaryPrompt = newPrompt;
    AppLogger.info('Summary prompt updated', tag: 'AIService');
  }

  static void updateChatbotPrompt(String newPrompt) {
    chatbotPersonaPrompt = newPrompt;
    AppLogger.info('Chatbot prompt updated', tag: 'AIService');
  }

  /// Generates a summary for the given text.
  Future<String> generateSummary(String content,
      {String learningStyle = "General"}) async {
    final prompt =
        "$summaryPrompt\n\nTarget Audience Style: $learningStyle\n\nContent:\n$content";

    try {
      return await _callGroqAPI(prompt);
    } catch (e, stack) {
      AppLogger.error('Summary generation failed',
          tag: 'AIService', error: e, stackTrace: stack);
      return "Error generating summary. Please try again later.";
    }
  }

  /// Generates a neurodivergent-adapted summary using Grounded Context Injection.
  ///
  /// The extracted text is wrapped in delimiters so the model has a clear
  /// "Source of Truth" and never apologises for not being able to read a file.
  Future<String> generateAdaptiveSummary(
    String content, {
    required bool isADHD,
    required bool isAutistic,
    required bool isDyslexic,
    bool isDyspraxic = false,
    bool useGemini = true,
    void Function(String)? onWait,
  }) async {
    // ── Error guard: catch scanned / image-only PDFs early ─────────────────
    if (content.trim().length < 10) {
      return '⚠️ **Could not read this PDF.**\n\n'
          'This document appears to be a scanned image rather than a text-based PDF. '
          'Please try a PDF with selectable text (not a photo or scan).';
    }

    // ── Model Router: Gemini vs Groq ───────────────────────────────────────
    // If the text is extremely large (>= 20,000 chars), route it
    // to Gemini which handles massive contexts. Otherwise, use Groq for speed.
    final bool routeToGemini = content.length >= 20000;

    if (routeToGemini) {
      AppLogger.info('Routing to Gemini. Content length: ${content.length}',
          tag: 'AIService');
    } else {
      AppLogger.info('Routing to Groq. Content length: ${content.length}',
          tag: 'AIService');
    }

    // ── 1. Build grounded system prompt ────────────────────────────────────
    final String traitInstructions;

    if (isADHD) {
      traitInstructions = 'Format the output for a learner with ADHD:\n'
          '- Start the ENTIRE response with a **### ⚡ TL;DR** section containing exactly 3 bullet points summarizing the whole document.\n'
          '- Use **bold headers** for each topic (## Header).\n'
          '- Start every bullet point with a relevant emoji.\n'
          '- Bold (**keyword**) the most important terms so they can be visually highlighted by the app.\n'
          '- Insert encouraging Progress Markers between sections (e.g., "Great job! Halfway there!").\n'
          '- Keep each bullet ≤ 15 words.\n'
          '- End with a section titled **### 📋 Summary Checklist** listing the 3–5 most important takeaways as checkboxes (- [ ] item).';
    } else if (isAutistic) {
      traitInstructions =
          'Format the output for a learner with Autism Spectrum Condition using a Deep Dive structure:\n'
          '- Use ### Markdown headings for each topic.\n'
          '- Under each heading write **Why this matters:** followed by a literal, precise explanation.\n'
          '- Under each heading write **How it works:** with a numbered step-by-step breakdown.\n'
          '- Ensure concepts are visually spaced out. Do not clump information together.\n'
          '- Inject a "💡 Did you know?" or "Fun Fact!" callout with extra, literal context where relevant.\n'
          '- Be literal and unambiguous. Avoid idioms, metaphors, and vague language.\n'
          '- Do NOT skip steps or assume implied knowledge.';
    } else if (isDyslexic) {
      traitInstructions = 'Format the output for a learner with Dyslexia:\n'
          '- Use short paragraphs (2–3 sentences max).\n'
          '- Use high-contrast bullet points (- item) for all key ideas.\n'
          '- NEVER have more than 3 bullet points in a row without a visual break (e.g., a new short paragraph or header).\n'
          '- Prefer words with 1–2 syllables.\n'
          '- One idea per bullet. No nested bullets. No tables.\n'
          '- Add a blank line between every paragraph and bullet group.';
    } else if (isDyspraxic) {
      traitInstructions =
          'Format the output for a learner with Dyspraxia using a Kinesthetic/Action-Oriented structure:\n'
          '- Use "Step-by-Step" instructions for all concepts.\n'
          '- Each step must start with a CLEAR ACTION VERB (e.g., "Identify", "Compare", "Write").\n'
          '- Use bolding for the ACTION VERBS.\n'
          '- Break tasks into the smallest possible sequences.\n'
          '- If explaining a concept, explain it through a "Mental Simulation" or "Hands-on Analogy".\n'
          '- Keep the layout extremely linear (One column, no sidebars/tables).';
    } else {
      traitInstructions = 'Format the output as a clear Markdown summary:\n'
          '- Use ### headings for major topics.\n'
          '- Use bullet points for key facts and takeaways.\n'
          '- Keep language concise and educational.';
    }

    final String systemPrompt = 'You are the AdaptEd Learning Assistant.\n'
        'The user has uploaded a PDF and the text has been extracted for you.\n'
        'Your ONLY job is to summarise the document text provided between the ### SOURCE MATERIAL ### delimiters below.\n'
        'IMPORTANT RULES:\n'
        '1. Use ONLY the provided document text as your source of truth.\n'
        '2. Do NOT apologise for not being able to see or access files — the text is already given to you.\n'
        '3. Do NOT invent or assume information not present in the text.\n'
        '4. Do NOT refer to "the document" or "the PDF" — just present the information directly.\n'
        '5. Chunk the summary into "Bite-Sized" sections. You MUST break the PDF content into 4-6 distinct, bite-sized objects.\n'
        '6. Use Progressive Disclosure: Utilize bulleted lists rather than dense paragraphs to prevent cognitive overload.\n'
        '7. You MUST return ONLY a raw JSON array of objects. Do not include markdown code blocks. Each object must follow this schema: {"title": "Section Title", "content": "The actual text with **keywords** in bold", "icon": "emoji"}\n\n'
        '$traitInstructions';

    // ── 2. Wrap the content in clear delimiters ─────────────────────────────
    final String userPrompt = '### SOURCE MATERIAL ###\n'
        '$content\n'
        '### END SOURCE MATERIAL ###\n\n'
        'Generate the summary now using ONLY the source material above.';

    try {
      if (routeToGemini) {
        return await _callGeminiAPI(userPrompt,
            systemPrompt: systemPrompt, onWait: onWait);
      } else {
        return await _callGroqAPI(userPrompt, systemPrompt: systemPrompt);
      }
    } catch (e, stack) {
      AppLogger.error('Adaptive summary failed',
          tag: 'AIService', error: e, stackTrace: stack);
      return 'Error generating summary. Please try again later.';
    }
  }

  Future<String> chatWithAI(String text, String profileName,
      {void Function(String)? onWait}) async {
    final systemPrompt = "$chatbotPersonaPrompt $profileName";
    try {
      return await _callGeminiAPI(text,
          systemPrompt: systemPrompt, onWait: onWait);
    } catch (e, stack) {
      AppLogger.error('Chat generation failed',
          tag: 'AIService', error: e, stackTrace: stack);
      return "I'm having trouble connecting to my brain right now. Please try again.";
    }
  }

  /// Static alias for chatWithAI to support context-based routing.
  static Future<String> generateChatResponse(String text,
      {String? context, void Function(String)? onWait}) async {
    return await AIService()
        .chatWithAI(text, context ?? "General", onWait: onWait);
  }

  /// Chat with the AI using a stream for real-time response feel.
  Stream<String> chatWithAIStream(String message, String learningStyle) async* {
    if (_groqApiKey.isEmpty) {
      yield "Config Error: GROQ_API_KEY missing in .env";
      return;
    }

    final systemPrompt = "$chatbotPersonaPrompt $learningStyle";
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final request = http.Request('POST', url);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_groqApiKey',
    });
    request.body = jsonEncode({
      'model': 'llama-3.1-8b-instant',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': message},
      ],
      'stream': true,
    });

    try {
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        AppLogger.error('Stream API Error',
            tag: 'AIService', error: 'Status: ${response.statusCode}');
        yield "API Error: ${response.statusCode}";
        return;
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') break;

            try {
              final data = jsonDecode(dataStr);
              final content = data['choices']?[0]?['delta']?['content'];
              if (content != null) yield content;
            } catch (e) {
              // Ignore partial JSON parse errors usually caused by split chunks
            }
          }
        }
      }
    } catch (e, stack) {
      AppLogger.error('Stream Connection Failed',
          tag: 'AIService', error: e, stackTrace: stack);
      yield " [Connection Error: $e]";
    }
  }
  // --- PRIVATE API CALLERS ---

  Future<String> _callGroqAPI(String userContent,
      {String? systemPrompt}) async {
    if (_groqApiKey.isEmpty) {
      AppLogger.error('API Key Missing',
          tag: 'AIService', error: 'GROQ_API_KEY not found in .env');
      return "Config Error: API Key missing. Please check .env";
    }

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final messages = [];
    if (systemPrompt != null)
      messages.add({'role': 'system', 'content': systemPrompt});
    messages.add({'role': 'user', 'content': userContent});

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': messages,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        AppLogger.error('API Error',
            tag: 'AIService',
            error: 'Status: ${response.statusCode}, Body: ${response.body}');
        if (response.statusCode == 413) {
          return "The uploaded document is too large to process. Please try uploading a shorter pdf.";
        } else if (response.statusCode == 429) {
          return "Rate limit exceeded. Please wait a moment and try again.";
        }

        return "API Error (${response.statusCode}): ${response.body}";
      }
    } catch (e, stack) {
      AppLogger.error('Network Error',
          tag: 'AIService', error: e, stackTrace: stack);
      return "Network Error: $e";
    }
  }

  // //Generate 10 short_answer questions based on the PDF content
  Future<List<Map<String, dynamic>>> generateShortAnswerQuiz(
      String content, {String difficulty = 'MEDIUM'}) async {
    final prompt =
        "Generate exactly 10 $difficulty level short-answers based on the following text."
        "Return ONLY a JSON array of objects. Each object must have a 'question' (string) and 'answer' (string).\n\nContent:\n$content";

    try {
      final response = await _callGroqAPI(prompt);
      String cleaned = response;

      if (response.contains('```json')) {
        cleaned = response.split('```json')[1].split('```')[0].trim();
      } else if (response.contains('```')) {
        cleaned = response.split('```')[1].split('```')[0].trim();
      }

      if (!cleaned.startsWith('[')) {
        final startIndex = cleaned.indexOf('[');
        final endIndex = cleaned.lastIndexOf(']');
        if (startIndex != -1 && endIndex != -1) {
          cleaned = cleaned.substring(startIndex, endIndex + 1);
        }
      }

      final List<dynamic> data = jsonDecode(cleaned);
      return data.cast<Map<String, dynamic>>();
    } catch (e, stack) {
      AppLogger.error('Short answer quiz generation failed',
          tag: 'AIService', error: e, stackTrace: stack);
      return [];
    }
  }

  // Generate multiple-choice questions based on the content
  Future<List<Map<String, dynamic>>> generateMultipleChoiceQuiz(
      String content, {String difficulty = 'MEDIUM'}) async {
     final prompt =
        "Generate exactly 10 $difficulty level multiple-choice questions based on the following text. "
        "Return ONLY a JSON array of objects. Each object must have a 'question' (string), "
        "'options' (an array of exactly 4 strings), and 'correctIndex' (integer 0-3 indicating the correct option).\n\nContent:\n$content";

    try {
      final response = await _callGroqAPI(prompt);
      String cleaned = response;

      if (response.contains('```json')) {
        cleaned = response.split('```json')[1].split('```')[0].trim();
      } else if (response.contains('```')) {
        cleaned = response.split('```')[1].split('```')[0].trim();
      }

      if (!cleaned.startsWith('[')) {
        final startIndex = cleaned.indexOf('[');
        final endIndex = cleaned.lastIndexOf(']');
        if (startIndex != -1 && endIndex != -1) {
          cleaned = cleaned.substring(startIndex, endIndex + 1);
        }
      }

      final List<dynamic> data = jsonDecode(cleaned);
      return data.cast<Map<String, dynamic>>();
    } catch (e, stack) {
      AppLogger.error('Multiple choice quiz generation failed',
          tag: 'AIService', error: e, stackTrace: stack);
      return [];
    }
  }

  // --- 4. RETRY LOGIC & PRIVATE API CALLERS ---

  Future<T> _retryWithBackoff<T>(Future<T> Function() action,
      {void Function(String)? onWait, void Function()? onRetry}) async {
    int retries = 0;
    const int maxRetries = 3;

    while (true) {
      try {
        return await action();
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        // Check for Quota or Rate Limit specifics
        if (errorStr.contains('quota') ||
            errorStr.contains('429') ||
            errorStr.contains('rate limit')) {
          retries++;
          if (retries > maxRetries) {
            AppLogger.error('Max retries exceeded for Quota issue',
                tag: 'AIService', error: e);
            rethrow;
          }

          AppLogger.warning(
              'Quota Exceeded. Retrying $retries/$maxRetries in 5 seconds...',
              tag: 'AIService');
          if (onWait != null) {
            onWait("AdaptEd is thinking deeply... back in a few seconds!");
          }
          if (onRetry != null) {
            onRetry();
          }

          await Future.delayed(const Duration(seconds: 5));
        } else {
          rethrow; // Re-throw non-quota errors immediately
        }
      }
    }
  }

  Future<String> _callGeminiAPI(String userContent,
      {String? systemPrompt, void Function(String)? onWait}) async {
    if (_geminiApiKey.isEmpty) {
      AppLogger.error('API Key Missing',
          tag: 'AIService', error: 'GEMINI_API_KEY missing');
      return "Config Error: Gemini API Key missing.";
    }

    try {
      // 1. The server unequivocally told us this is your authorized primary model
      String currentModel = 'gemini-2.5-flash';

      return await _retryWithBackoff(
          () async {
            // The 2.5 models require the v1beta endpoint to function correctly in the Dart SDK
            final model = GenerativeModel(
              model: currentModel,
              apiKey: _geminiApiKey,
              requestOptions: const RequestOptions(apiVersion: 'v1beta'),
            );

            // 2. Prompt Prepending (bulletproof bypassing of payload parsing!)
            final combinedPrompt = systemPrompt != null
                ? "SYSTEM INSTRUCTIONS: $systemPrompt\n\nUSER MESSAGE:\n$userContent"
                : userContent;

            final response =
                await model.generateContent([Content.text(combinedPrompt)]);

            if (response.text != null && response.text!.isNotEmpty) {
              return response.text!;
            } else {
              throw Exception('Gemini returned empty response');
            }
          },
          onWait: onWait,
          onRetry: () {
            // 3. Fallback to your other allowed 2.5 model if rate-limited!
            currentModel = 'gemini-2.5-pro';
          });
    } catch (e, stack) {
      AppLogger.error('Gemini Network Error',
          tag: 'AIService', error: e, stackTrace: stack);
      return "Network Error: $e";
    }
  }
}
