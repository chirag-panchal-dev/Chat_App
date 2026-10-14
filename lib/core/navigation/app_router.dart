import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account_deletion/presentation/delete_account_screen.dart';
import '../../features/attachments/presentation/screens/attachment_preview_screen.dart';
import '../../features/attachments/presentation/screens/image_viewer_screen.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/auth/presentation/viewmodels/auth_providers.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/contact_info_screen.dart';
import '../../features/conversations/presentation/screens/chats_screen.dart';
import '../../features/onboarding/presentation/intro_screen.dart';
import '../../features/privacy_settings/presentation/screens/legal_screen.dart';
import '../../features/privacy_settings/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_setup_screen.dart';
import '../../features/profile/presentation/viewmodels/profile_providers.dart';
import '../../features/safety/presentation/screens/blocked_users_screen.dart';
import '../../features/user_search/presentation/screens/new_chat_screen.dart';
import '../l10n/l10n_ext.dart';
import '../widgets/hushlo_mark.dart';
import '../widgets/state_views.dart';

/// Bridges Riverpod session state to go_router's `refreshListenable`.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(currentProfileProvider, (_, __) => notifyListeners());
  }
}

const _publicPaths = {'/intro', '/auth'};

final routerProvider = Provider<GoRouter>((ref) {
  final session = _SessionListenable(ref);

  String? redirect(BuildContext context, GoRouterState state) {
    final path = state.matchedLocation;
    final auth = ref.read(authStateProvider);
    if (auth.isLoading) return path == '/splash' ? null : '/splash';
    final user = auth.value;

    if (user == null) {
      return _publicPaths.contains(path) ? null : '/intro';
    }
    if (user.needsEmailVerification) {
      return path == '/verify' ? null : '/verify';
    }
    final profile = ref.read(currentProfileProvider);
    if (profile.isLoading) return path == '/splash' ? null : '/splash';
    if (profile.hasError) {
      return path == '/session-error' ? null : '/session-error';
    }
    if (profile.value == null) {
      return path == '/setup' ? null : '/setup';
    }
    // Fully set up: keep users out of the pre-auth/setup screens.
    if (_publicPaths.contains(path) ||
        path == '/splash' ||
        path == '/verify' ||
        path == '/session-error' ||
        path == '/setup') {
      return '/chats';
    }
    return null;
  }

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: session,
    redirect: redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/intro', builder: (_, __) => const IntroScreen()),
      GoRoute(
        path: '/session-error',
        builder: (_, __) => const _SessionErrorScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder:
            (_, s) => AuthScreen(
              initialMode:
                  s.uri.queryParameters['mode'] == 'login'
                      ? AuthMode.login
                      : AuthMode.signUp,
            ),
      ),
      GoRoute(path: '/verify', builder: (_, __) => const VerifyEmailScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const ProfileSetupScreen()),
      GoRoute(path: '/chats', builder: (_, __) => const ChatsScreen()),
      GoRoute(path: '/new-chat', builder: (_, __) => const NewChatScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'info',
            builder:
                (_, s) =>
                    ContactInfoScreen(conversationId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'attachment',
            builder: (_, s) {
              final extra = s.extra as Map<String, Object?>;
              return AttachmentPreviewScreen(
                conversationId: s.pathParameters['id']!,
                path: extra['path']! as String,
                replyToId: extra['replyTo'] as String?,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/image',
        builder: (_, s) {
          final extra = s.extra as Map<String, Object?>;
          return ImageViewerScreen(
            path: extra['path']! as String,
            thumbPath: extra['thumb'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (_, __) => const EditProfileScreen(),
          ),
          GoRoute(
            path: 'blocked',
            builder: (_, __) => const BlockedUsersScreen(),
          ),
          GoRoute(
            path: 'delete-account',
            builder: (_, __) => const DeleteAccountScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/legal/:doc',
        builder: (_, s) => LegalScreen(doc: s.pathParameters['doc']!),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    session.dispose();
  });
  return router;
});

/// In-app loading state that visually continues the native splash
/// (same colour and mark), with no decorative animation.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFF101820),
    body: Center(child: HushloMark(size: 120)),
  );
}

/// Shown when the profile can't be loaded (offline, permission, etc.) so the
/// user can retry or sign out instead of seeing an endless spinner.
class _SessionErrorScreen extends ConsumerWidget {
  const _SessionErrorScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(currentProfileProvider).error ?? 'unknown';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ErrorState(
                error: error,
                onRetry: () => ref.invalidate(currentProfileProvider),
              ),
            ),
            TextButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: Text(context.l10n.signOut),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
