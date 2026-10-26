import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_colors.dart';
import '../../models/ride_model.dart';
import '../../providers/app_provider.dart';
import '../../core/api/rider_api.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppProvider>().refreshConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = app.isDark;
    final chats = app.conversations.where((chat) {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return chat.title.toLowerCase().contains(q) ||
          chat.lastMessagePreview.toLowerCase().contains(q) ||
          chat.messages.any((m) => m.text.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.lastMessageAt.compareTo(a.lastMessageAt);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(app.t('Chats', 'Mazungumzo')),
        actions: [
          IconButton(
            tooltip: 'Support',
            icon: const Icon(Icons.support_agent),
            onPressed: () async {
              try {
                final conv = await context.read<AppProvider>().openSupportChat();
                if (conv != null && mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(conversation: conv)));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final result = await showSearch<String>(
                context: context,
                delegate: _ChatSearchDelegate(app.conversations),
              );
              if (result != null && mounted) setState(() => query = result);
            },
          ),
        ],
      ),
      body: chats.isEmpty
          ? RefreshIndicator(
              onRefresh: () => context.read<AppProvider>().refreshConversations(),
              child: ListView(children: [
                SizedBox(height: MediaQuery.of(context).size.height * .3),
                Center(child: Text(app.t('No chats yet', 'Hakuna mazungumzo bado'))),
              ]),
            )
          : RefreshIndicator(
              onRefresh: () => context.read<AppProvider>().refreshConversations(),
              child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final preview = chat.lastMessagePreview.isNotEmpty
                    ? chat.lastMessagePreview
                    : (chat.messages.isEmpty ? '' : chat.messages.last.text);
                return Dismissible(
                  key: ValueKey(chat.id),
                  direction: chat.isSupport
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  background: Container(
                    color: AppColors.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Conversation deletion is not supported by the current backend API.')),
                    );
                    return false;
                  },
                  onDismissed: (_) {},
                  child: ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(conversation: chat),
                      ),
                    ).then((_) {
                      if (mounted) context.read<AppProvider>().refreshConversations();
                    }),
                    leading: CircleAvatar(
                      backgroundColor: chat.isSupport
                          ? (dark ? AppColors.aquaGreen : AppColors.oceanTeal)
                          : Colors.grey.shade400,
                      child: chat.isSupport
                          ? const Icon(Icons.support_agent, color: Colors.white)
                          : Text(
                              chat.title.isEmpty ? '?' : chat.title[0],
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(chat.title)),
                        if (chat.isPinned)
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: dark ? AppColors.aquaGreen : AppColors.oceanTeal,
                          ),
                      ],
                    ),
                    subtitle: Text(
                      preview.isEmpty ? app.t('No messages yet', 'Hakuna ujumbe bado') : preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: chat.unreadCount > 0 ? FontWeight.w700 : FontWeight.normal),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (preview.isNotEmpty)
                          Text(
                            timeago.format(chat.lastMessageAt, locale: app.isSwahili ? 'sw' : 'en'),
                            style: const TextStyle(fontSize: 11),
                          ),
                        if (chat.unreadCount > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: dark ? AppColors.aquaGreen : AppColors.oceanTeal,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${chat.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            ),
    );
  }
}

class _ChatSearchDelegate extends SearchDelegate<String> {
  final List<ChatConversation> chats;
  _ChatSearchDelegate(this.chats);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, ''),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final q = query.trim().toLowerCase();
    final matches = chats.where((chat) {
      if (q.isEmpty) return true;
      return chat.title.toLowerCase().contains(q) ||
          chat.lastMessagePreview.toLowerCase().contains(q) ||
          chat.messages.any((m) => m.text.toLowerCase().contains(q));
    }).toList();

    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (_, index) {
        final chat = matches[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
          title: Text(chat.title),
          subtitle: Text(
            chat.lastMessagePreview.isNotEmpty ? chat.lastMessagePreview : (chat.messages.isEmpty ? '' : chat.messages.last.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => close(context, chat.title),
        );
      },
    );
  }
}
