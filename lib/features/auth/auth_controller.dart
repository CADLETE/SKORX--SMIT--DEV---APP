import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/token_store.dart';
import 'data/auth_repository.dart';
import 'data/current_user.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final preferencesProvider = Provider<SharedPreferencesAsync>((ref) => SharedPreferencesAsync());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(tokens: ref.watch(tokenStoreProvider));
  // A session the server will no longer refresh ends here, from any screen.
  client.onSessionEnded = () => ref.read(authControllerProvider.notifier).sessionEnded();
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
    ref.watch(preferencesProvider),
  ),
);

sealed class AuthState {
  const AuthState();
}

/// Checking for a stored session at launch.
class AuthRestoring extends AuthState {
  const AuthRestoring();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn(this.user, {this.fromCache = false});

  final CurrentUser user;

  /// The app started offline and [user] is the last copy the server sent.
  final bool fromCache;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthRestoring();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    try {
      final restored = await _repo.restore();
      state = restored == null ? const SignedOut() : SignedIn(restored.user, fromCache: restored.fromCache);
    } catch (_) {
      // Revoked or unreadable session: start again from sign-in.
      state = const SignedOut();
    }
  }

  Future<OtpSent> sendOtp(String mobile) => _repo.sendOtp(mobile);

  Future<void> verifyOtp(String mobile, String code) async {
    state = SignedIn(await _repo.verifyOtp(mobile, code));
  }

  Future<void> completeProfile(ProfileUpdate update) async {
    state = SignedIn(await _repo.updateProfile(update));
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const SignedOut();
  }

  void sessionEnded() => state = const SignedOut();
}

/// The signed-in user, for screens that only exist while signed in.
final currentUserProvider = Provider<CurrentUser?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is SignedIn ? auth.user : null;
});
