import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  ChatMessage? _replyingTo;
  bool _emojiVisible = false;
  bool _translate = false;
  bool _sending = false;
  bool _firstLoad = true;
  int _lastCount = -1;
  Timer? _poll;
  final Set<String> _selectedIds = <String>{};

  bool get _selectionMode => _selectedIds.isNotEmpty;
  String get _cid => widget.conversation.id;

  /// Always read the live conversation from the provider so new messages appear immediately.
  ChatConversation _live(AppProvider app) {
    for (final c in app.conversations) {
      if (c.id == _cid) return c;
    }
    return widget.conversation;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<AppProvider>().refreshConversationMessages(_cid);
      if (!mounted) return;
      setState(() => _firstLoad = false);
      _scrollToEnd(jump: true);
    });
    // Near real-time: poll the open thread every 3 seconds.
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_sending) {
        context.read<AppProvider>().refreshConversationMessages(_cid);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _controller.text.trim();
    if (value.isEmpty || _sending) return;
    _controller.clear();
    final app = context.read<AppProvider>();
    final replyId = _replyingTo?.id;
    setState(() {
      _sending = true;
      _emojiVisible = false;
    });
    try {
      await app.sendChatMessage(_cid, value, replyToId: replyId);
      if (!mounted) return;
      setState(() => _replyingTo = null);
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      _controller.text = value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(max);
      } else {
        _scrollController.animateTo(max, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  String _displayText(ChatMessage message) {
    if (!_translate) return message.text;
    final replacements = <String, String>{
      'hello': 'habari',
      'hi': 'hujambo',
      'good morning': 'habari za asubuhi',
      'thank you': 'asante',
      'thanks': 'asante',
      'please': 'tafadhali',
      'where are you': 'uko wapi',
      'i am coming': 'nakuja',
      'ok': 'sawa',
      'yes': 'ndiyo',
      'no': 'hapana',
      'help': 'msaada',
      'driver': 'dereva',
      'ride': 'safari',
    };
    var result = message.text;
    replacements.forEach((from, to) => result = result.replaceAll(RegExp(RegExp.escape(from), caseSensitive: false), to));
    return result;
  }

  Future<void> _messageMenu(ChatMessage message) async {
    final mine = message.isMine || message.senderId == 'me';
    final app = context.read<AppProvider>();
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.reply_rounded), title: Text(app.t('Reply', 'Jibu')), onTap: () => Navigator.pop(ctx, 'reply')),
          if (mine) ListTile(leading: const Icon(Icons.edit_rounded), title: Text(app.t('Edit message', 'Hariri ujumbe')), onTap: () => Navigator.pop(ctx, 'edit')),
          ListTile(leading: const Icon(Icons.copy_rounded), title: Text(app.t('Copy text', 'Nakili maandishi')), onTap: () => Navigator.pop(ctx, 'copy')),
          if (mine) ListTile(leading: const Icon(Icons.checklist_rounded), title: Text(app.t('Select', 'Chagua')), onTap: () => Navigator.pop(ctx, 'select')),
          if (mine) ListTile(leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error), title: Text(app.t('Delete message', 'Futa ujumbe'), style: const TextStyle(color: AppColors.error)), onTap: () => Navigator.pop(ctx, 'delete')),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'reply') setState(() => _replyingTo = message);
    if (action == 'select') setState(() => _selectedIds.add(message.id));
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.t('Copied', 'Imenakiliwa'))));
      }
    }
    if (action == 'edit') _editMessage(message);
    if (action == 'delete') _deleteMessages({message.id});
  }

  Future<void> _editMessage(ChatMessage message) async {
    final app = context.read<AppProvider>();
    final ctrl = TextEditingController(text: message.text);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(app.t('Edit message', 'Hariri ujumbe')),
        content: TextField(controller: ctrl, maxLines: 4, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.t('Cancel', 'Ghairi'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(app.t('Save', 'Hifadhi'))),
        ],
      ),
    );
    if (!mounted || value == null || value.isEmpty || value == message.text) return;
    try {
      await app.editChatMessage(_cid, message.id, value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _deleteMessages(Set<String> ids) async {
    final app = context.read<AppProvider>();
    final msgs = _live(app).messages;
    final mineOnly = ids.where((id) => msgs.any((m) => m.id == id && (m.isMine || m.senderId == 'me'))).toSet();
    if (mineOnly.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(mineOnly.length == 1
            ? app.t('Delete message?', 'Futa ujumbe?')
            : app.t('Delete selected messages?', 'Futa ujumbe uliochaguliwa?')),
        content: Text(app.t('This will remove the selected messages from this chat.', 'Hii itaondoa ujumbe uliochaguliwa kutoka kwenye gumzo hili.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(app.t('Cancel', 'Ghairi'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(app.t('Delete', 'Futa'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(_selectedIds.clear);
    try {
      await app.deleteChatMessages(_cid, mineOnly);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  void _selectAllMine() {
    final msgs = _live(context.read<AppProvider>()).messages;
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(msgs.where((m) => m.isMine || m.senderId == 'me').map((m) => m.id));
    });
  }

  String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = app.isDark;
    final accent = dark ? AppColors.aquaGreen : AppColors.oceanTeal;
    final conv = _live(app);
    final messages = conv.messages;

    // Auto-scroll when a new message arrives.
    if (messages.length != _lastCount) {
      final grew = _lastCount >= 0 && messages.length > _lastCount;
      _lastCount = messages.length;
      if (grew) _scrollToEnd();
    }

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode ? Text('${_selectedIds.length} selected') : Text(conv.title),
        leading: _selectionMode ? IconButton(onPressed: () => setState(_selectedIds.clear), icon: const Icon(Icons.close)) : null,
        actions: _selectionMode
            ? [
                IconButton(onPressed: _selectAllMine, icon: const Icon(Icons.select_all_rounded)),
                IconButton(onPressed: () => _deleteMessages(_selectedIds), icon: const Icon(Icons.delete_outline_rounded)),
              ]
            : [
                Row(children: [
                  Text(app.t('Translate', 'Tafsiri'), style: const TextStyle(fontSize: 12)),
                  Switch.adaptive(value: _translate, activeColor: accent, onChanged: (v) => setState(() => _translate = v)),
                ]),
              ],
      ),
      body: Column(children: [
        Expanded(
          child: (_firstLoad && messages.isEmpty)
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          app.t('No messages yet. Say hello 👋', 'Hakuna ujumbe bado. Sema habari 👋'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final mine = message.isMine || message.senderId == 'me';
                        final selected = _selectedIds.contains(message.id);
                        ChatMessage? replied;
                        if (message.replyToId != null) {
                          for (final m in messages) {
                            if (m.id == message.replyToId) {
                              replied = m;
                              break;
                            }
                          }
                        }
                        return GestureDetector(
                          onLongPress: () => _messageMenu(message),
                          onHorizontalDragEnd: (details) {
                            if ((details.primaryVelocity ?? 0).abs() > 180) setState(() => _replyingTo = message);
                          },
                          onTap: _selectionMode && mine
                              ? () => setState(() => selected ? _selectedIds.remove(message.id) : _selectedIds.add(message.id))
                              : null,
                          child: Container(
                            color: selected ? accent.withOpacity(.08) : Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Align(
                              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 7),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .80),
                                decoration: BoxDecoration(
                                  color: mine ? accent : (dark ? AppColors.darkCard : AppColors.lightCard),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(17),
                                    topRight: const Radius.circular(17),
                                    bottomLeft: Radius.circular(mine ? 17 : 5),
                                    bottomRight: Radius.circular(mine ? 5 : 17),
                                  ),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  if (message.replyToId != null)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(7),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(.10), borderRadius: BorderRadius.circular(8)),
                                      child: Text(
                                        replied?.text ?? app.t('Replying to a message', 'Kujibu ujumbe'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : null),
                                      ),
                                    ),
                                  Text(_displayText(message), style: TextStyle(color: mine ? Colors.white : null)),
                                  const SizedBox(height: 3),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      '${message.isEdited ? '${app.t('edited', 'imehaririwa')} · ' : ''}${_hhmm(message.timestamp)}',
                                      style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : Colors.grey),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        if (_replyingTo != null && !_selectionMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: dark ? AppColors.darkCard : AppColors.lightCard,
            child: Row(children: [
              const Icon(Icons.reply_rounded),
              const SizedBox(width: 8),
              Expanded(child: Text(_replyingTo!.text, maxLines: 1, overflow: TextOverflow.ellipsis)),
              IconButton(onPressed: () => setState(() => _replyingTo = null), icon: const Icon(Icons.close)),
            ]),
          ),
        if (_emojiVisible && !_selectionMode)
          SizedBox(
            height: 250,
            child: EmojiPicker(onEmojiSelected: (_, emoji) {
              _controller.text += emoji.emoji;
              _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
            }),
          ),
        if (!_selectionMode)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
              child: Row(children: [
                IconButton(onPressed: () => setState(() => _emojiVisible = !_emojiVisible), icon: const Icon(Icons.emoji_emotions_outlined)),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onTap: () => setState(() => _emojiVisible = false),
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: app.t('Type a message...', 'Andika ujumbe...'),
                      filled: true,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24)), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  backgroundColor: accent,
                  child: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded, color: Colors.white)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
