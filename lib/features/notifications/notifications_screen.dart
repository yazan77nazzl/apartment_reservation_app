import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/common.dart';
import '../../core/l10n.dart';
import '../../services/housing_repository.dart';
import '../../services/session.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    return Scaffold(
        appBar: AppBar(title: Text(context.tr('Notifications'))),
        body: RecordsView(
            stream: repo.records('notifications',
                field: 'userId',
                value: ref.watch(sessionProvider).user!.uid,
                order: 'createdAt'),
            builder: (all) => PageBody(children: [
                  BusyButton(
                      label: 'Enable push notifications',
                      icon: Icons.notifications_active_outlined,
                      action: () async {
                        await ref.read(sessionProvider).enablePush();
                        if (context.mounted) {
                          notice(context, 'Push notifications enabled');
                        }
                      }),
                  if (all.isEmpty)
                    EmptyState(text: context.tr('No notifications yet')),
                  ...all.map((n) => Card(
                      child: ListTile(
                          leading: Icon(n.b('read')
                              ? Icons.notifications_none
                              : Icons.notifications_active),
                          title: Text(context.tr(n.s('title'))),
                          subtitle: Text(context.tr(n.s('body'))),
                          onTap: () async {
                            await perform(
                                context, () => repo.readNotification(n.id));
                            if (context.mounted &&
                                n.s('reservationId').isNotEmpty) {
                              context.push(
                                  '/reservations/${n.s('reservationId')}');
                            }
                          }))),
                ])));
  }
}
