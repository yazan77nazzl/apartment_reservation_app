import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/common.dart';
import '../../core/l10n.dart';
import '../../models/record.dart';
import '../../services/housing_repository.dart';
import '../../services/session.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    return RecordsView(
        stream: ref.read(repositoryProvider).records('chats',
            field: 'participants',
            value: s.user!.uid,
            array: true,
            order: 'updatedAt'),
        builder: (chats) => PageBody(children: [
              heading(context, 'Messages'),
              if (chats.isEmpty)
                EmptyState(
                    text: context
                        .tr('Start a conversation from an apartment page')),
              ...chats.map((c) => Card(
                  child: ListTile(
                      leading:
                          const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(c
                          .s(s.profile!.isOwner ? 'studentName' : 'ownerName')),
                      subtitle: Text(c.s('latestMessage'),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/chats/${c.id}'))))
            ]));
  }
}

class ConversationScreen extends ConsumerStatefulWidget {
  final String id;
  const ConversationScreen({super.key, required this.id});
  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final body = TextEditingController();
  late final Stream<List<Record>> messages;
  String? lastReadMessage;
  @override
  void initState() {
    super.initState();
    messages = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.id)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs.map(Record.fromDoc).toList());
  }

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider), repo = ref.read(repositoryProvider);
    return Scaffold(
        appBar: AppBar(title: Text(context.tr('Conversation'))),
        body: RecordView(
            stream: repo.document('chats', widget.id),
            builder: (chat) => Column(children: [
                  ListTile(
                      title: Text(chat
                          .s(s.profile!.isOwner ? 'studentName' : 'ownerName')),
                      subtitle: Text(context.tr(
                          'Messages are visible to conversation participants'))),
                  Expanded(
                      child: RecordsView(
                          stream: messages,
                          builder: (all) {
                            if (all.isNotEmpty &&
                                all.first.id != lastReadMessage) {
                              lastReadMessage = all.first.id;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  perform(
                                      context,
                                      () => repo.call('markChatRead',
                                          {'chatId': widget.id}));
                                }
                              });
                            }
                            if (all.isEmpty) {
                              return EmptyState(text: context.tr('Say hello'));
                            }
                            final other = chat
                                .list('participants')
                                .firstWhere((id) => id != s.user!.uid);
                            final readAt = (chat.data['readAt'] as Map?)?[other]
                                as Timestamp?;
                            return ListView.builder(
                                reverse: true,
                                padding: const EdgeInsets.all(16),
                                itemCount: all.length,
                                itemBuilder: (context, i) {
                                  final m = all[i],
                                      mine = m.s('senderId') == s.user!.uid;
                                  final read = readAt != null &&
                                      m.time('createdAt') != null &&
                                      !readAt
                                          .toDate()
                                          .isBefore(m.time('createdAt')!);
                                  return Align(
                                      alignment: mine
                                          ? AlignmentDirectional.centerEnd
                                          : AlignmentDirectional.centerStart,
                                      child: Container(
                                          constraints: const BoxConstraints(
                                              maxWidth: 340),
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                              color: mine
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(m.s('body')),
                                                const SizedBox(height: 6),
                                                Text(
                                                    '${m.time('createdAt')?.toLocal().toString().substring(0, 16) ?? context.tr('Sending')} ${mine && read ? '✓✓' : ''}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall)
                                              ])));
                                });
                          })),
                  SafeArea(
                      top: false,
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Expanded(
                                child: TextField(
                                    controller: body,
                                    maxLines: 3,
                                    minLines: 1,
                                    decoration: InputDecoration(
                                        hintText: context.tr('Message')))),
                            const SizedBox(width: 8),
                            BusyButton(
                                label: 'Send',
                                icon: Icons.send,
                                action: () async {
                                  final text = body.text.trim();
                                  if (text.isEmpty) return;
                                  await repo.call('sendMessage',
                                      {'chatId': widget.id, 'body': text});
                                  if (mounted && body.text.trim() == text) {
                                    body.clear();
                                  }
                                })
                          ]))),
                ])));
  }
}
