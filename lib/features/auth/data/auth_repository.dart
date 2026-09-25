import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/token_store.dart';
import 'current_user.dart';

/// What happened after a code was sent: when a new one can be requested.
class OtpSent {
  const OtpSent({required this.resendAfter});

  final Duration resendAfter;
}

/// Profile fields a player fills in after their first sign-in.
class ProfileUpdate {
  const ProfileUpdate({required this.name, this.city, this.gender, this.dateOfBirth});

  final String name;
  final String? city;

  /// male, female, other, prefer_not_to_say.
  final String? gender;
  final DateTime? dateOfBirth;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (city != null) 'city': city,
        if (gender != null) 'gender': gender,
        if (dateOfBirth != null)
          'dateOfBirth':
              '${dateOfBirth!.year.toString().padLeft(4, '0')}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}',
      };
}

/// The signed-in user as last seen by the server, restored from the cache
/// when the app starts offline.
class RestoredUser {
  const RestoredUser(this.user, {required this.fromCache});

  final CurrentUser user;
  final bool fromCache;
}

/// Phone sign-in, session and profile calls.
abstract class AuthRepository {
  Future<OtpSent> sendOtp(String mobile);

  /// Signs in and stores the session. Returns the signed-in user.
  Future<CurrentUser> verifyOtp(String mobile, String code);

  /// The signed-in user, or null when there is no stored session.
  Future<RestoredUser?> restore();
  Future<CurrentUser> updateProfile(ProfileUpdate update);
  Future<void> signOut();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._tokens, this._prefs);

  final ApiClient _api;
  final TokenStore _tokens;
  final SharedPreferencesAsync _prefs;
  static const _cacheKey = 'skorx.currentUser';

  @override
  Future<OtpSent> sendOtp(String mobile) async {
    final data = await _api.postPublic<Map<String, dynamic>>('/auth/otp/send', body: {'mobile': mobile});
    return OtpSent(resendAfter: Duration(seconds: data['resendAfterSeconds'] as int? ?? 30));
  }

  @override
  Future<CurrentUser> verifyOtp(String mobile, String code) async {
    final data = await _api.postPublic<Map<String, dynamic>>(
      '/auth/otp/verify',
      body: {'mobile': mobile, 'otp': code, 'client': 'mobile'},
    );
    await _tokens.write(SessionTokens.fromJson(data['session'] as Map<String, dynamic>));
    return _remember(CurrentUser.fromJson(data['user'] as Map<String, dynamic>));
  }

  @override
  Future<RestoredUser?> restore() async {
    if (await _tokens.read() == null) return null;
    try {
      final user = CurrentUser.fromJson(await _api.get<Map<String, dynamic>>('/auth/me'));
      return RestoredUser(await _remember(user), fromCache: false);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      final cached = await _prefs.getString(_cacheKey);
      if (cached == null) rethrow;
      return RestoredUser(CurrentUser.fromJson(jsonDecode(cached) as Map<String, dynamic>), fromCache: true);
    }
  }

  @override
  Future<CurrentUser> updateProfile(ProfileUpdate update) async {
    await _api.patch<Map<String, dynamic>>('/me/profile', body: update.toJson());
    return _remember(CurrentUser.fromJson(await _api.get<Map<String, dynamic>>('/auth/me')));
  }

  @override
  Future<void> signOut() async {
    final tokens = await _tokens.read();
    await _tokens.clear();
    await _prefs.remove(_cacheKey);
    if (tokens == null) return;
    try {
      // Revoke on the server too; if offline, the token simply expires.
      await _api.postPublic<Object?>('/auth/logout', body: {'refreshToken': tokens.refreshToken});
    } on ApiException {
      // Nothing to do: the local session is already gone.
    }
  }

  Future<CurrentUser> _remember(CurrentUser user) async {
    await _prefs.setString(_cacheKey, jsonEncode(user.toJson()));
    return user;
  }
}
