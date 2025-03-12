import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:decideat/models/chat_message.dart';
import 'package:decideat/api/api.dart' as api;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Page for chatting with the AI assistant
class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // API configuration
  final String _apiUrl = api.apiUrl!; // Change this to your actual API URL
  
  // Chat state
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with a welcome message
    _messages.add(ChatMessage(
      text: "Welcome to the chat! Send a message to get started.",
      isUser: false,
    ));
  }

  /// Send a message to the AI via REST API
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    
    _messageController.clear();

    // Add user message to the chat
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
      ));
      _isLoading = true;
    });

    // Scroll to the bottom immediately after adding user message
    _scrollToBottom();

    try {
      // Make API request
      final response = await http.post(
        Uri.parse('$_apiUrl/llama/chat'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        // Successfully received response
        String responseText = response.body;
        
        // Parse the response text if needed
        try {
          // Some APIs return JSON objects, check if this is the case
          final dynamic jsonResponse = json.decode(responseText);
          if (jsonResponse is Map<String, dynamic> && jsonResponse.containsKey('message')) {
            responseText = jsonResponse['message'] as String;
          } else if (jsonResponse is String) {
            // If the JSON decoded to a string, use that directly
            responseText = jsonResponse;
          }
          // Otherwise keep the original response
        } catch (_) {
          // Not JSON, use the raw response
        }
        
        setState(() {
          _messages.add(ChatMessage(
            text: responseText,
            isUser: false,
          ));
          _isLoading = false;
        });
      } else {
        // Handle error response
        setState(() {
          _messages.add(ChatMessage(
            text: "Error: Server returned status code ${response.statusCode}",
            isUser: false,
          ));
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle network or other errors
      setState(() {
        _messages.add(ChatMessage(
          text: "Error connecting to API: ${e.toString()}",
          isUser: false,
        ));
        _isLoading = false;
      });
    }

    // Scroll to bottom after adding response
    _scrollToBottom();
  }

  /// Scroll to the bottom of the chat
  void _scrollToBottom() {
    // Use Future.delayed to ensure the UI has updated
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _buildChatMessages(),
          ),
          
          // Input field and send button
          _buildInputArea(),
        ],
      ),
    );
  }

  /// Build the chat messages list
  Widget _buildChatMessages() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to start chatting',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  /// Build a message bubble for a chat message
  Widget _buildMessageBubble(ChatMessage message) {
    // Process the message text to properly handle escape sequences
    final String processedText = _processMessageText(message.text);
    
    return Align(
      alignment: message.isUser 
          ? Alignment.centerRight 
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: message.isUser 
              ? Colors.green.shade100 
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: 2,
              color: Colors.black.withOpacity(0.1),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: SelectableText(
          processedText,
          style: TextStyle(
            color: message.isUser 
                ? Colors.black87 
                : Colors.black87,
            fontWeight: message.isUser 
                ? FontWeight.w500 
                : FontWeight.normal,
            height: 1.4, // Increase line height for better readability
          ),
        ),
      ),
    );
  }

  /// Process message text to handle formatting and escape sequences
  String _processMessageText(String text) {
    if (text.isEmpty) return text;
    
    try {
      // Check if the text is JSON formatted (from API response)
      // This handles cases where the API returns a JSON string with escape sequences
      if (text.startsWith('"') && text.endsWith('"')) {
        try {
          // Attempt to decode JSON string
          final decoded = json.decode(text);
          if (decoded is String) {
            return decoded;
          }
        } catch (_) {
          // If decoding fails, continue with regular processing
        }
      }
      
      // Handle different types of newline representations
      String processed = text;
      
      // Replace literal \n with actual newlines
      processed = processed.replaceAll('\\n', '\n');
      
      // Replace literal \\n with actual newlines (double escaped)
      processed = processed.replaceAll('\\\\n', '\n');
      
      // Remove any quotes at the beginning and end if they exist
      if (processed.startsWith('"') && processed.endsWith('"')) {
        processed = processed.substring(1, processed.length - 1);
      }
      
      return processed;
    } catch (e) {
      // If any error occurs during processing, return the original text
      return text;
    }
  }

  /// Build the message input area
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: _isLoading ? 'Waiting for response...' : 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onSubmitted: (_) => _sendMessage(),
              maxLines: 1,
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: !_isLoading ? _sendMessage : null,
            mini: true,
            backgroundColor: !_isLoading ? Colors.green.shade300 : Colors.grey,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
