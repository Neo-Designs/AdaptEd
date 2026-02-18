import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';

class AIService {
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
      "Keep answers concise but helpful. Adaptation style: ";

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
  Future<String> generateSummary(String content, {String learningStyle = "General"}) async {
    final prompt = "$summaryPrompt\n\nTarget Audience Style: $learningStyle\n\nContent:\n$content";
    
    try {
      return await _callGroqAPI(prompt);
    } catch (e, stack) {
      AppLogger.error('Summary generation failed', tag: 'AIService', error: e, stackTrace: stack);
      return "Error generating summary. Please try again later.";
    }
  }

  /// Real Chat method connected to Groq API
  Future<String> chatWithAI(String text, String profileName) async {
    final systemPrompt = "$chatbotPersonaPrompt $profileName";
    try {
      return await _callGroqAPI(text, systemPrompt: systemPrompt);
    } catch (e, stack) {
      AppLogger.error('Chat generation failed', tag: 'AIService', error: e, stackTrace: stack);
      return "I'm having trouble connecting to my brain right now. Please try again.";
    }
  }

  /// Chat with the AI using a stream for real-time response feel.
  Stream<String> chatWithAIStream(String message, String learningStyle) async* {
    final systemPrompt = "$chatbotPersonaPrompt $learningStyle";
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final request = http.Request('POST', url);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_groqApiKey',
    });
    request.body = jsonEncode({
      'model': 'llama3-8b-8192',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': message},
      ],
      'stream': true,
    });

    try {
      final response = await http.Client().send(request);
      if (response.statusCode != 200) {
        throw Exception('Groq Stream Error: ${response.statusCode}');
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') break;
            try {
              final data = jsonDecode(dataStr);
              final content = data['choices'][0]['delta']['content'];
              if (content != null) yield content;
            } catch (_) {}
          }
        }
      }
    } catch (e, stack) {
      AppLogger.error('AI Stream Error', tag: 'AIService', error: e, stackTrace: stack);
      yield " [Error: Connection lost]";
    }
  }

  /// Generates a quiz based on educational content.
  Future<List<Map<String, dynamic>>> generateQuiz(String content) async {
    final prompt = "Generate 5 multiple choice questions based on the following text. "
        "Return ONLY a JSON array of objects. Each object must have 'question', 'options' (array of strings), and 'correctIndex' (int).\n\nContent:\n$content";
    
    try {
      final response = await _callGroqAPI(prompt);
      String cleaned = response;
      if (response.contains('```json')) {
        cleaned = response.split('```json')[1].split('```')[0].trim();
      } else if (response.contains('```')) {
        cleaned = response.split('```')[1].split('```')[0].trim();
      }
      // Basic cleanup for leading/trailing non-json chars if markdown didn't catch it
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
      AppLogger.error('Quiz generation failed', tag: 'AIService', error: e, stackTrace: stack);
      // Return empty list instead of throwing to allow caller to handle gracefully
      return []; 
    }
  }

  // --- PRIVATE API CALLERS ---

  Future<String> _callGroqAPI(String userContent, {String? systemPrompt}) async {
    if (_groqApiKey.isEmpty) {
      return "Groq API Key missing. Please check .env";
    }

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final messages = [];
    if (systemPrompt != null) messages.add({'role': 'system', 'content': systemPrompt});
    messages.add({'role': 'user', 'content': userContent});

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_groqApiKey',
      },
      body: jsonEncode({
        'model': 'llama3-8b-8192',
        'messages': messages,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Groq API Error: ${response.statusCode} ${response.body}');
    }
  }
}
