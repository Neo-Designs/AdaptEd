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
  final List<Map<String, String>> _adminMessages = [];
  final TextEditingController _adminChatController = TextEditingController();
  bool _isChatLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrompts();
  }

  @override
  void dispose() {
    _summaryPromptController.dispose();
    _chatPromptController.dispose();
    _adminChatController.dispose();
    super.dispose();
  }

  Future<void> _loadPrompts() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('ai_prompts').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _summaryPromptController.text = data['summaryPrompt'] ?? "";
          _chatPromptController.text = data['chatbotPersonaPrompt'] ?? "";
        });
      }
    } catch (e) {
      AppLogger.error("Error loading prompts", error: e);
    }
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
            const SizedBox(height: 32),
            _buildUsersFeed(),
            const SizedBox(height: 32),
            _buildRecentDocumentsSection(),
            const SizedBox(height: 32),
            _buildReviewsFeed(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // --- 1. ANALYTICS & GRAPH SECTION ---
  Widget _buildAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Analytics Dashboard", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildCountCard(
              "Total Users", 
              Icons.people,
              FirebaseFirestore.instance.collection('users').snapshots().map((s) => s.docs.length.toString()),
            ),
            const SizedBox(width: 16),
            _buildCountCard(
              "User Reviews", 
              Icons.star,
              FirebaseFirestore.instance.collection('reviews').snapshots().map((s) => s.docs.length.toString()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildCountCard(
              "Documents Processed", 
              Icons.picture_as_pdf,
              FirebaseFirestore.instance.collection('learning_materials').snapshots().map((s) => s.docs.length.toString()),
            ),
            const SizedBox(width: 16),
            _buildCountCard(
              "Quizzes Generated", 
              Icons.quiz,
              FirebaseFirestore.instance.collection('quizzes').snapshots().map((s) => s.docs.length.toString()),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildReviewList(),
        const SizedBox(height: 24),
        _buildRealTimeChart(), 
        const SizedBox(height: 8),
        const Center(child: Text("Active Users (Last 7 Days)")),
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
                            title: Text(data['comment'] ?? data['text'] ?? '', style: const TextStyle(fontSize: 14)),
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

  Widget _buildCountCard(String title, IconData icon, Stream<String> countStream) {
    return Expanded(
      child: Card(
        clipBehavior: Clip.antiAlias, 
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<String>(
                stream: countStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                     return const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  return Text(
                    snapshot.data ?? "0", 
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueGrey)
                  );
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 5,
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
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
          if (_isChatLoading) const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _adminChatController,
                  decoration: const InputDecoration(hintText: "Ask about system status..."),
                  onSubmitted: (_) => _sendAdminChat(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blueGrey),
                onPressed: _sendAdminChat,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendAdminChat() async {
    final text = _adminChatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _adminMessages.add({'role': 'user', 'content': text});
      _adminChatController.clear();
      _isChatLoading = true;
    });

    try {
      final response = await AIService.generateChatResponse(text, context: "State: Admin Dashboard");
      setState(() {
        _adminMessages.add({'role': 'assistant', 'content': response});
      });
    } catch (e) {
      AppLogger.error("Admin chat error", error: e);
      setState(() {
        _adminMessages.add({'role': 'assistant', 'content': "Error: Could not reach AI service."});
      });
    } finally {
      setState(() => _isChatLoading = false);
    }
  }

  Widget _buildRealTimeChart() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 250,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox(height: 250, child: Center(child: Text("Error loading chart data.")));
        }

        List<double> dailyCounts = List.filled(7, 0);
        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final Timestamp? timestamp = data['lastUpdated'] ?? data['createdAt'];

          if (timestamp != null) {
            final date = timestamp.toDate();
            final docMidnight = DateTime(date.year, date.month, date.day);
            final differenceInDays = todayMidnight.difference(docMidnight).inDays;
            
            if (differenceInDays >= 0 && differenceInDays < 7) {
              dailyCounts[6 - differenceInDays]++;
            }
          }
        }

        List<FlSpot> spots = [];
        for (int i = 0; i < 7; i++) {
          spots.add(FlSpot(i.toDouble(), dailyCounts[i]));
        }

        double maxDataPoint = dailyCounts.reduce((a, b) => a > b ? a : b);
        double maxY = ((maxDataPoint / 5).ceil() * 5).toDouble(); 
        if (maxY < 5) maxY = 5; 

        return Container(
          height: 250,
          padding: const EdgeInsets.only(right: 16, left: 0, top: 16, bottom: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              minY: 0,
              maxY: maxY,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, 
                    reservedSize: 40,
                    interval: maxY / 5, 
                  )
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, 
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      const style = TextStyle(color: Colors.grey, fontSize: 10);
                      int daysAgo = 6 - value.toInt();
                      String text = daysAgo == 0 ? 'Today' : '-${daysAgo}d';
                      return SideTitleWidget(
                        meta: meta, 
                        child: Text(text, style: style),
                      );
                    },
                  )
                ), 
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey[300]!)),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true, 
                  color: Colors.blue,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 2. USERS FEED ---
  Widget _buildUsersFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.people, color: Colors.blueGrey),
            SizedBox(width: 8),
            Text("System Feed: Registered Users", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 350, 
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No users found."));

              final docs = snapshot.data!.docs;
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final docId = docs[index].id;
                  
                  final email = data['email'] ?? 'No Email';
                  final role = data['role'] ?? 'learner';
                  final xp = data['xp'] ?? 0;
                  final level = data['level'] ?? 1;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: role == 'admin' ? Colors.blueGrey : Colors.blue.withOpacity(0.2),
                      child: Icon(
                        role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                        color: role == 'admin' ? Colors.white : Colors.blue,
                      ),
                    ),
                    title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: role == 'admin' 
                        ? const Text("System Administrator", style: TextStyle(color: Colors.blueGrey))
                        : Text("Level $level • $xp XP"),
                    trailing: PopupMenuButton<String>(
                      initialValue: role,
                      tooltip: "Change Role",
                      onSelected: (newRole) async {
                        if (newRole != role) {
                          await FirebaseFirestore.instance.collection('users').doc(docId).update({'role': newRole});
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$email updated to $newRole.")));
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'learner', child: Text("Learner")),
                        const PopupMenuItem(value: 'admin', child: Text("Admin")),
                      ],
                      child: Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Text(role.toUpperCase(), style: const TextStyle(fontSize: 10)), const Icon(Icons.arrow_drop_down, size: 16)],
                        ),
                        backgroundColor: Colors.grey[100],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 3. RECENT DOCUMENTS FEED ---
  Widget _buildRecentDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.monitor_heart, color: Colors.blueGrey),
            SizedBox(width: 8),
            Text("System Feed: Recent Documents", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 350, 
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('learning_materials')
                .orderBy('createdAt', descending: true)
                .limit(20) 
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_off, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No documents have been uploaded yet.", style: TextStyle(color: Colors.grey)),
                    ],
                  )
                );
              }

              final docs = snapshot.data!.docs;
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final docId = docs[index].id;
                  
                  final title = data['title'] ?? 'Untitled Document';
                  final userId = data['userId'] ?? 'Unknown User';
                  
                  String dateStr = "Unknown Date";
                  if (data['createdAt'] != null) {
                    final date = (data['createdAt'] as Timestamp).toDate();
                    dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
                  }

                  return ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text("Uploaded: $dateStr"),
                    trailing: IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.blue),
                      tooltip: "Inspect Metadata",
                      onPressed: () => _showDocumentMetadata(context, docId, title, userId, dateStr),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDocumentMetadata(BuildContext context, String docId, String title, String userId, String dateStr) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.data_object, color: Colors.blueGrey),
            SizedBox(width: 8),
            Text("Document Metadata"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetaRow("Filename:", title),
            _buildMetaRow("Document ID:", docId),
            
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
              builder: (context, snapshot) {
                String ownerText = userId; 
                
                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  final email = userData['email'] ?? 'Unknown Email';
                  ownerText = "$email\n($userId)"; 
                }
                
                return _buildMetaRow("Owner:", ownerText);
              },
            ),
            
            _buildMetaRow("Processed At:", dateStr),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text("AI Processing Successful", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100, 
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
          ),
          Expanded(
            child: Text(
              value, 
              style: const TextStyle(fontFamily: 'monospace', color: Colors.blueGrey, fontSize: 13)
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. REVIEWS FEED ---
  Widget _buildReviewsFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.star, color: Colors.orange),
            SizedBox(width: 8),
            Text("System Feed: User Feedback & Reviews", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 350, 
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('reviews').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.reviews_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No reviews yet.", style: TextStyle(color: Colors.grey)),
                    ],
                  )
                );
              }

              final docs = snapshot.data!.docs;
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final email = data['userEmail'] ?? 'Anonymous';
                  final rating = data['rating'] ?? 5;
                  final comment = data['comment'] ?? data['text'] ?? 'No comment provided.';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), shape: BoxShape.circle),
                        child: Text(rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ),
                      title: Text(email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(comment, style: const TextStyle(color: Colors.black87))),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}