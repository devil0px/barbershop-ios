import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import 'booking_repository.dart';

class ChatScreen extends StatefulWidget {
  final int bookingId;
  final String barbershopName;
  const ChatScreen({super.key, required this.bookingId, required this.barbershopName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _bookingRepository = BookingRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  WebSocketChannel? _channel;

  // Track optimistic (pending) message tempIds to avoid duplication on WS echo
  final Set<int> _pendingTempIds = {};
  // Track all known message IDs to prevent duplicates
  final Set<int> _knownMessageIds = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAsRead();
    _connectWebSocket();
  }
  
  void _connectWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    // Connect to WebSocket with token for authentication
    final wsUrl = '${ApiConstants.chatWebSocket(widget.bookingId)}?token=$token';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    
    _channel!.stream.listen(
      (message) {
        try {
          final jsonData = jsonDecode(message) as Map<String, dynamic>;
          
          final isMe = jsonData['is_me'] ?? false;
          final text = jsonData['message'] ?? '';
          final senderName = jsonData['sender_name'] ?? '';
          final messageId = jsonData['message_id'] ?? 0;
          final createdAt = jsonData['created_at'] ?? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
          
          setState(() {
            if (isMe) {
              // ─── Optimistic message replacement ───────────────────────
              // Find the pending optimistic entry and replace it with the
              // confirmed server version (which has the real DB id).
              final idx = _messages.indexWhere((m) =>
                  m['is_me'] == true && _pendingTempIds.contains(m['id']));
              if (idx != -1) {
                _pendingTempIds.remove(_messages[idx]['id']);
                _knownMessageIds.add(messageId);
                _messages[idx] = {
                  'id': messageId,
                  'message': text,
                  'sender_name': 'أنت',
                  'created_at': createdAt,
                  'is_me': true,
                };
                return;
              }
            }

            // Deduplication: skip if we already have this message ID
            if (messageId != 0 && _knownMessageIds.contains(messageId)) {
              return;
            }

            // Incoming message from the other party – show real sender name
            _knownMessageIds.add(messageId);
            _messages.add({
              'id': messageId,
              'message': text,
              'sender_name': isMe ? 'أنت' : (senderName.isNotEmpty ? senderName : 'الطرف الآخر'),
              'created_at': createdAt,
              'is_me': isMe,
            });
          });
          
          // Scroll to bottom
          _scrollToBottom();
          
          // Mark as read
          _markAsRead();
        } catch (e) {
          debugPrint('WebSocket parse error: $e');
        }
      },
      onError: (error) {
        debugPrint('WebSocket connection error: $error');
      },
      onDone: () {
        debugPrint('WebSocket connection closed — reconnecting in 3s');
        // Try to reconnect after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            // 🔄 Fix: Reload messages from server on reconnect to prevent data loss
            _loadMessages(showLoading: false);
            _connectWebSocket();
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    await _bookingRepository.markAsRead(widget.bookingId);
  }

  Future<void> _loadMessages({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    final messages = await _bookingRepository.getMessages(widget.bookingId);
    if (mounted) {
      setState(() {
        _messages = messages;
        // Rebuild the known IDs index from server data
        _knownMessageIds.clear();
        for (final m in _messages) {
          final id = m['id'];
          if (id != null && id is int) {
            _knownMessageIds.add(id);
          }
        }
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    
    // Optimistic UI: add locally with a unique temp id
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempMessage = {
      'id': tempId,
      'message': text,
      'sender_name': 'أنت',
      'created_at': DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      'is_me': true,
    };
    
    setState(() {
      _pendingTempIds.add(tempId);
      _messages.add(tempMessage);
      _messageController.clear();
    });
    
    _scrollToBottom();
    
    // Send via WebSocket only (consumer saves to DB + broadcasts back with real id)
    bool sent = false;
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode({'message': text}));
        sent = true;
      } catch (_) {
        sent = false;
      }
    }
    
    // Fallback to REST API if WS is unavailable
    if (!sent) {
      sent = await _bookingRepository.sendMessage(widget.bookingId, text);
      if (sent) {
        // Reload from server since we used REST (no WS echo to replace optimistic)
        _pendingTempIds.remove(tempId);
        await _loadMessages(showLoading: false);
      }
    }
    
    if (mounted) {
      setState(() => _isSending = false);
      if (!sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إرسال الرسالة')),
        );
        setState(() {
          _messages.remove(tempMessage);
          _pendingTempIds.remove(tempId);
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront, color: Color(0xFFD4AF37), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.barbershopName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  const Text('دردشة الحجز', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white38),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                      ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 36, color: Color(0xFFD4AF37)),
          ),
          const SizedBox(height: 20),
          const Text('لا توجد رسائل بعد', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text('ابدأ المحادثة مع الصالون', style: TextStyle(color: Colors.white30, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['is_me'] ?? false;
    final text = message['message'] ?? '';
    final senderName = message['sender_name'] ?? '';
    final isPending = _pendingTempIds.contains(message['id']);

    // Parse created_at — supports both ISO datetime and dd/MM/yyyy HH:mm
    DateTime? createdAt;
    final rawDate = message['created_at'];
    if (rawDate != null) {
      createdAt = DateTime.tryParse(rawDate);
      if (createdAt == null) {
        try {
          createdAt = DateFormat('dd/MM/yyyy HH:mm').parse(rawDate);
        } catch (_) {}
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        // Fix: Use correct alignment for RTL — my messages on the left (end in RTL)
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            // Other party avatar
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(left: 6, bottom: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1),
              ),
              child: const Icon(Icons.person, size: 14, color: Color(0xFFD4AF37)),
            ),
          ],
          Flexible(
            child: Opacity(
              opacity: isPending ? 0.6 : 1.0,
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  // Fix: Better colors — gold gradient for me, dark card for others
                  gradient: isMe
                      ? const LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFFC9A030)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe ? null : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMe
                          ? const Color(0xFFD4AF37).withOpacity(0.15)
                          : Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe && senderName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          senderName,
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      text,
                      style: TextStyle(
                        color: isMe ? Colors.black87 : Colors.white.withOpacity(0.92),
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            createdAt != null ? DateFormat('hh:mm a', 'ar').format(createdAt) : '',
                            style: TextStyle(
                              color: isMe ? Colors.black45 : Colors.white30,
                              fontSize: 10,
                            ),
                          ),
                          if (isPending) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.access_time, size: 10, color: isMe ? Colors.black38 : Colors.white24),
                          ] else if (isMe) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.done, size: 12, color: Colors.black45),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white, fontSize: 14.5),
                  decoration: const InputDecoration(
                    hintText: 'اكتب رسالتك...',
                    hintStyle: TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFC9A030)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.send_rounded, color: Colors.black, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
