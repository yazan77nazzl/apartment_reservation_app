import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/common.dart';
import '../../core/l10n.dart';
import '../../services/housing_repository.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  final String apartmentId;
  final String? reservationId;
  const ReviewsScreen(
      {super.key, required this.apartmentId, this.reservationId});
  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  final form = GlobalKey<FormState>(), comment = TextEditingController();
  int rating = 5;
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    return Scaffold(
        appBar: AppBar(title: Text(context.tr('Reviews and ratings'))),
        body: RecordsView(
            stream: repo.records('reviews',
                field: 'apartmentId',
                value: widget.apartmentId,
                order: 'updatedAt'),
            builder: (reviews) => PageBody(children: [
                  if (widget.reservationId != null)
                    Form(
                        key: form,
                        child: Column(children: [
                          heading(context, 'Share your experience'),
                          Wrap(
                              children: List.generate(
                                  5,
                                  (i) => IconButton(
                                      tooltip:
                                          '${i + 1} ${context.tr('stars')}',
                                      onPressed: () =>
                                          setState(() => rating = i + 1),
                                      icon: Icon(
                                          i < rating
                                              ? Icons.star
                                              : Icons.star_outline,
                                          color: Colors.amber)))),
                          field(context, 'Your review', comment, lines: 3),
                          const SizedBox(height: 12),
                          BusyButton(
                              label: 'Submit review',
                              action: () async {
                                if (!form.currentState!.validate()) return;
                                await repo.call('saveReview', {
                                  'apartmentId': widget.apartmentId,
                                  'reservationId': widget.reservationId,
                                  'rating': rating,
                                  'comment': comment.text
                                });
                                if (context.mounted) {
                                  comment.clear();
                                  notice(context, 'Review saved');
                                }
                              })
                        ])),
                  if (reviews.isEmpty)
                    EmptyState(text: context.tr('No reviews yet')),
                  ...reviews.map((r) => Card(
                      child: ListTile(
                          title: Text(
                              '${r.s('studentName')} Â· ${'â˜…' * r.i('rating')}'),
                          subtitle: Text(r.s('comment'))))),
                ])));
  }
}
