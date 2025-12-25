import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/network/seller_api.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';

class ConversationDto {
  ConversationDto({required this.id, required this.name, required this.title, required this.image});

  final int id;
  final String name;
  final String title;
  final String image;

  factory ConversationDto.fromJson(Map<String, dynamic> json) {
    return ConversationDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
    );
  }
}

class MessageDto {
  MessageDto({
    required this.id,
    required this.userId,
    required this.sendType,
    required this.message,
    required this.dateLabel,
    required this.timeLabel,
  });

  final int id;
  final int userId;
  final String sendType;
  final String message;
  final String dateLabel;
  final String timeLabel;

  bool get outgoing => sendType == 'seller';

  factory MessageDto.fromJson(Map<String, dynamic> json) {
    return MessageDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      userId: int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      sendType: (json['send_type'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      dateLabel: (json['date'] ?? '').toString(),
      timeLabel: (json['time'] ?? '').toString(),
    );
  }
}

class ConversationsState {
  const ConversationsState({this.loading = false, this.items = const [], this.error});

  final bool loading;
  final List<ConversationDto> items;
  final String? error;

  ConversationsState copyWith({bool? loading, List<ConversationDto>? items, String? error}) {
    return ConversationsState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      error: error,
    );
  }
}

final conversationsControllerProvider =
    StateNotifierProvider<ConversationsController, ConversationsState>((ref) {
  final api = ref.watch(sellerApiProvider);
  return ConversationsController(api)..load();
});

class ConversationsController extends StateNotifier<ConversationsState> {
  ConversationsController(this.api) : super(const ConversationsState());
  final SellerApi api;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await api.fetchConversations();
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? const []) : const [];
      final items = list
          .whereType<Map>()
          .map((e) => ConversationDto.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id != 0)
          .toList();
      state = state.copyWith(loading: false, items: items);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<List<MessageDto>> loadMessages(int conversationId) async {
    final res = await api.fetchConversationMessages(conversationId);
    final data = res.data;
    final list = data is Map<String, dynamic> ? (data['data'] as List? ?? const []) : const [];
    return list
        .whereType<Map>()
        .map((e) => MessageDto.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id != 0)
        .toList();
  }

  Future<void> sendMessage(int conversationId, String message) async {
    await api.sendConversationMessage(conversationId: conversationId, message: message);
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.conversationId});
  final int? conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  bool _openedInitial = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsControllerProvider);
    ref.listen<ConversationsState>(conversationsControllerProvider, (prev, next) {
      if (_openedInitial) return;
      final targetId = widget.conversationId;
      if (targetId == null) return;
      ConversationDto? match;
      for (final convo in next.items) {
        if (convo.id == targetId) {
          match = convo;
          break;
        }
      }
      if (match != null) {
        _openedInitial = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _openThread(context, ref, match!);
        });
      }
    });

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Messages', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(conversationsControllerProvider.notifier).load(),
          ),
        ],
      ),
      body: state.loading && state.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(conversationsControllerProvider.notifier).load(),
              child: ListView.builder(
                padding: DesignTokens.paddingScreen,
                itemCount: state.items.length + (state.items.isEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  if (state.items.isEmpty) {
                    return _EmptyConversationsState(error: state.error);
                  }
                  final convo = state.items[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
                    decoration: BoxDecoration(
                      color: DesignTokens.surfaceWhite,
                      borderRadius: DesignTokens.borderRadiusMd,
                      boxShadow: DesignTokens.shadowSm,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: DesignTokens.brandAccent.withOpacity(0.12),
                        child: const Icon(Icons.chat_bubble_outline, color: DesignTokens.brandAccent),
                      ),
                      title: Text(convo.name.isEmpty ? 'Conversation' : convo.name, style: DesignTokens.textBodyBold),
                      subtitle: Text(
                        convo.title,
                        style: DesignTokens.textSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right, color: DesignTokens.grayMedium),
                      onTap: () => _openThread(context, ref, convo),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _openThread(BuildContext context, WidgetRef ref, ConversationDto convo) {
    BottomSheetModal.show(
      context: context,
      title: convo.name.isEmpty ? 'Conversation' : convo.name,
      subtitle: convo.title.isEmpty ? null : convo.title,
      maxHeight: 600,
      child: _ThreadSheet(conversation: convo),
    );
  }
}

class _ThreadSheet extends ConsumerStatefulWidget {
  const _ThreadSheet({required this.conversation});
  final ConversationDto conversation;

  @override
  ConsumerState<_ThreadSheet> createState() => _ThreadSheetState();
}

class _ThreadSheetState extends ConsumerState<_ThreadSheet> {
  late Future<List<MessageDto>> _future;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = ref.read(conversationsControllerProvider.notifier).loadMessages(widget.conversation.id);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = ref.read(conversationsControllerProvider.notifier).loadMessages(widget.conversation.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: FutureBuilder<List<MessageDto>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load messages: ${snapshot.error}', style: DesignTokens.textBody));
              }
              final messages = snapshot.data ?? const [];
              if (messages.isEmpty) {
                return Center(child: Text('No messages yet', style: DesignTokens.textSmall));
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSm),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return Align(
                    alignment: msg.outgoing ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: DesignTokens.spaceXs,
                        horizontal: DesignTokens.spaceSm,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceMd,
                        vertical: DesignTokens.spaceSm,
                      ),
                      decoration: BoxDecoration(
                        color: msg.outgoing
                            ? DesignTokens.brandAccent.withOpacity(0.12)
                            : DesignTokens.grayLight.withOpacity(0.35),
                        borderRadius: DesignTokens.borderRadiusMd,
                      ),
                      child: Column(
                        crossAxisAlignment: msg.outgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(msg.message, style: DesignTokens.textBody),
                          const SizedBox(height: DesignTokens.spaceXs),
                          Text('${msg.dateLabel} ${msg.timeLabel}', style: DesignTokens.textSmall),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: EdgeInsets.only(
            left: DesignTokens.spaceMd,
            right: DesignTokens.spaceMd,
            bottom: MediaQuery.of(context).viewInsets.bottom + DesignTokens.spaceSm,
            top: DesignTokens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: DesignTokens.surfaceWhite,
            border: Border(top: BorderSide(color: DesignTokens.grayLight.withOpacity(0.7))),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    hintText: 'Type a reply…',
                    prefixIcon: Icon(Icons.message_outlined),
                  ),
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              IconButton(
                tooltip: 'Send',
                onPressed: () async {
                  final text = _ctrl.text.trim();
                  if (text.isEmpty) return;
                  _ctrl.clear();
                  await ref.read(conversationsControllerProvider.notifier).sendMessage(widget.conversation.id, text);
                  if (!mounted) return;
                  _refresh();
                },
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyConversationsState extends StatelessWidget {
  const _EmptyConversationsState({this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DesignTokens.paddingMd,
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: DesignTokens.grayMedium),
          const SizedBox(height: DesignTokens.spaceMd),
          Text('No conversations', style: DesignTokens.textBodyBold),
          if (error != null) ...[
            const SizedBox(height: DesignTokens.spaceSm),
            Text(error!, style: DesignTokens.textSmall, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
