import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/services/ai_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController _summaryPromptController =
      TextEditingController();
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
        const Text("Analytics Dashboard",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildCountCard(
                "Total Users",
                FirebaseFirestore.instance
                    .collection('users')
                    .snapshots()
                    .map((s) => s.docs.length.toString())),
            const SizedBox(width: 16),
            _buildCountCard(
                "Reviews",
                FirebaseFirestore.instance
                    .collection('reviews')
                    .snapshots()
                    .map((s) => s.docs.length.toString())),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!)),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 22)),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                  show: true, border: Border.all(color: Colors.grey[300]!)),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    const FlSpot(0, 10),
                    const FlSpot(1, 25),
                    const FlSpot(2, 40),
                    const FlSpot(3, 35),
                    const FlSpot(4, 60),
                    const FlSpot(5, 80),
                    const FlSpot(6, 95),
                  ],
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                      show: true, color: Colors.blue.withValues(alpha: 0.1)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(child: Text("User Growth (Last 7 Days - Mock Data)")),
      ],
    );
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
                    return Text(snapshot.data ?? "...",
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold));
                  }),
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
        const Text("Prompt Engineering",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildPromptField("Summary System Prompt", _summaryPromptController),
        const SizedBox(height: 16),
        _buildPromptField("Chatbot Persona Prompt", _chatPromptController),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            // In a real app, save these to Firestore or a config service
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Prompts updated successfully!")));
          },
          child: const Text("Save Prompt Config"),
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
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Admin Assistant",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _adminMessages.length,
              itemBuilder: (context, index) {
                final msg = _adminMessages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueGrey : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(msg['content']!,
                        style: TextStyle(
                            color: isUser ? Colors.white : Colors.black)),
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
                  decoration: const InputDecoration(
                      hintText: "Ask about admin tasks..."),
                ),
              ),
              IconButton(
                onPressed: _sendMessage,
                icon: _isChatLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator())
                    : const Icon(Icons.send),
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
