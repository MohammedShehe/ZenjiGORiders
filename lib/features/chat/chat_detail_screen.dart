import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_model.dart';
import '../../providers/app_provider.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatConversation conversation;
  const ChatDetailScreen({super.key, required this.conversation});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  ChatMessage? _replyingTo;
  bool _emojiVisible = false;
  bool _translate = false;

  @override
  void initState() {
    super.initState();
    _syncMessages();
  }

  void _syncMessages() {
    final app = context.read<AppProvider>();
    final live = app.conversations.where((c) => c.id == widget.conversation.id).toList();
    final source = live.isNotEmpty ? live.first.messages : widget.conversation.messages;
    _messages = List<ChatMessage>.from(source);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    final msg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      senderId: 'me',
      text: value,
      replyToId: _replyingTo?.id,
    );
    setState(() {
      _messages.add(msg);
      _controller.clear();
      _replyingTo = null;
      _emojiVisible = false;
    });
    // Persist into provider so reopening the chat keeps messages
    context.read<AppProvider>().addMessage(widget.conversation.id, msg);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _displayText(ChatMessage message) {
    if (!_translate) return message.text;
    final replacements = <String, String>{
      'hello': 'habari',
      'hi': 'hujambo',
      'thank you': 'asante',
      'ok': 'sawa',
    };
    var result = message.text;
    replacements.forEach((from, to) {
      result = result.replaceAll(RegExp(from, caseSensitive: false), to);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = app.isDark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversation.title),
        actions: [
          IconButton(
            onPressed: () => setState(() => _translate = !_translate),
            icon: Icon(_translate ? Icons.translate : Icons.g_translate),
            tooltip: 'Translate',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final mine = message.senderId == 'me';
                return GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0).abs() > 180) {
                      setState(() => _replyingTo = message);
                    }
                  },
                  child: Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * .78,
                      ),
                      decoration: BoxDecoration(
                        color: mine
                            ? (dark ? AppColors.aquaGreen : AppColors.oceanTeal)
                            : (dark ? AppColors.darkCard : AppColors.lightCard),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.replyToId != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(7),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Replying to a message',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          Text(
                            _displayText(message),
                            style: TextStyle(color: mine ? Colors.white : null),
                          ),
                          const SizedBox(height: 3),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10,
                                color: mine ? Colors.white70 : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: dark ? AppColors.darkCard : AppColors.lightCard,
              child: Row(
                children: [
                  const Icon(Icons.reply),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _replyingTo!.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _replyingTo = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          if (_emojiVisible)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) {
                  _controller.text += emoji.emoji;
                  _controller.selection = TextSelection.collapsed(
                    offset: _controller.text.length,
                  );
                },
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _emojiVisible = !_emojiVisible),
                    icon: const Icon(Icons.emoji_emotions_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onTap: () => setState(() => _emojiVisible = false),
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Message text copied.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                  ),
                  CircleAvatar(
                    backgroundColor: dark ? AppColors.aquaGreen : AppColors.oceanTeal,
                    child: IconButton(
                      onPressed: _send,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
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
