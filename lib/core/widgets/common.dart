import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../models/record.dart';
import '../utils/validation.dart';
import '../l10n.dart';

String errorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' =>
        'Email or password is incorrect',
      'email-already-in-use' => 'This email is already registered',
      'weak-password' => 'Use at least 8 characters',
      'too-many-requests' => 'Too many attempts. Try again later',
      'network-request-failed' => 'Check your connection',
      _ => error.message ?? error.code,
    };
  }
  if (error is FirebaseFunctionsException) return error.message ?? error.code;
  return error.toString().replaceFirst('Bad state: ', '');
}

void notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.tr(message))));
Future<T?> perform<T>(BuildContext context, Future<T> Function() work,
    {String? success}) async {
  try {
    final result = await work();
    if (context.mounted && success != null) notice(context, success);
    return result;
  } catch (e) {
    if (context.mounted) notice(context, errorMessage(e));
    return null;
  }
}

class PageBody extends StatelessWidget {
  final List<Widget> children;
  const PageBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
              padding: const EdgeInsets.all(20),
              children: children
                  .map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 16), child: w))
                  .toList())));
}

class BusyButton extends StatefulWidget {
  final String label;
  final Future<void> Function() action;
  final IconData? icon;
  const BusyButton(
      {super.key, required this.label, required this.action, this.icon});
  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
      onPressed: busy
          ? null
          : () async {
              setState(() => busy = true);
              await perform(context, widget.action);
              if (mounted) setState(() => busy = false);
            },
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(widget.icon ?? Icons.arrow_forward),
      label: Text(context.tr(widget.label)));
}

class RecordsView extends StatelessWidget {
  final Stream<List<Record>> stream;
  final Widget Function(List<Record>) builder;
  const RecordsView({super.key, required this.stream, required this.builder});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Record>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(errorMessage(s.error!))));
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return builder(s.data!);
      });
}

class RecordView extends StatelessWidget {
  final Stream<Record?> stream;
  final Widget Function(Record) builder;
  const RecordView({super.key, required this.stream, required this.builder});
  @override
  Widget build(BuildContext context) => StreamBuilder<Record?>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) return Center(child: Text(errorMessage(s.error!)));
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.data == null) {
          return EmptyState(text: context.tr('Record not found'));
        }
        return builder(s.data!);
      });
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.home_work_outlined,
            size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center)
      ]));
}

class Gallery extends StatelessWidget {
  final List<String> images;
  const Gallery({super.key, required this.images});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
          height: 220,
          child: images.isEmpty
              ? Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: const Center(
                      child: Icon(Icons.apartment_rounded, size: 80)))
              : PageView(
                  children: images
                      .map((url) => url.startsWith('assets/')
                          ? Image.asset(url, fit: BoxFit.cover)
                          : Image.network(url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_outlined)),
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                      ? child
                                      : const Center(
                                          child: CircularProgressIndicator())))
                      .toList())));
}

class Info extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const Info(this.label, this.value,
      {super.key, this.icon = Icons.info_outline});
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(context.tr(label)),
      subtitle: Text(value));
}

Widget heading(BuildContext context, String text) => Text(context.tr(text),
    style: Theme.of(context)
        .textTheme
        .headlineSmall
        ?.copyWith(fontWeight: FontWeight.bold));
Widget field(
        BuildContext context, String label, TextEditingController controller,
        {bool secret = false,
        int lines = 1,
        TextInputType? keyboard,
        String? Function(String?)? validate}) =>
    TextFormField(
        controller: controller,
        obscureText: secret,
        maxLines: lines,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: context.tr(label)),
        validator: (v) {
          final result = (validate ?? Validation.required)(v);
          return result == null ? null : context.tr(result);
        });
Widget choice(BuildContext context, String label, String value,
        List<String> choices, ValueChanged<String> onChange) =>
    DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: context.tr(label)),
        items: choices
            .map((x) => DropdownMenuItem(value: x, child: Text(context.tr(x))))
            .toList(),
        onChanged: (x) {
          if (x != null) onChange(x);
        });
