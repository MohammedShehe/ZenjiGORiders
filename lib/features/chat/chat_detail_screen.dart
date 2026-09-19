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
  final Set<String> _selectedIds = <String>{};

  bool get _selectionMode => _selectedIds.isNotEmpty;

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
    context.read<AppProvider>().addMessage(widget.conversation.id, msg);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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
    final mine = message.senderId == 'me';
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.reply_rounded), title: const Text('Reply'), onTap: () => Navigator.pop(ctx, 'reply')),
          if (mine) ListTile(leading: const Icon(Icons.edit_rounded), title: const Text('Edit message'), onTap: () => Navigator.pop(ctx, 'edit')),
          ListTile(leading: const Icon(Icons.copy_rounded), title: const Text('Copy text'), onTap: () => Navigator.pop(ctx, 'copy')),
          ListTile(leading: const Icon(Icons.checklist_rounded), title: const Text('Select'), onTap: () => Navigator.pop(ctx, 'select')),
          if (mine) ListTile(leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error), title: const Text('Delete message', style: TextStyle(color: AppColors.error)), onTap: () => Navigator.pop(ctx, 'delete')),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'reply') setState(() => _replyingTo = message);
    if (action == 'select') setState(() => _selectedIds.add(message.id));
    if (action == 'copy') {
      await showDialog<void>(context: context, builder: (_) => AlertDialog(content: SelectableText(message.text), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))]));
    }
    if (action == 'edit') _editMessage(message);
    if (action == 'delete') _deleteMessages({message.id});
  }

  Future<void> _editMessage(ChatMessage message) async {
    final ctrl = TextEditingController(text: message.text);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: ctrl, maxLines: 4, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (!mounted || value == null || value.isEmpty) return;
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index < 0) return;
    final edited = ChatMessage(id: message.id, senderId: message.senderId, text: value, timestamp: message.timestamp, replyToId: message.replyToId);
    setState(() => _messages[index] = edited);
    _replaceConversationMessages();
  }

  Future<void> _deleteMessages(Set<String> ids) async {
    final mineOnly = ids.where((id) => _messages.any((m) => m.id == id && m.senderId == 'me')).toSet();
    if (mineOnly.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(mineOnly.length == 1 ? 'Delete message?' : 'Delete selected messages?'),
        content: const Text('This will remove the selected messages from this chat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _messages.removeWhere((m) => mineOnly.contains(m.id));
      _selectedIds.clear();
    });
    _replaceConversationMessages();
  }

  void _replaceConversationMessages() {
    final app = context.read<AppProvider>();
    final current = app.conversations.where((c) => c.id == widget.conversation.id).toList();
    if (current.isEmpty) return;
    app.addOrUpdateConversation(current.first.copyWith(messages: List<ChatMessage>.from(_messages)));
  }

  void _selectAllMine() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(_messages.where((m) => m.senderId == 'me').map((m) => m.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = app.isDark;
    final accent = dark ? AppColors.aquaGreen : AppColors.oceanTeal;

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode ? Text('${_selectedIds.length} selected') : Text(widget.conversation.title),
        leading: _selectionMode ? IconButton(onPressed: () => setState(_selectedIds.clear), icon: const Icon(Icons.close)) : null,
        actions: _selectionMode
            ? [
                IconButton(onPressed: _selectAllMine, icon: const Icon(Icons.select_all_rounded)),
                IconButton(onPressed: () => _deleteMessages(_selectedIds), icon: const Icon(Icons.delete_outline_rounded)),
              ]
            : [
                if (!widget.conversation.isSupport) IconButton(onPressed: () => _confirmDeleteChat(app), icon: const Icon(Icons.delete_outline_rounded)),
                Row(children: [const Text('Translate', style: TextStyle(fontSize: 12)), Switch.adaptive(value: _translate, activeColor: accent, onChanged: (v) => setState(() => _translate = v))]),
              ],
      ),
      body: Column(children: [
        if (!_selectionMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            color: accent.withOpacity(.08),
            child: Row(children: [Icon(Icons.translate_rounded, color: accent, size: 18), const SizedBox(width: 8), Expanded(child: Text(app.t('Translation preview: English ↔ Kiswahili', 'Tafsiri: Kiingereza ↔ Kiswahili'), style: const TextStyle(fontSize: 12))), Text(_translate ? 'ON' : 'OFF', style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 11))]),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final mine = message.senderId == 'me';
              final selected = _selectedIds.contains(message.id);
              return GestureDetector(
                onLongPress: () => _messageMenu(message),
                onHorizontalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0).abs() > 180) setState(() => _replyingTo = message);
                },
                onTap: _selectionMode && mine ? () => setState(() => selected ? _selectedIds.remove(message.id) : _selectedIds.add(message.id)) : null,
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
                        color: mine ? (dark ? AppColors.aquaGreen : AppColors.oceanTeal) : (dark ? AppColors.darkCard : AppColors.lightCard),
                        borderRadius: BorderRadius.only(topLeft: const Radius.circular(17), topRight: const Radius.circular(17), bottomLeft: Radius.circular(mine ? 17 : 5), bottomRight: Radius.circular(mine ? 5 : 17)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (message.replyToId != null) Container(width: double.infinity, padding: const EdgeInsets.all(7), margin: const EdgeInsets.only(bottom: 6), decoration: BoxDecoration(color: Colors.black.withOpacity(.10), borderRadius: BorderRadius.circular(8)), child: const Text('Replying to a message', style: TextStyle(fontSize: 11))),
                        Text(_displayText(message), style: TextStyle(color: mine ? Colors.white : null)),
                        const SizedBox(height: 3),
                        Align(alignment: Alignment.bottomRight, child: Text('${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : Colors.grey))),
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
            child: Row(children: [const Icon(Icons.reply_rounded), const SizedBox(width: 8), Expanded(child: Text(_replyingTo!.text, maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(onPressed: () => setState(() => _replyingTo = null), icon: const Icon(Icons.close))]),
          ),
        if (_emojiVisible && !_selectionMode) SizedBox(height: 250, child: EmojiPicker(onEmojiSelected: (_, emoji) { _controller.text += emoji.emoji; _controller.selection = TextSelection.collapsed(offset: _controller.text.length); })),
        if (!_selectionMode)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
              child: Row(children: [
                IconButton(onPressed: () => setState(() => _emojiVisible = !_emojiVisible), icon: const Icon(Icons.emoji_emotions_outlined)),
                Expanded(child: TextField(controller: _controller, onTap: () => setState(() => _emojiVisible = false), onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Type a message...', filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24)), borderSide: BorderSide.none)))),
                const SizedBox(width: 6),
                CircleAvatar(backgroundColor: accent, child: IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded, color: Colors.white))),
              ]),
            ),
          ),
      ]),
    );
  }

  Future<void> _confirmDeleteChat(AppProvider app) async {
    if (widget.conversation.isSupport) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(app.t('Delete entire chat?', 'Futa mazungumzo yote?')), content: Text(app.t('This conversation will be removed from your chat list.', 'Mazungumzo haya yataondolewa kwenye orodha yako.')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(app.t('Cancel', 'Ghairi'))), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(app.t('Delete', 'Futa')))]));
    if (ok == true && mounted) {
      app.deleteConversation(widget.conversation.id);
      Navigator.pop(context);
    }
  }
}
