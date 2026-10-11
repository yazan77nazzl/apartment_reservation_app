import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/common.dart';
import '../../core/l10n.dart';
import '../../core/utils/validation.dart';
import '../../core/config/app_config.dart';
import '../../models/record.dart';
import '../../services/housing_repository.dart';
import '../../services/session.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});
  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  String search = '', location = '', sort = 'rating', gender = 'any';
  double maxPrice = 5000, minRating = 0;
  @override
  Widget build(BuildContext context) {
    final repository = ref.read(repositoryProvider),
        p = ref.watch(sessionProvider).profile!;
    return RecordsView(
        stream: repository.records('apartments'),
        builder: (all) {
          final apartments = all
              .where((a) =>
                  (a.s('gender') == 'any' || a.s('gender') == p.s('gender')) &&
                  (gender == 'any' || a.s('gender') == gender) &&
                  '${a.s('title')} ${a.s('location')}'
                      .toLowerCase()
                      .contains(search.toLowerCase()) &&
                  a
                      .s('location')
                      .toLowerCase()
                      .contains(location.toLowerCase()) &&
                  a.i('minPriceMinor') <= maxPrice * 100 &&
                  a.n('averageRating') >= minRating)
              .toList();
          apartments.sort((a, b) => sort == 'price'
              ? a.i('minPriceMinor').compareTo(b.i('minPriceMinor'))
              : sort == 'location'
                  ? a.s('location').compareTo(b.s('location'))
                  : b.n('averageRating').compareTo(a.n('averageRating')));
          return PageBody(children: [
            heading(context, 'Find your university home'),
            Text(context.tr('Housing matched to your profile')),
            TextField(
                decoration: InputDecoration(
                    labelText: context.tr('Search name or location'),
                    prefixIcon: const Icon(Icons.search)),
                onChanged: (v) => setState(() => search = v)),
            ExpansionTile(
                title: Text(context.tr('Filters and sorting')),
                children: [
                  TextField(
                      decoration:
                          InputDecoration(labelText: context.tr('Location')),
                      onChanged: (v) => setState(() => location = v)),
                  const SizedBox(height: 12),
                  choice(
                      context,
                      'Sort by',
                      sort,
                      ['rating', 'price', 'location'],
                      (v) => setState(() => sort = v)),
                  const SizedBox(height: 12),
                  choice(
                      context,
                      'Gender eligibility',
                      gender,
                      ['any', 'female', 'male'],
                      (v) => setState(() => gender = v)),
                  Text(
                      '${context.tr('Maximum monthly price')}: ${money(maxPrice * 100)}'),
                  Slider(
                      value: maxPrice,
                      min: 100,
                      max: 5000,
                      divisions: 49,
                      label: money(maxPrice * 100),
                      onChanged: (v) => setState(() => maxPrice = v)),
                  Text(
                      '${context.tr('Minimum rating')}: ${minRating.toStringAsFixed(1)}'),
                  Slider(
                      value: minRating,
                      min: 0,
                      max: 5,
                      divisions: 10,
                      onChanged: (v) => setState(() => minRating = v)),
                ]),
            if (apartments.isEmpty)
              EmptyState(text: context.tr('No matching apartments')),
            ...apartments.map((a) => ApartmentCard(apartment: a)),
          ]);
        });
  }
}

class ApartmentCard extends StatelessWidget {
  final Record apartment;
  const ApartmentCard({super.key, required this.apartment});
  @override
  Widget build(BuildContext context) => Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: () => context.push('/apartments/${apartment.id}'),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Gallery(images: apartment.list('images')),
                    const SizedBox(height: 12),
                    Text(apartment.s('title'),
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(apartment.s('location')),
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, children: [
                      Text(
                          '★ ${apartment.n('averageRating').toStringAsFixed(1)} (${apartment.i('reviewCount')})'),
                      Text(apartment.i('minPriceMinor') > 0
                          ? '${context.tr('From')} ${money(apartment.i('minPriceMinor'))} / ${context.tr('month')}'
                          : context.tr('No available rooms')),
                      Text(context.tr(apartment.s('gender')))
                    ]),
                    if (apartment.b('fictional'))
                      Text(context.tr('Fictional sample'),
                          style: const TextStyle(fontStyle: FontStyle.italic))
                  ]))));
}

