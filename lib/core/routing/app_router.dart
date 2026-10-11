import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/session.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/apartments/apartment_screens.dart';
import '../../features/reservations/reservation_screens.dart';
import '../../features/owner/owner_screens.dart';
import '../../features/profile/profile_screens.dart';
import '../../features/chat/chat_screens.dart';
import '../../features/reviews/review_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../l10n.dart';
import '../widgets/brand_mark.dart';

String? roleRedirect(
    {required bool loading,
    required bool authenticated,
    required String? role,
    required String path}) {
  if (loading) return path == '/loading' ? null : '/loading';
  final authPage = ['/login', '/register', '/reset'].contains(path);
  if (!authenticated) return authPage ? null : '/login';
  if (role == null) return path == '/complete' ? null : '/complete';
  if (authPage || path == '/loading' || path == '/complete') return '/';
  if (path.startsWith('/owner') && role != 'owner') return '/';
  if ((path.endsWith('/request') || path.endsWith('/payment')) &&
      role != 'student') {
    return '/';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final s = ref.read(sessionProvider);
  final router = GoRouter(
      refreshListenable: s,
      redirect: (context, state) => roleRedirect(
          loading: s.loading,
          authenticated: s.user != null,
          role: s.profile?.s('role'),
          path: state.uri.path),
      routes: [
        GoRoute(path: '/loading', builder: (_, __) => const LoadingScreen()),
        for (final mode in ['login', 'register', 'reset'])
          GoRoute(path: '/$mode', builder: (_, __) => AuthScreen(mode: mode)),
        GoRoute(
            path: '/complete',
            builder: (_, __) => const AuthScreen(mode: 'complete')),
        ShellRoute(builder: (_, __, child) => AppShell(child: child), routes: [
          GoRoute(
              path: '/',
              builder: (_, __) => s.profile?.isOwner == true
                  ? const OwnerDashboard()
                  : const BrowseScreen()),
          GoRoute(
              path: '/reservations',
              builder: (_, __) => const ReservationsScreen()),
          GoRoute(path: '/chats', builder: (_, __) => const ChatListScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ]),
        GoRoute(
            path: '/profile/edit', builder: (_, __) => const ProfileEditor()),
        GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationsScreen()),
        GoRoute(
            path: '/apartments/:id',
            builder: (_, s) =>
                ApartmentDetailScreen(id: s.pathParameters['id']!)),
        GoRoute(
            path: '/apartments/:id/rooms',
            builder: (_, s) =>
                RoomsScreen(apartmentId: s.pathParameters['id']!)),
        GoRoute(
            path: '/apartments/:id/reviews',
            builder: (_, s) => ReviewsScreen(
                apartmentId: s.pathParameters['id']!,
                reservationId: s.uri.queryParameters['reservation'])),
        GoRoute(
            path: '/rooms/:id',
            builder: (_, s) => RoomDetailScreen(id: s.pathParameters['id']!)),
        GoRoute(
            path: '/rooms/:id/request',
            builder: (_, s) => ReservationRequestScreen(
                roomId: s.pathParameters['id']!,
                parentId: s.uri.queryParameters['parent'])),
        GoRoute(
            path: '/reservations/:id',
            builder: (_, s) =>
                ReservationDetailScreen(id: s.pathParameters['id']!)),
        GoRoute(
            path: '/reservations/:id/payment',
            builder: (_, s) => PaymentScreen(id: s.pathParameters['id']!)),
        GoRoute(
            path: '/chats/:id',
            builder: (_, s) => ConversationScreen(id: s.pathParameters['id']!)),
        GoRoute(
            path: '/owner/apartments/new',
            builder: (_, __) => const ApartmentEditor()),
        GoRoute(
            path: '/owner/apartments/:id/edit',
            builder: (_, s) => ApartmentEditor(id: s.pathParameters['id']!)),
        GoRoute(
            path: '/owner/apartments/:id/rooms/new',
            builder: (_, s) =>
                RoomEditor(apartmentId: s.pathParameters['id']!)),
        GoRoute(
            path: '/owner/apartments/:id/rooms/:room/edit',
            builder: (_, s) => RoomEditor(
                apartmentId: s.pathParameters['id']!,
                id: s.pathParameters['room']!)),
        GoRoute(
            path: '/owner/requests',
            builder: (context, _) => Scaffold(
                appBar: AppBar(title: Text(context.tr('Requests'))),
                body: const ReservationsScreen(requestsOnly: true))),
        GoRoute(
            path: '/owner/calendar',
            builder: (_, __) => const CalendarScreen()),
        GoRoute(
            path: '/owner/payments',
            builder: (_, __) => const PaymentsScreen()),
      ],
      errorBuilder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(context.tr('Page not found'))),
          body: Center(
              child: FilledButton(
                  onPressed: () => context.go('/'),
                  child: Text(context.tr('Home'))))));
  ref.onDispose(router.dispose);
  return router;
});

class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      body: Center(
          child: ref.watch(sessionProvider).error == null
              ? const CircularProgressIndicator()
              : Text(ref.watch(sessionProvider).error!)));
}

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path,
        paths = ['/', '/reservations', '/chats', '/profile'];
    return Scaffold(
        appBar: AppBar(
            leading: const Padding(
                padding: EdgeInsets.all(8), child: BrandMark(size: 40)),
            title: Text(context.tr('Campus Home')),
            actions: [
              IconButton(
                  tooltip: context.tr('Notifications'),
                  onPressed: () => context.push('/notifications'),
                  icon: const Icon(Icons.notifications_outlined))
            ]),
        body: child,
        bottomNavigationBar: NavigationBar(
            selectedIndex: !paths.contains(path) ? 0 : paths.indexOf(path),
            onDestinationSelected: (i) => context.go(paths[i]),
            destinations: [
              NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  label: context.tr('Home')),
              NavigationDestination(
                  icon: const Icon(Icons.bookmark_border),
                  label: context.tr('Reservations')),
              NavigationDestination(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: context.tr('Messages')),
              NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  label: context.tr('Profile'))
            ]));
  }
}
