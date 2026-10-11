import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/common.dart';
import '../../core/l10n.dart';
import '../../models/record.dart';
import '../../services/housing_repository.dart';
import '../../services/session.dart';
import '../apartments/apartment_screens.dart';
import '../reservations/reservation_screens.dart';

class OwnerDashboard extends ConsumerWidget {
  const OwnerDashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider), repo = ref.read(repositoryProvider);
    return RecordsView(
        stream:
            repo.records('apartments', field: 'ownerId', value: s.user!.uid),
        builder: (apartments) => PageBody(children: [
              heading(context,
                  '${context.tr('Welcome')}, ${s.profile!.s('firstName')}'),
              Text(context.tr('Help students find their next home')),
              if (apartments.isEmpty)
                EmptyState(
                    text: context.tr(
                        'Ready to start? Add your apartment, then its rooms.')),
              FilledButton.icon(
                  onPressed: () => context.push('/owner/apartments/new'),
                  icon: const Icon(Icons.add),
                  label: Text(context
                      .tr(apartments.isEmpty ? 'Start now' : 'Add apartment'))),
              Wrap(spacing: 12, runSpacing: 12, children: [
                OutlinedButton.icon(
                    onPressed: () => context.push('/owner/requests'),
                    icon: const Icon(Icons.inbox_outlined),
                    label: Text(context.tr('Reservation requests'))),
                OutlinedButton.icon(
                    onPressed: () => context.push('/owner/calendar'),
                    icon: const Icon(Icons.calendar_month),
                    label: Text(context.tr('Calendar'))),
                OutlinedButton.icon(
                    onPressed: () => context.push('/owner/payments'),
                    icon: const Icon(Icons.receipt_long),
                    label: Text(context.tr('Payment records')))
              ]),
              ...apartments.map((a) => ApartmentCard(apartment: a)),
            ]));
  }
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime selected = DateTime.now();
  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider),
        uid = ref.watch(sessionProvider).user!.uid;
    return Scaffold(
        appBar: AppBar(title: Text(context.tr('Reservation calendar'))),
        body: RecordsView(
            stream: repo.records('reservations', field: 'ownerId', value: uid),
            builder: (all) {
              final date = isoDay(selected),
                  reservations = all
                      .where((r) =>
                          (['confirmed', 'completed'].contains(r.s('status')) ||
                              r.displayStatus == 'awaiting_payment') &&
                          r.s('start').compareTo(date) <= 0 &&
                          r.s('end').compareTo(date) > 0)
                      .toList();
              return PageBody(children: [
                Card(
                    child: CalendarDatePicker(
                        initialDate: selected,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        onDateChanged: (v) => setState(() => selected = v))),
                heading(context, date),
                if (reservations.isEmpty)
                  EmptyState(text: context.tr('No stays on this date')),
                ...reservations.map((r) => Column(children: [
                      Text('${r.s('studentName')} · ${r.s('studentPhone')}'),
                      ReservationCard(reservation: r)
                    ]))
              ]);
            }));
  }
}

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: Text(context.tr('Payment records'))),
      body: RecordsView(
          stream: ref.read(repositoryProvider).records('payments',
              field: 'ownerId', value: ref.watch(sessionProvider).user!.uid),
          builder: (payments) => PageBody(children: [
                if (payments.isEmpty)
                  EmptyState(text: context.tr('No payments yet')),
                ...payments.map((p) => Card(
                    child: ListTile(
                        title: Text(money(p.i('amountMinor'))),
                        subtitle: Text(
                            '${context.tr(p.s('status'))} · ${p.s('provider')}\n${p.time('updatedAt')?.toLocal() ?? ''}'),
                        trailing: p.b('demo')
                            ? Chip(label: Text(context.tr('Demo')))
                            : null,
                        onTap: () => context
                            .push('/reservations/${p.s('reservationId')}'))))
              ])));
}