class ApartmentDetailScreen extends ConsumerWidget {
  final String id;
  const ApartmentDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider),
        owner = ref.watch(sessionProvider).profile!.isOwner;
    return Scaffold(
        appBar: AppBar(title: Text(context.tr('Apartment details'))),
        body: RecordView(
            stream: repo.document('apartments', id),
            builder: (a) => PageBody(children: [
                  Gallery(images: a.list('images')),
                  heading(context, a.s('title')),
                  Text(a.s('description')),
                  Info('Location', a.s('location'),
                      icon: Icons.location_on_outlined),
                  Info('Housing type', context.tr(a.s('housingType'))),
                  Info('Gender eligibility', context.tr(a.s('gender'))),
                  Info(
                      'Nearest university gate',
                      a.s('nearestGate').isEmpty
                          ? context.tr('Not provided')
                          : a.s('nearestGate')),
                  Info('Owner contact',
                      '${a.s('ownerName')} · ${a.s('contactPhone')}'),
                  Info('Rating',
                      '★ ${a.n('averageRating').toStringAsFixed(1)} (${a.i('reviewCount')})'),
                  FilledButton.icon(
                      onPressed: () => context.push('/apartments/$id/rooms'),
                      icon: const Icon(Icons.bed_outlined),
                      label: Text(context
                          .tr(owner ? 'Manage rooms' : 'Available rooms'))),
                  OutlinedButton(
                      onPressed: () => context.push('/apartments/$id/reviews'),
                      child: Text(context.tr('Reviews'))),
                  if (owner &&
                      a.s('ownerId') == ref.read(sessionProvider).user!.uid)
                    FilledButton(
                        onPressed: () =>
                            context.push('/owner/apartments/$id/edit'),
                        child: Text(context.tr('Edit apartment'))),
                  if (!owner)
                    BusyButton(
                        label: 'Chat with owner',
                        icon: Icons.chat_outlined,
                        action: () async {
                          final result =
                              await repo.call('openChat', {'apartmentId': id});
                          if (context.mounted) {
                            context.push('/chats/${result['id']}');
                          }
                        }),
                ])));
  }
}

class ApartmentEditor extends ConsumerStatefulWidget {
  final String? id;
  const ApartmentEditor({super.key, this.id});
  @override
  ConsumerState<ApartmentEditor> createState() => _ApartmentEditorState();
}

