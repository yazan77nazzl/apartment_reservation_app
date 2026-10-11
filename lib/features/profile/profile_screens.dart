import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/common.dart';
import '../../core/l10n.dart';
import '../../core/utils/validation.dart';
import '../../services/housing_repository.dart';
import '../../services/session.dart';
import '../../services/image_storage.dart';
import '../../core/config/app_config.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider), p = session.profile!;
    return PageBody(children: [
      Center(
          child: CircleAvatar(
              radius: 48,
              backgroundImage: p.s('photoUrl').isEmpty
                  ? null
                  : housingImage(p.s('photoUrl')),
              child: p.s('photoUrl').isEmpty
                  ? const Icon(Icons.person, size: 48)
                  : null)),
      heading(context, p.name),
      Chip(label: Text(context.tr(p.s('role')))),
      Info('Email', session.user!.email ?? p.s('email'),
          icon: Icons.email_outlined),
      Info('Phone', p.s('phone'), icon: Icons.phone_outlined),
      Info('Address', p.s('address'), icon: Icons.location_on_outlined),
      Info('Gender', context.tr(p.s('gender'))),
      FilledButton(
          onPressed: () => context.push('/profile/edit'),
          child: Text(context.tr('Edit profile'))),
      OutlinedButton(
          onPressed: () => context.push('/notifications'),
          child: Text(context.tr('Notifications'))),
      if (p.isOwner)
        OutlinedButton(
            onPressed: () => context.push('/owner/calendar'),
            child: Text(context.tr('Calendar'))),
      choice(context, 'Language', ref.watch(localeProvider), ['en', 'ar'],
          (v) => ref.read(localeProvider.notifier).state = v),
      BusyButton(label: 'Log out', icon: Icons.logout, action: session.logout),
    ]);
  }
}

class ProfileEditor extends ConsumerStatefulWidget {
  const ProfileEditor({super.key});
  @override
  ConsumerState<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<ProfileEditor> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final key in [
      'firstName',
      'lastName',
      'phone',
      'address',
      'email',
      'currentPassword',
      'newPassword'
    ])
      key: TextEditingController()
  };
  String photo = '', gender = 'unspecified';
  @override
  void initState() {
    super.initState();
    final s = ref.read(sessionProvider), p = s.profile!;
    for (final key in ['firstName', 'lastName', 'phone', 'address']) {
      fields[key]!.text = p.s(key);
    }
    fields['email']!.text = s.user!.email ?? '';
    photo = p.s('photoUrl');
    gender = p.s('gender');
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(context.tr('Edit profile'))),
      body: Form(
          key: form,
          child: PageBody(children: [
            if (photo.isNotEmpty)
              Center(
                  child: CircleAvatar(
                      radius: 48, backgroundImage: housingImage(photo))),
            BusyButton(
                label: AppConfig.demoImages
                    ? 'Choose demo image'
                    : 'Upload profile image',
                icon: Icons.add_a_photo_outlined,
                action: () async {
                  final url = await ref.read(repositoryProvider).pickImage(
                      'profiles/${ref.read(sessionProvider).user!.uid}',
                      context: context);
                  if (url != null && mounted) setState(() => photo = url);
                }),
            field(context, 'First name', fields['firstName']!),
            field(context, 'Last name', fields['lastName']!),
            field(context, 'Phone', fields['phone']!,
                keyboard: TextInputType.phone, validate: Validation.phone),
            field(context, 'Address', fields['address']!),
            choice(context, 'Gender', gender, ['unspecified', 'female', 'male'],
                (v) => setState(() => gender = v)),
            field(context, 'Email', fields['email']!,
                keyboard: TextInputType.emailAddress,
                validate: Validation.email),
            Text(context.tr(
                'Email changes require verification. Use your verified email on your next login.')),
            field(context, 'Current password', fields['currentPassword']!,
                secret: true, validate: (_) => null),
            field(context, 'New password (optional)', fields['newPassword']!,
                secret: true,
                validate: (v) =>
                    v == null || v.isEmpty ? null : Validation.password(v)),
            BusyButton(
                label: 'Save profile',
                action: () async {
                  if (!form.currentState!.validate()) return;
                  final user = FirebaseAuth.instance.currentUser!,
                      repo = ref.read(repositoryProvider),
                      email = fields['email']!.text.trim(),
                      password = fields['newPassword']!.text;
                  if (email != user.email || password.isNotEmpty) {
                    if (fields['currentPassword']!.text.isEmpty) {
                      throw StateError(
                          'Current password is required for email or password changes');
                    }
                    await user.reauthenticateWithCredential(
                        EmailAuthProvider.credential(
                            email: user.email!,
                            password: fields['currentPassword']!.text));
                    if (password.isNotEmpty) {
                      await user.updatePassword(password);
                    }
                    if (email != user.email) {
                      await user.verifyBeforeUpdateEmail(email);
                      if (context.mounted) {
                        notice(context,
                            'Check your new email to verify the change');
                      }
                    }
                  }
                  await repo.call('updateProfile', {
                    for (final key in [
                      'firstName',
                      'lastName',
                      'phone',
                      'address'
                    ])
                      key: fields[key]!.text,
                    'gender': gender,
                    'photoUrl': photo
                  });
                  if (context.mounted) {
                    notice(context, 'Profile saved');
                    context.go('/profile');
                  }
                }),
          ])));
}
