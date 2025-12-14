import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatChefPage extends StatefulWidget {
  const ChatChefPage({super.key});

  @override
  State<ChatChefPage> createState() => _ChatChefPageState();
}

class _ChatChefPageState extends State<ChatChefPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': message});
      _isLoading = true;
    });

    const apiKey = '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'; // Replace with your actual key

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {'role': 'system', 'content': 'You are a helpful assistant.'},
            {'role': 'user', 'content': message},
          ],
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiMessage = data['choices'][0]['message']['content'] as String;

        setState(() {
          _messages.add({'role': 'assistant', 'content': aiMessage});
          _isLoading = false;
        });
      } else {
        String errorMessage = 'Error: ${response.statusCode} - ${response.reasonPhrase}';
        setState(() {
          _messages.add({'role': 'assistant', 'content': errorMessage});
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'Error: $e'});
        _isLoading = false;
      });
    }

    _controller.clear();
  }

  Widget _buildMessage(Map<String, String> message) {
    final isUser = message['role'] == 'user';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.green[200] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message['content'] ?? '',
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat-Chef'),
        backgroundColor: const Color(0xFF1C4322),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: 'Ask me anything about cooking...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF1C4322)),
                    onPressed: () => _sendMessage(_controller.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}