class _ApartmentEditorState extends ConsumerState<ApartmentEditor> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      description = TextEditingController(),
      location = TextEditingController(),
      gate = TextEditingController();
  String gender = 'any', type = 'residence';
  String? id;
  List<String> images = [];
  bool loaded = false;
  @override
  void dispose() {
    for (final c in [title, description, location, gate]) {
      c.dispose();
    }
    super.dispose();
  }

  void populate(Record a) {
    if (loaded) return;
    loaded = true;
    id = a.id;
    title.text = a.s('title');
    description.text = a.s('description');
    location.text = a.s('location');
    gate.text = a.s('nearestGate');
    gender = a.s('gender');
    type = a.s('housingType');
    images = a.list('images');
  }

  Future<void> save({bool navigate = true}) async {
    if (!form.currentState!.validate()) return;
    final result = await ref.read(repositoryProvider).call('saveApartment', {
      'id': id,
      'title': title.text,
      'description': description.text,
      'location': location.text,
      'nearestGate': gate.text,
      'gender': gender,
      'housingType': type,
      'images': images
    });
    id = result['id'] as String;
    if (mounted && navigate) context.go('/apartments/$id');
  }

  Widget content() => Form(
      key: form,
      child: PageBody(children: [
        heading(context, id == null ? 'Add your apartment' : 'Edit apartment'),
        field(context, 'Apartment name', title),
        field(context, 'Description', description, lines: 4),
        field(context, 'Location', location),
        field(context, 'Nearest university gate', gate, validate: (_) => null),
        choice(context, 'Gender eligibility', gender, ['any', 'female', 'male'],
            (v) => setState(() => gender = v)),
        choice(
            context,
            'Housing type',
            type,
            ['apartment', 'studio', 'residence'],
            (v) => setState(() => type = v)),
        Gallery(images: images),
        if (images.isNotEmpty)
          ...images.asMap().entries.map((entry) => ListTile(
              title: Text('${context.tr('Image')} ${entry.key + 1}'),
              trailing: IconButton(
                  tooltip: context.tr('Remove image'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      setState(() => images.removeAt(entry.key))))),
        BusyButton(
            label: AppConfig.demoImages
                ? 'Choose demo image'
                : 'Upload apartment image',
            icon: Icons.add_photo_alternate_outlined,
            action: () async {
              if (images.length >= 10) {
                throw StateError('Up to ten images allowed');
              }
              if (id == null) {
                await save(navigate: false);
                if (id == null) return;
              }
              if (!mounted) return;
              final url = await ref
                  .read(repositoryProvider)
                  .pickImage('apartments/$id', context: context);
              if (url != null && mounted) {
                setState(() => images.add(url));
                await save(navigate: false);
              }
            }),
        BusyButton(label: 'Save apartment', action: () => save()),
      ]));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(context.tr('Apartment information'))),
      body: widget.id == null
          ? content()
          : RecordView(
              stream: ref
                  .read(repositoryProvider)
                  .document('apartments', widget.id!),
              builder: (a) {
                populate(a);
                return content();
              }));
}

class RoomsScreen extends ConsumerWidget {
  final String apartmentId;
  const RoomsScreen({super.key, required this.apartmentId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider),
        uid = ref.read(sessionProvider).user!.uid;
    return Scaffold(
        appBar: AppBar(title: Text(context.tr('Rooms'))),
        body: RecordView(
            stream: repo.document('apartments', apartmentId),
            builder: (a) => RecordsView(
                stream: repo.records('rooms',
                    field: 'apartmentId', value: apartmentId),
                builder: (all) {
                  final own = a.s('ownerId') == uid,
                      rooms = all.where((r) => own || r.b('available')).toList()
                        ..sort(
                            (a, b) => a.s('number').compareTo(b.s('number')));
                  return PageBody(children: [
                    if (own)
                      FilledButton.icon(
                          onPressed: () => context
                              .push('/owner/apartments/$apartmentId/rooms/new'),
                          icon: const Icon(Icons.add),
                          label: Text(context.tr('Add room'))),
                    if (rooms.isEmpty)
                      EmptyState(text: context.tr('No available rooms')),
                    ...rooms.map((r) => Card(
                        child: ListTile(
                            leading: const Icon(Icons.bed_outlined),
                            title: Text(
                                '${context.tr('Room')} ${r.s('number')} · ${money(r.i('priceMinor'))} / ${context.tr('month')}'),
                            subtitle: Text(
                                '${context.tr('Floor')} ${r.i('floor')} · ${r.i('beds')} ${context.tr('beds')} · ${context.tr(r.b('available') ? 'Open for requests' : 'Unavailable')}'),
                            onTap: () => context.push('/rooms/${r.id}'),
                            trailing: own
                                ? IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: context.tr('Edit room'),
                                    onPressed: () => context.push(
                                        '/owner/apartments/$apartmentId/rooms/${r.id}/edit'))
                                : const Icon(Icons.chevron_right))))
                  ]);
                })));
  }
}

