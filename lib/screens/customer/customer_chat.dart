import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';

class CustomerChatScreen extends StatefulWidget {
  const CustomerChatScreen({super.key});

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _selectedConversation;
  String? _selectedReceiverId;
  List<Map<String, dynamic>> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _showSidebar = true;
  String _searchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isSending = false;
  final ScrollController _messageScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _fetchConversations();

    Supabase.instance.client
        .channel('customer_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            if (_selectedConversation != null) {
              _fetchMessages(_selectedConversation!);
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchConversations() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final response = await Supabase.instance.client
          .from('messages')
          .select('*, profiles!sender_id(full_name, avatar_url, role, email)')
          .or('sender_id.eq.${currentUser!.id},receiver_id.eq.${currentUser.id}')
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> conversations = {};
      for (var message in response) {
        final convId = message['conversation_id'] as String;
        if (!conversations.containsKey(convId)) {
          conversations[convId] = message;
        }
      }

      setState(() {
        _conversations = conversations.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMessages(String conversationId) async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('*, profiles!sender_id(full_name, avatar_url)')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_messageScrollController.hasClients) {
          _messageScrollController.jumpTo(_messageScrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }

  Future<void> _sendMessage(String receiverId) async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final List<String> ids = [currentUser!.id, receiverId];
      ids.sort();
      final conversationId = ids.join('_');

      await Supabase.instance.client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUser.id,
        'receiver_id': receiverId,
        'message': _messageController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      _messageController.clear();
      await _fetchMessages(conversationId);
      await _fetchConversations();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_messageScrollController.hasClients) {
          _messageScrollController.jumpTo(_messageScrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  String _getOtherParticipantId() {
    if (_messages.isEmpty) return '';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    for (var message in _messages) {
      final senderId = message['sender_id'] as String;
      if (senderId != currentUserId) {
        return senderId;
      }
    }
    return '';
  }

  String _getOtherParticipantName() {
    if (_messages.isEmpty) return 'User';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    for (var message in _messages) {
      final senderId = message['sender_id'] as String;
      if (senderId != currentUserId) {
        final profile = message['profiles'] as Map<String, dynamic>?;
        return profile?['full_name'] ?? 'User';
      }
    }
    return 'User';
  }

  String? _getOtherParticipantAvatar() {
    if (_messages.isEmpty) return null;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    for (var message in _messages) {
      final senderId = message['sender_id'] as String;
      if (senderId != currentUserId) {
        final profile = message['profiles'] as Map<String, dynamic>?;
        return profile?['avatar_url'] as String?;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get _filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    return _conversations.where((conv) {
      final profile = conv['profiles'] as Map<String, dynamic>?;
      final fullName = profile?['full_name'] ?? 'User';
      return fullName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _startNewChat() async {
    try {
      final adminResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .eq('role', 'admin')
          .limit(1);
      
      if (adminResponse.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No admin available to chat')),
        );
        return;
      }
      
      final adminId = adminResponse[0]['id'];
      final currentUser = Supabase.instance.client.auth.currentUser;
      final List<String> ids = [currentUser!.id, adminId];
      ids.sort();
      final conversationId = ids.join('_');
      
      final existingConv = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .limit(1);
      
      if (existingConv.isEmpty) {
        await Supabase.instance.client.from('messages').insert({
          'conversation_id': conversationId,
          'sender_id': currentUser.id,
          'receiver_id': adminId,
          'message': 'Hello! I need assistance.',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      
      setState(() {
        _selectedConversation = conversationId;
        _selectedReceiverId = adminId;
        if (MediaQuery.of(context).size.width < 800) {
          _showSidebar = false;
        }
      });
      await _fetchMessages(conversationId);
      await _fetchConversations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting chat: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleSidebar() {
    setState(() {
      _showSidebar = !_showSidebar;
    });
  }

  String _formatMessageTime(String? dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 0) {
        return DateFormat('MMM d, y').format(dateTime);
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  String _getMessageDate(String? dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('yyyy-MM-dd').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  String _formatDate(String? dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      
      if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
        return 'Today';
      } else if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day - 1) {
        return 'Yesterday';
      } else {
        return DateFormat('MMM d, y').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 800;
    final filteredConversations = _filteredConversations;
    
    final showSidebar = isMobile ? (_selectedConversation == null ? _showSidebar : false) : _showSidebar;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            if (_selectedConversation != null) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                backgroundImage: _getOtherParticipantAvatar() != null
                    ? NetworkImage(_getOtherParticipantAvatar()!)
                    : null,
                child: _getOtherParticipantAvatar() == null
                    ? Text(
                        _getOtherParticipantName().isNotEmpty 
                            ? _getOtherParticipantName()[0].toUpperCase() 
                            : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _getOtherParticipantName(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else ...[
              const Text(
                'Chats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
        elevation: 0,
        leading: isMobile && _selectedConversation != null
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.grey.shade700,
                ),
                onPressed: () {
                  setState(() {
                    _selectedConversation = null;
                    _messages = [];
                    _showSidebar = true;
                  });
                },
              )
            : null,
        actions: [
          if (_selectedConversation == null) ...[
            IconButton(
              icon: Icon(
                Icons.search,
                color: isDark ? Colors.white : Colors.grey.shade700,
              ),
              onPressed: () {
                // Focus search
              },
            ),
            IconButton(
              icon: Icon(
                Icons.message,
                color: isDark ? Colors.white : Colors.grey.shade700,
              ),
              onPressed: _startNewChat,
              tooltip: 'New Chat',
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: isDark ? Colors.white : Colors.grey.shade700,
              ),
              onPressed: () {},
            ),
          ],
        ],
      ),
      body: Row(
        children: [
          // Sidebar - WhatsApp style
          if (!isMobile || (isMobile && _selectedConversation == null))
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isMobile ? MediaQuery.of(context).size.width : 340,
              curve: Curves.easeInOut,
              child: _buildConversationList(isDark, isMobile),
            ),
          // Chat Area
          if (_selectedConversation != null)
            Expanded(
              child: _buildChatArea(isDark, isMobile),
            ),
        ],
      ),
    );
  }

  Widget _buildConversationList(bool isDark, bool isMobile) {
    final filteredConversations = _filteredConversations;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search Bar - WhatsApp style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          // Conversations List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredConversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 60,
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No conversations',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filteredConversations.length,
                        itemBuilder: (context, index) {
                          final conv = filteredConversations[index];
                          return _buildConversationTile(conv, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conv, bool isDark) {
    final profile = conv['profiles'] as Map<String, dynamic>?;
    final fullName = profile?['full_name'] ?? 'User';
    final avatarUrl = profile?['avatar_url'] as String?;
    final isSelected = _selectedConversation == conv['conversation_id'];
    final message = conv['message']?.toString() ?? 'No message';
    final createdAt = conv['created_at'];
    final isUnread = false;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedConversation = conv['conversation_id'] as String;
          if (MediaQuery.of(context).size.width < 800) {
            _showSidebar = false;
          }
        });
        _fetchMessages(_selectedConversation!);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fullName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isDark ? Colors.white : Colors.grey.shade900,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          _formatMessageTime(createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea(bool isDark, bool isMobile) {
    final avatarUrl = _getOtherParticipantAvatar();
    final participantName = _getOtherParticipantName();
    
    return Column(
      children: [
        // Messages - WhatsApp style with date separators (Removed duplicate header)
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 60,
                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Say hello!',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _messageScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                    final isMe = message['sender_id'] == currentUserId;
                    final profile = message['profiles'] as Map<String, dynamic>?;
                    final senderName = profile?['full_name'] ?? 'User';
                    final createdAt = message['created_at'];
                    
                    final showDate = index == 0 || 
                        _getMessageDate(_messages[index - 1]['created_at']) != 
                        _getMessageDate(createdAt);
                    
                    return Column(
                      children: [
                        if (showDate)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatDate(createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe 
                                    ? Colors.blue.shade700
                                    : (isDark ? Colors.grey.shade700 : Colors.white),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Text(
                                      senderName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                    ),
                                  if (!isMe) const SizedBox(height: 2),
                                  Text(
                                    message['message']?.toString() ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatMessageTime(createdAt),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe 
                                          ? Colors.white.withOpacity(0.7)
                                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        // Message Input - WhatsApp style
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.white,
            border: Border(
              top: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.emoji_emotions_outlined,
                  color: isDark ? Colors.white : Colors.grey.shade700,
                  size: 24,
                ),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) {
                      final receiverId = _getOtherParticipantId();
                      if (receiverId.isNotEmpty) {
                        _sendMessage(receiverId);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _isSending
                    ? null
                    : () {
                        final receiverId = _getOtherParticipantId();
                        if (receiverId.isNotEmpty) {
                          _sendMessage(receiverId);
                        }
                      },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isSending ? Colors.grey.shade400 : Colors.blue.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}