import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/common.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n.dart';
import '../../models/record.dart';
import '../../services/housing_repository.dart';
import '../../services/session.dart';

class ReservationRequestScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? parentId;
  const ReservationRequestScreen(
      {super.key, required this.roomId, this.parentId});
  @override
  ConsumerState<ReservationRequestScreen> createState() =>
      _ReservationRequestState();
}

class _ReservationRequestState extends ConsumerState<ReservationRequestScreen> {
  DateTime? start, end;
  bool initialized = false;
  Future<void> selectDates() async {
    final now = DateTime.now(), today = DateTime(now.year, now.month, now.day);
    final range = await showDateRangePicker(
        context: context,
        firstDate: today,
        lastDate: today.add(const Duration(days: 730)),
        initialDateRange:
            start != null && end != null && !start!.isBefore(today)
                ? DateTimeRange(start: start!, end: end!)
                : null);
    if (range != null && mounted) {
      setState(() {
        start = range.start;
        end = range.end;
      });
    }
  }

  Widget content(Record room) {
    final days = start == null || end == null
        ? 0
        : DateTime.utc(end!.year, end!.month, end!.day)
            .difference(DateTime.utc(start!.year, start!.month, start!.day))
            .inDays;
    final amount = room.i('priceMinor') * (days / 30).ceil();
    return PageBody(children: [
      heading(
          context,
          widget.parentId == null
              ? 'Request reservation'
              : 'Renew reservation'),
      Info('Room', room.s('number')),
      Info('Monthly price', money(room.i('priceMinor'))),
      Text(context.tr(
          'Whole-room booking. Price is rounded up to 30-day rental months.')),
      OutlinedButton.icon(
          onPressed: selectDates,
          icon: const Icon(Icons.date_range),
          label: Text(context.tr('Choose dates'))),
      if (start != null) Info('Start date', isoDay(start!)),
      if (end != null) Info('End date', isoDay(end!)),
      if (days > 0) Info('Total', money(amount)),
      Text(context.tr('The owner must approve your request before payment')),
      BusyButton(
          label: 'Submit request',
          action: () async {
            if (days < 1 || days > 366) {
              throw StateError('Choose a stay of 1–366 days');
            }
            final result =
                await ref.read(repositoryProvider).call('submitReservation', {
              'roomId': widget.roomId,
              'start': isoDay(start!),
              'end': isoDay(end!),
              'parentId': widget.parentId
            });
            if (mounted) context.go('/reservations/${result['id']}');
          })
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    return Scaffold(
        appBar: AppBar(title: Text(context.tr('Reservation request'))),
        body: RecordView(
            stream: repo.document('rooms', widget.roomId),
            builder: (room) => widget.parentId == null
                ? content(room)
                : RecordView(
                    stream: repo.document('reservations', widget.parentId!),
                    builder: (parent) {
                      if (!initialized) {
                        initialized = true;
                        final now = DateTime.now();
                        final previousEnd = DateTime.parse(parent.s('end'));
                        start = previousEnd.isAfter(now)
                            ? previousEnd
                            : DateTime(now.year, now.month, now.day);
                        end = start!.add(const Duration(days: 30));
                      }
                      return content(room);
                    })));
  }
}

class ReservationsScreen extends ConsumerWidget {
  final bool requestsOnly;
  const ReservationsScreen({super.key, this.requestsOnly = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider), repo = ref.read(repositoryProvider);
    return RecordsView(
        stream: repo.records('reservations',
            field: s.profile!.isOwner ? 'ownerId' : 'studentId',
            value: s.user!.uid),
        builder: (all) {
          all.sort((a, b) => b.s('start').compareTo(a.s('start')));
          final visible = all
              .where((r) => !requestsOnly || r.s('status') == 'pending')
              .toList();
          final active = visible
              .where((r) => ['pending', 'awaiting_payment', 'confirmed']
                  .contains(r.displayStatus))
              .toList();
          final history = visible.where((r) => !active.contains(r)).toList();
          return PageBody(children: [
            heading(context,
                requestsOnly ? 'Reservation requests' : 'Reservations'),
            if (visible.isEmpty)
              EmptyState(text: context.tr('No reservations yet')),
            if (active.isNotEmpty) heading(context, 'Active and pending'),
            ...active.map((r) => ReservationCard(reservation: r)),
            if (history.isNotEmpty) heading(context, 'Previous reservations'),
            ...history.map((r) => ReservationCard(reservation: r))
          ]);
        });
  }
}

class ReservationCard extends StatelessWidget {
  final Record reservation;
  const ReservationCard({super.key, required this.reservation});
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          isThreeLine: true,
          title: Text(
              '${reservation.s('apartmentTitle')} · ${context.tr('Room')} ${reservation.s('roomNumber')}'),
          subtitle: Text(
              '${reservation.s('start')} → ${reservation.s('end')}\n${context.tr(reservation.displayStatus)} · ${money(reservation.i('amountMinor'))}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/reservations/${reservation.id}')));
}