class RoomDetailScreen extends ConsumerWidget {
  final String id;
  const RoomDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider),
        student = !ref.read(sessionProvider).profile!.isOwner;
    return Scaffold(
        appBar: AppBar(title: Text(context.tr('Room details'))),
        body: RecordView(
            stream: repo.document('rooms', id),
            builder: (room) => RecordView(
                stream: repo.document('apartments', room.s('apartmentId')),
                builder: (a) => PageBody(children: [
                      Gallery(images: a.list('images')),
                      heading(
                          context, '${context.tr('Room')} ${room.s('number')}'),
                      Text(room.s('description')),
                      Info('Apartment', a.s('title')),
                      Info('Floor', room.s('floor')),
                      Info('Beds', room.s('beds')),
                      Info('Monthly price', money(room.i('priceMinor'))),
                      Info(
                          'Availability',
                          context.tr(room.b('available')
                              ? 'Open for requests'
                              : 'Unavailable')),
                      if (student && room.b('available'))
                        FilledButton(
                            onPressed: () => context.push('/rooms/$id/request'),
                            child: Text(context.tr('Request reservation'))),
                      Text(context.tr(
                          'Availability for your dates is checked when requesting and approving')),
                      OutlinedButton(
                          onPressed: () => context.push('/apartments/${a.id}'),
                          child: Text(context.tr('Apartment details'))),
                    ]))));
  }
}

class RoomEditor extends ConsumerStatefulWidget {
  final String apartmentId;
  final String? id;
  const RoomEditor({super.key, required this.apartmentId, this.id});
  @override
  ConsumerState<RoomEditor> createState() => _RoomEditorState();
}

class _RoomEditorState extends ConsumerState<RoomEditor> {
  final form = GlobalKey<FormState>();
  final number = TextEditingController(),
      floor = TextEditingController(text: '1'),
      beds = TextEditingController(text: '1'),
      price = TextEditingController(),
      description = TextEditingController();
  bool available = true, loaded = false;
  @override
  void dispose() {
    for (final c in [number, floor, beds, price, description]) {
      c.dispose();
    }
    super.dispose();
  }

  void populate(Record r) {
    if (loaded) return;
    loaded = true;
    number.text = r.s('number');
    floor.text = r.s('floor');
    beds.text = r.s('beds');
    price.text = (r.i('priceMinor') / 100).toString();
    description.text = r.s('description');
    available = r.b('available');
  }

  Widget content() => Form(
      key: form,
      child: PageBody(children: [
        field(context, 'Room number', number),
        field(context, 'Floor', floor,
            keyboard: const TextInputType.numberWithOptions(signed: true),
            validate: (v) =>
                int.tryParse(v ?? '') == null ? 'Enter a whole number' : null),
        field(context, 'Beds', beds,
            keyboard: TextInputType.number,
            validate: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 1
                ? 'Enter a positive whole number'
                : null),
        field(context, 'Monthly price (ILS)', price,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            validate: Validation.positive),
        field(context, 'Description', description, lines: 3),
        SwitchListTile(
            title: Text(context.tr('Open for reservation requests')),
            value: available,
            onChanged: (v) => setState(() => available = v)),
        BusyButton(
            label: 'Save room',
            action: () async {
              if (!form.currentState!.validate()) return;
              await ref.read(repositoryProvider).call('saveRoom', {
                'id': widget.id,
                'apartmentId': widget.apartmentId,
                'number': number.text,
                'floor': int.parse(floor.text),
                'beds': int.parse(beds.text),
                'priceMinor': (double.parse(price.text) * 100).round(),
                'description': description.text,
                'available': available
              });
              if (mounted) {
                context.go('/apartments/${widget.apartmentId}/rooms');
              }
            })
      ]));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title:
              Text(context.tr(widget.id == null ? 'Add room' : 'Edit room'))),
      body: widget.id == null
          ? content()
          : RecordView(
              stream:
                  ref.read(repositoryProvider).document('rooms', widget.id!),
              builder: (r) {
                populate(r);
                return content();
              }));
}
