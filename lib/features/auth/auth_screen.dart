import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/common.dart';
import '../../core/utils/validation.dart';
import '../../core/l10n.dart';
import '../../services/housing_repository.dart';
import '../../services/session.dart';
import '../../core/widgets/brand_mark.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final String mode;
  const AuthScreen({super.key, required this.mode});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final key in [
      'firstName',
      'lastName',
      'email',
      'phone',
      'address',
      'password',
      'confirm'
    ])
      key: TextEditingController()
  };
  String role = 'student', gender = 'unspecified';
  bool get register => widget.mode == 'register' || widget.mode == 'complete';
  bool get complete => widget.mode == 'complete';
  bool get reset => widget.mode == 'reset';
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final auth = FirebaseAuth.instance;
    final repository = ref.read(repositoryProvider);
    if (reset) {
      await auth.sendPasswordResetEmail(email: fields['email']!.text.trim());
      if (mounted) {
        notice(context, 'Password reset email sent');
        context.go('/login');
      }
      return;
    }
    if (register) {
      if (!complete) {
        await auth.createUserWithEmailAndPassword(
            email: fields['email']!.text.trim(),
            password: fields['password']!.text);
      }
      await repository.call('registerProfile', {
        for (final key in ['firstName', 'lastName', 'phone', 'address'])
          key: fields[key]!.text.trim(),
        'role': role,
        'gender': gender
      });
      if (mounted) context.go('/');
    } else {
      await auth.signInWithEmailAndPassword(
          email: fields['email']!.text.trim(),
          password: fields['password']!.text);
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = reset
        ? 'Reset password'
        : complete
            ? 'Complete your profile'
            : register
                ? 'Create account'
                : 'Welcome back';
    return Scaffold(
        appBar: AppBar(title: Text(context.tr('Campus Home')), actions: [
          TextButton(
              onPressed: () => ref.read(localeProvider.notifier).state =
                  ref.read(localeProvider) == 'en' ? 'ar' : 'en',
              child: const Text('العربية / EN'))
        ]),
        body: PageBody(children: [
          const SizedBox(height: 24),
          const BrandMark(size: 112),
          heading(context, title),
          Text(context.tr('Find a place to study, rest and belong')),
          Form(
              key: form,
              child: Column(children: [
                if (register) ...[
                  choice(context, 'Account type', role, ['student', 'owner'],
                      (v) => setState(() => role = v)),
                  const SizedBox(height: 14),
                  field(context, 'First name', fields['firstName']!),
                  const SizedBox(height: 14),
                  field(context, 'Last name', fields['lastName']!),
                  const SizedBox(height: 14),
                  choice(
                      context,
                      'Gender',
                      gender,
                      ['unspecified', 'female', 'male'],
                      (v) => setState(() => gender = v)),
                  const SizedBox(height: 14),
                  field(context, 'Phone', fields['phone']!,
                      keyboard: TextInputType.phone,
                      validate: Validation.phone),
                  const SizedBox(height: 14),
                  field(context, 'Address', fields['address']!),
                  const SizedBox(height: 14),
                ],
                if (!complete) ...[
                  field(context, 'Email', fields['email']!,
                      keyboard: TextInputType.emailAddress,
                      validate: Validation.email),
                  const SizedBox(height: 14)
                ],
                if (!reset && !complete) ...[
                  field(context, 'Password', fields['password']!,
                      secret: true,
                      validate:
                          register ? Validation.password : Validation.required),
                  const SizedBox(height: 14)
                ],
                if (register && !complete) ...[
                  field(context, 'Confirm password', fields['confirm']!,
                      secret: true,
                      validate: (v) => v == fields['password']!.text
                          ? null
                          : 'Passwords do not match'),
                  const SizedBox(height: 14)
                ],
                BusyButton(
                    label: reset
                        ? 'Send reset email'
                        : register
                            ? 'Register'
                            : 'Log in',
                    action: submit),
              ])),
          if (!complete)
            TextButton(
                onPressed: () =>
                    context.go(register || reset ? '/login' : '/register'),
                child: Text(context.tr(
                    register || reset ? 'Back to login' : 'Create account'))),
          if (!register && !reset)
            TextButton(
                onPressed: () => context.go('/reset'),
                child: Text(context.tr('Forgot password?'))),
          if (complete)
            BusyButton(
                label: 'Log out',
                action: () => ref.read(sessionProvider).logout()),
        ]));
  }
}
