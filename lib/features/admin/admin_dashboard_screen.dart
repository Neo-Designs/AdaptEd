import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/services/ai_service.dart';
import '../../core/utils/logger.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController _summaryPromptController = TextEditingController();
  final TextEditingController _chatPromptController = TextEditingController();
  final AIService _aiService = AIService();
  
  final TextEditingController _adminChatController = TextEditingController();
  final List<Map<String, String>> _adminMessages = [];
  bool _isChatLoading = false;

  @override
  void initState() {
    super.initState();
    _summaryPromptController.text = AIService.summaryPrompt;
    _chatPromptController.text = AIService.chatbotPersonaPrompt;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Portal"),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             _buildAnalyticsSection(),
             const SizedBox(height: 32),
             _buildPromptManagementSection(),
             const SizedBox(height: 32),
             _buildChatbotSection(),
           ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Analytics Dashboard", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildCountCard("Total Users", FirebaseFirestore.instance.collection('users').snapshots().map((s) => s.docs.length.toString())),
            const SizedBox(width: 16),
            _buildCountCard("User Reviews", FirebaseFirestore.instance.collection('reviews').snapshots().map((s) => s.docs.length.toString())),
          ],
        ),
        const SizedBox(height: 24),
        _buildReviewList(),
      ],
    );
  }

  Widget _buildReviewList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Latest Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('reviews').orderBy('timestamp', descending: true).limit(5).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Text("No reviews found.");

            // Calculate average
            return FutureBuilder<double>(
              future: _calculateAverageRating(),
              builder: (context, avgSnapshot) {
                return Column(
                  children: [
                    if (avgSnapshot.hasData)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text("Average Rating: ${avgSnapshot.data!.toStringAsFixed(1)} / 5.0", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
                      ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(data['text'] ?? '', style: const TextStyle(fontSize: 14)),
                            subtitle: Text("Rating: ${data['rating'] ?? 'N/A'}", style: const TextStyle(fontSize: 12)),
                          ),
                        );
                      },
                    ),
                  ],
                );
              }
            );
          },
        ),
      ],
    );
  }

  Future<double> _calculateAverageRating() async {
    final snap = await FirebaseFirestore.instance.collection('reviews').get();
    if (snap.docs.isEmpty) return 0.0;
    double total = 0;
    for (var doc in snap.docs) {
      total += (doc.data()['rating'] ?? 0).toDouble();
    }
    return total / snap.docs.length;
  }

  Widget _buildCountCard(String title, Stream<String> countStream) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(color: Colors.grey)),
              StreamBuilder<String>(
                stream: countStream,
                builder: (context, snapshot) {
                  return Text(snapshot.data ?? "...", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("AI Prompt Management", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildPromptField("Summary System Prompt", _summaryPromptController),
        const SizedBox(height: 16),
        _buildPromptField("Chatbot Persona Prompt", _chatPromptController),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          onPressed: () async {
            try {
              await FirebaseFirestore.instance.collection('config').doc('ai_prompts').set({
                'summaryPrompt': _summaryPromptController.text,
                'chatbotPersonaPrompt': _chatPromptController.text,
                'lastUpdated': FieldValue.serverTimestamp(),
              });
              AIService.updateSummaryPrompt(_summaryPromptController.text);
              AIService.updateChatbotPrompt(_chatPromptController.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Prompts updated and synced!")));
              }
            } catch (e) {
               AppLogger.error("Failed to save prompts", error: e);
            }
          },
          label: const Text("Deploy Prompt Changes"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
        ),
      ],
    );
  }

  Widget _buildPromptField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  Widget _buildChatbotSection() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Admin Assistant", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _adminMessages.length,
              itemBuilder: (context, index) {
                final msg = _adminMessages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueGrey : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(msg['content']!, style: TextStyle(color: isUser ? Colors.white : Colors.black)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _adminChatController,
                  decoration: const InputDecoration(hintText: "Ask about admin tasks..."),
                ),
              ),
              IconButton(
                onPressed: _sendMessage,
                icon: _isChatLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _adminChatController.text.trim();
    if (text.isEmpty) return;
    
    setState(() {
      _adminMessages.add({'role': 'user', 'content': text});
      _isChatLoading = true;
      _adminChatController.clear();
    });

    try {
      final response = await _aiService.chatWithAI(text, "Admin Assistant");
      if (mounted) {
        setState(() {
          _adminMessages.add({'role': 'ai', 'content': response});
          _isChatLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _adminMessages.add({'role': 'ai', 'content': "Error: $e"});
          _isChatLoading = false;
        });
      }
    }
  }
}
