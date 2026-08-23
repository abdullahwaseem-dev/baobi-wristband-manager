import 'dart:convert';
import 'package:http/http.dart' as http;
import 'firebase_env.dart';
import 'settings_service.dart';

/// One Firebase Auth account per hospital, signed in via the Identity
/// Toolkit REST API (not the native Firebase Auth SDK — see the
/// project-level note on why: Firebase's own docs say Windows is not a
/// production-supported platform for the native plugins). The signed-in
/// account's UID is used directly as the hospital's Firestore partition key
/// (see FirebaseService / firestore.rules) — no custom claims needed.
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  String? _idToken;
  DateTime? _idTokenExpiry;
  Future<String?>? _refreshFuture;

  bool get isSignedIn => SettingsService.instance.firebaseRefreshToken.isNotEmpty;
  String get hospitalUid => SettingsService.instance.firebaseHospitalUid;
  String get signedInEmail => SettingsService.instance.firebaseEmail;

  Uri _uri(String base, String path) {
    final u = Uri.parse('$base$path');
    return u.replace(queryParameters: {...u.queryParameters, 'key': FirebaseEnv.apiKey});
  }

  // ─── Sign in / out ───────────────────────────────────────────────────────────

  Future<({bool ok, String? error})> signIn(String email, String password) async {
    if (!FirebaseEnv.isConfigured) {
      return (ok: false, error: 'Firebase is not configured for this build yet.');
    }
    if (email.trim().isEmpty || password.isEmpty) {
      return (ok: false, error: 'Enter both email and password.');
    }
    try {
      final uri = _uri(FirebaseEnv.identityToolkitBaseUrl, '/v1/accounts:signInWithPassword');
      final resp = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'email': email.trim(),
                'password': password,
                'returnSecureToken': true,
              }))
          .timeout(const Duration(seconds: 10));

      final body = json.decode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        return (ok: false, error: _authErrorMessage(body));
      }

      _idToken = body['idToken'] as String;
      _idTokenExpiry = DateTime.now().add(Duration(seconds: int.parse(body['expiresIn'] as String)));
      await SettingsService.instance.setFirebaseRefreshToken(body['refreshToken'] as String);
      await SettingsService.instance.setFirebaseHospitalUid(body['localId'] as String);
      await SettingsService.instance.setFirebaseEmail(email.trim());
      return (ok: true, error: null);
    } on Exception catch (e) {
      return (ok: false, error: _friendlyError(e));
    }
  }

  Future<void> signOut() async {
    _idToken = null;
    _idTokenExpiry = null;
    _refreshFuture = null;
    await SettingsService.instance.clearFirebaseRefreshToken();
  }

  // ─── Token access ────────────────────────────────────────────────────────────

  /// Returns a currently-valid idToken, refreshing it first if needed, or
  /// null if not signed in or the refresh fails terminally (which also signs
  /// the account out — see [_doRefresh]).
  Future<String?> validIdToken() async {
    if (!isSignedIn) return null;
    if (_idToken != null &&
        _idTokenExpiry != null &&
        DateTime.now().isBefore(_idTokenExpiry!.subtract(const Duration(minutes: 5)))) {
      return _idToken;
    }
    // Single in-flight refresh: concurrent Firestore calls that all discover
    // an expired token share one refresh instead of firing redundant
    // parallel requests.
    return _refreshFuture ??= _doRefresh().whenComplete(() => _refreshFuture = null);
  }

  Future<String?> _doRefresh() async {
    final refreshToken = SettingsService.instance.firebaseRefreshToken;
    if (refreshToken.isEmpty) return null;
    try {
      final uri = _uri(FirebaseEnv.secureTokenBaseUrl, '/v1/token');
      final resp = await http.post(
        uri,
        body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        // Terminal: revoked/disabled/invalid refresh token. Do NOT retry —
        // an allowed-to-spin refresh-failure loop is a real Blaze cost risk,
        // not just an annoyance. Sign out so every call site's isSignedIn
        // check goes false and stops trying.
        await signOut();
        return null;
      }

      final body = json.decode(resp.body) as Map<String, dynamic>;
      _idToken = body['id_token'] as String;
      _idTokenExpiry = DateTime.now().add(Duration(seconds: int.parse(body['expires_in'] as String)));
      // Google may rotate the refresh token on every grant — always persist
      // whatever came back, never assume the original is still valid.
      await SettingsService.instance.setFirebaseRefreshToken(body['refresh_token'] as String);
      return _idToken;
    } catch (_) {
      await signOut();
      return null;
    }
  }

  // ─── Error messages ──────────────────────────────────────────────────────────

  String _authErrorMessage(Map<String, dynamic> body) {
    final code = (body['error']?['message'] as String?) ?? '';
    switch (code) {
      case 'EMAIL_NOT_FOUND':
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect email or password.';
      case 'USER_DISABLED':
        return 'This account has been disabled — contact support.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Too many failed attempts — try again later.';
      default:
        return code.isEmpty ? 'Sign-in failed.' : 'Sign-in failed: $code';
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Failed host lookup')) {
      return 'Cannot reach the sign-in server — check your internet connection.';
    }
    if (msg.contains('TimeoutException')) {
      return 'Sign-in timed out — the server did not respond in time.';
    }
    return 'Sign-in error: $msg';
  }
}