class ReservationDetailScreen extends ConsumerWidget {
  final String id;
  const ReservationDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider), s = ref.watch(sessionProvider);
    return Scaffold(
        appBar: AppBar(title: Text(context.tr('Reservation details'))),
        body: RecordView(
            stream: repo.document('reservations', id),
            builder: (r) => PageBody(children: [
                  heading(context, r.s('apartmentTitle')),
                  Chip(label: Text(context.tr(r.displayStatus))),
                  Info('Room', r.s('roomNumber')),
                  Info('Start date', r.s('start')),
                  Info('Expiration date', r.s('end')),
                  Info('Total', money(r.i('amountMinor'))),
                  Info('Payment status', context.tr(r.s('paymentStatus'))),
                  if (r.s('status') == 'awaiting_payment')
                    Info(
                        'Payment deadline',
                        DateTime.fromMillisecondsSinceEpoch(
                                r.i('holdExpiresAt'))
                            .toLocal()
                            .toString()),
                  if (s.profile!.isOwner) ...[
                    Info('Student', r.s('studentName')),
                    Info('Address', r.s('studentAddress')),
                    Info('Phone', r.s('studentPhone'))
                  ],
                  if (s.profile!.isOwner && r.s('status') == 'pending') ...[
                    BusyButton(
                        label: 'Approve request',
                        icon: Icons.check,
                        action: () async {
                          await repo.call('decideReservation',
                              {'id': id, 'action': 'approve'});
                        }),
                    BusyButton(
                        label: 'Reject request',
                        icon: Icons.close,
                        action: () async {
                          await repo.call('decideReservation',
                              {'id': id, 'action': 'reject'});
                        }),
                  ],
                  if (!s.profile!.isOwner &&
                      r.displayStatus == 'awaiting_payment')
                    FilledButton(
                        onPressed: () =>
                            context.push('/reservations/$id/payment'),
                        child: Text(context.tr('Proceed to payment'))),
                  if (['pending', 'awaiting_payment'].contains(r.s('status')))
                    BusyButton(
                        label: 'Cancel request',
                        action: () async {
                          await repo.call('cancelReservation', {'id': id});
                        }),
                  if (!s.profile!.isOwner &&
                      ['confirmed', 'completed'].contains(r.s('status'))) ...[
                    FilledButton(
                        onPressed: () => context
                            .push('/rooms/${r.s('roomId')}/request?parent=$id'),
                        child: Text(context.tr('Renew reservation'))),
                    if (r.s('start').compareTo(isoDay(DateTime.now())) <= 0)
                      FilledButton(
                          onPressed: () => context.push(
                              '/apartments/${r.s('apartmentId')}/reviews?reservation=$id'),
                          child: Text(context.tr('Rate and review'))),
                  ],
                  OutlinedButton(
                      onPressed: () =>
                          context.push('/apartments/${r.s('apartmentId')}'),
                      child: Text(context.tr('Apartment details'))),
                ])));
  }
}

class PaymentScreen extends ConsumerWidget {
  final String id;
  const PaymentScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    Future<void> pay(String outcome) async {
      final result =
          await repo.call('demoPayment', {'id': id, 'outcome': outcome});
      if (context.mounted) {
        notice(
            context,
            result['status'] == 'succeeded'
                ? 'Sandbox payment succeeded. No money transferred.'
                : 'Sandbox payment declined. You can retry.');
        if (result['status'] == 'succeeded') context.go('/reservations/$id');
      }
    }

    return Scaffold(
        appBar: AppBar(title: Text(context.tr('Payment'))),
        body: RecordView(
            stream: repo.document('reservations', id),
            builder: (r) => PageBody(children: [
                  const Icon(Icons.science_outlined, size: 64),
                  heading(context, 'Sandbox checkout'),
                  Text(context.tr(
                      'Demo only. No real money is transferred. Do not enter card details.')),
                  Info('Reservation', r.s('apartmentTitle')),
                  Info('Total', money(r.i('amountMinor'))),
                  Info('Status', context.tr(r.displayStatus)),
                  if (AppConfig.emulator &&
                      AppConfig.useFunctions &&
                      r.displayStatus == 'awaiting_payment') ...[
                    BusyButton(
                        label: 'Simulate successful payment',
                        action: () => pay('success')),
                    BusyButton(
                        label: 'Simulate declined payment',
                        action: () => pay('decline'))
                  ] else
                    Text(context
                        .tr('A production payment provider is not configured')),
                ])));
  }
}
