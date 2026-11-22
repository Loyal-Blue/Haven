import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'domain.dart';
import 'store.dart';
import 'theme_settings.dart';

class AppearanceCloud extends ChangeNotifier {
  AppearanceCloud(this.store);

  final HavenStore store;
  static const project = String.fromEnvironment('HAVEN_FIREBASE_PROJECT');
  static const apiKey = String.fromEnvironment('HAVEN_FIREBASE_WEB_API_KEY');
  static const clientId = String.fromEnvironment('HAVEN_GOOGLE_WEB_CLIENT_ID');
  static const iosClientId = String.fromEnvironment(
    'HAVEN_GOOGLE_IOS_CLIENT_ID',
  );

  String? email;
  String? status;
  bool busy = false;
  bool _disposed = false;
  bool _initialized = false;
  Timer? _syncTimer;
  String? _userId, _token, _refreshToken;
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);
  int _observed = 0;

  bool get supported => Platform.isAndroid || Platform.isIOS;
  bool get configured =>
      project.isNotEmpty &&
      apiKey.isNotEmpty &&
      clientId.isNotEmpty &&
      (!Platform.isIOS || iosClientId.isNotEmpty);
  bool get connected => _userId != null;

  Future<void> start() async {
    if (!supported || !configured || _disposed) return;
    if (!await _optIn.exists()) return;
    await _connect(interactive: false);
  }

  File get _optIn => File(
    '${store.file.parent.path}${Platform.pathSeparator}google-theme-sync',
  );

  Future<void> signIn() => _connect(interactive: true);

  Future<void> _connect({required bool interactive}) async {
    if (busy || !supported || !configured || connected) return;
    busy = true;
    _notify();
    try {
      final google = GoogleSignIn.instance;
      if (!_initialized) {
        await google.initialize(
          serverClientId: clientId,
          clientId: Platform.isIOS ? iosClientId : null,
        );
        _initialized = true;
      }
      final account = interactive
          ? await google.authenticate()
          : await google.attemptLightweightAuthentication();
      if (account == null || _disposed) return;
      final googleToken = account.authentication.idToken;
      if (googleToken == null) {
        throw const FormatException('Google did not return an ID token.');
      }
      final response = await _request(
        Uri.https(
          'identitytoolkit.googleapis.com',
          '/v1/accounts:signInWithIdp',
          {'key': apiKey},
        ),
        method: 'POST',
        body: {
          'postBody': Uri(
            queryParameters: {
              'providerId': 'google.com',
              'id_token': googleToken,
            },
          ).query,
          'requestUri': 'http://localhost',
          'returnSecureToken': true,
        },
      );
      final data = response.data;
      if (response.code != 200 ||
          data['localId'] is! String ||
          data['idToken'] is! String) {
        throw const FormatException(
          'Firebase could not verify this Google account.',
        );
      }
      if (_disposed) return;
      _userId = data['localId'];
      _setTokens(data['idToken'], data['refreshToken'], data['expiresIn']);
      email = account.email;
      await _optIn.writeAsString('enabled', flush: true);
      if (_disposed) return;
      _observed = store.state.appearanceUpdatedAt;
      store.addListener(_localChange);
      _syncTimer = Timer.periodic(
        const Duration(minutes: 2),
        (_) => unawaited(sync()),
      );
      status = null;
    } on FormatException catch (failure) {
      status = failure.message;
    } on GoogleSignInException catch (failure) {
      if (failure.code != GoogleSignInExceptionCode.canceled) {
        status =
            'Google sign-in could not start. Check the OAuth configuration.';
      }
    } on Object {
      status = 'Could not connect to Google. Check your connection.';
    } finally {
      busy = false;
      _notify();
    }
    if (connected) await sync();
  }

  void _setTokens(String token, String? refresh, dynamic expires) {
    _token = token;
    _refreshToken = refresh;
    _expires = DateTime.now().add(
      Duration(seconds: (int.tryParse('$expires') ?? 3600) - 60),
    );
  }

  Future<void> _refresh() async {
    if (DateTime.now().isBefore(_expires)) return;
    final response = await _request(
      Uri.https('securetoken.googleapis.com', '/v1/token', {'key': apiKey}),
      method: 'POST',
      form: {
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken ?? '',
      },
    );
    if (response.code != 200) {
      throw const FormatException(
        'Sign out and sign back in to refresh your session.',
      );
    }
    _setTokens(
      response.data['id_token'],
      response.data['refresh_token'],
      response.data['expires_in'],
    );
  }

  void _localChange() {
    final latest = store.state.appearanceUpdatedAt;
    if (!connected || latest == _observed) return;
    _observed = latest;
    unawaited(sync());
  }

  Future<void> sync() async {
    if (busy || !connected || _disposed) return;
    final userId = _userId;
    busy = true;
    _notify();
    try {
      await _refresh();
      if (_disposed || _userId != userId) return;
      final uri = Uri.https(
        'firestore.googleapis.com',
        '/v1/projects/$project/databases/(default)/documents/havenAppearances/$userId',
      );
      for (var attempt = 0; attempt < 3; attempt++) {
        final remote = await _request(uri, token: _token);
        if (_disposed || _userId != userId) return;
        if (remote.code != 200 && remote.code != 404) {
          throw const FormatException(
            'Theme sync could not read Firestore. Check the project and rules.',
          );
        }
        final fields = remote.data['fields'] as Json?;
        final updated =
            int.tryParse('${fields?['modified']?['integerValue'] ?? 0}') ?? 0;
        final local = store.state;
        if (remote.code == 200 && updated >= local.appearanceUpdatedAt) {
          final saved = fields?['settings']?['stringValue'] as String;
          if (updated == local.appearanceUpdatedAt && saved == _encode(local)) {
            break;
          }
          final theme = jsonDecode(saved) as Json;
          final mode = ThemePreference.values
              .where((mode) => mode.name == theme['mode'])
              .firstOrNull;
          await store.commit((current) {
            if (_disposed ||
                _userId != userId ||
                current.appearanceUpdatedAt > updated) {
              return current;
            }
            _observed = updated;
            return current.copyWith(
              appearance: ThemeSettings.fromJson(theme['appearance'] as Json?),
              theme: mode,
              appearanceUpdatedAt: updated,
            );
          });
          if (store.state.appearanceUpdatedAt <= updated) break;
          continue;
        }
        final write = await _request(
          uri.replace(
            queryParameters: remote.code == 404
                ? {'currentDocument.exists': 'false'}
                : {
                    'currentDocument.updateTime':
                        remote.data['updateTime'] as String,
                  },
          ),
          method: 'PATCH',
          token: _token,
          body: {
            'fields': {
              'modified': {'integerValue': '${local.appearanceUpdatedAt}'},
              'settings': {
                'stringValue': jsonEncode({
                  'mode': local.theme.name,
                  'appearance': local.appearance.toJson(),
                }),
              },
            },
          },
        );
        if (write.code == 200 &&
            local.appearanceUpdatedAt == store.state.appearanceUpdatedAt) {
          break;
        }
        if (write.code != 200 &&
            write.code != 409 &&
            write.code != 412 &&
            write.data['error']?['status'] != 'FAILED_PRECONDITION') {
          throw const FormatException(
            'Theme sync could not write to Firestore. Check the project and rules.',
          );
        }
        if (attempt == 2) {
          throw const FormatException(
            'Theme changed on another device. Sync again.',
          );
        }
      }
      status = 'Appearance synced';
    } on FormatException catch (failure) {
      status = failure.message;
    } on Object {
      status = 'Appearance sync failed. Check your connection.';
    } finally {
      busy = false;
      _notify();
    }
  }

  String _encode(HavenState state) => jsonEncode({
    'mode': state.theme.name,
    'appearance': state.appearance.toJson(),
  });

  Future<void> signOut() async {
    if (busy || !connected) return;
    busy = true;
    _notify();
    try {
      if (await _optIn.exists()) await _optIn.delete();
      _clear();
      await GoogleSignIn.instance.signOut();
      status = null;
    } on Object {
      status = 'Could not finish signing out. Try again.';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _clear() {
    store.removeListener(_localChange);
    _syncTimer?.cancel();
    _userId = _token = _refreshToken = email = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clear();
    super.dispose();
  }
}

Future<({int code, Json data})> _request(
  Uri uri, {
  String method = 'GET',
  String? token,
  Json? body,
  Map<String, String>? form,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  const timeout = Duration(seconds: 15);
  try {
    final request = await client.openUrl(method, uri).timeout(timeout);
    request.followRedirects = false;
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    if (form != null) {
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );
      request.write(Uri(queryParameters: form).query);
    }
    final response = await request.close().timeout(timeout);
    final bytes = <int>[];
    await for (final chunk in response.timeout(timeout)) {
      if (bytes.length + chunk.length > 65536) {
        throw const FormatException('Cloud response too large.');
      }
      bytes.addAll(chunk);
    }
    final decoded = bytes.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(bytes)) as Json;
    return (code: response.statusCode, data: decoded);
  } finally {
    client.close(force: true);
  }
}
