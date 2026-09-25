import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skorx/core/api/api_client.dart';
import 'package:skorx/core/api/api_exception.dart';
import 'package:skorx/core/auth/token_store.dart';

typedef Handler = ({int status, Object body}) Function(RequestOptions request);

/// Answers requests from [handler] and records what was asked.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  Handler handler;
  final List<RequestOptions> requests = [];
  bool offline = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (offline) throw DioException.connectionError(requestOptions: options, reason: 'offline');
    await Future<void>.delayed(Duration.zero);
    final reply = handler(options);
    return ResponseBody.fromString(jsonEncode(reply.body), reply.status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

({int status, Object body}) ok(Object data) => (status: 200, body: {'success': true, 'data': data});
({int status, Object body}) fail(int status, String code) =>
    (status: status, body: {'success': false, 'error': {'code': code, 'message': 'Server says $code'}});

void main() {
  late MemoryTokenStore tokens;

  setUp(() => tokens = MemoryTokenStore(const SessionTokens(accessToken: 'old-access', refreshToken: 'old-refresh')));

  ApiClient client(FakeAdapter adapter, {void Function()? onEnded}) =>
      ApiClient(tokens: tokens, baseUrl: 'https://api.test', adapter: adapter, onSessionEnded: onEnded);

  test('unwraps the envelope and sends the access token', () async {
    final adapter = FakeAdapter((_) => ok({'id': 'u1'}));
    final data = await client(adapter).get<Map<String, dynamic>>('/auth/me');
    expect(data['id'], 'u1');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer old-access');
  });

  test('turns server errors into ApiException with the server code and message', () async {
    final adapter = FakeAdapter((_) => fail(409, 'SCORE_CONFLICT'));
    await expectLater(
      client(adapter).post<Object?>('/matches/m1/score', body: {'side': 'a'}),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'SCORE_CONFLICT')
          .having((e) => e.status, 'status', 409)
          .having((e) => e.message, 'message', 'Server says SCORE_CONFLICT')),
    );
  });

  test('reports no connection as a network error', () async {
    final adapter = FakeAdapter((_) => ok({}))..offline = true;
    await expectLater(
      client(adapter).get<Object?>('/auth/me'),
      throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', isTrue)),
    );
  });

  test('refreshes an expired token once and retries the request', () async {
    final adapter = FakeAdapter((request) {
      if (request.path == '/auth/refresh') {
        expect(jsonDecode(jsonEncode(request.data))['refreshToken'], 'old-refresh');
        return ok({
          'refreshed': true,
          'session': {'accessToken': 'new-access', 'refreshToken': 'new-refresh'},
        });
      }
      return request.headers['Authorization'] == 'Bearer new-access' ? ok({'id': 'u1'}) : fail(401, 'AUTH_TOKEN_EXPIRED');
    });

    final data = await client(adapter).get<Map<String, dynamic>>('/auth/me');
    expect(data['id'], 'u1');
    expect((await tokens.read())!.refreshToken, 'new-refresh');
    expect(adapter.requests.where((r) => r.path == '/auth/refresh'), hasLength(1));
  });

  test('parallel requests with an expired token share one refresh', () async {
    final adapter = FakeAdapter((request) {
      if (request.path == '/auth/refresh') {
        return ok({'session': {'accessToken': 'new-access', 'refreshToken': 'new-refresh'}});
      }
      return request.headers['Authorization'] == 'Bearer new-access' ? ok({'ok': true}) : fail(401, 'AUTH_TOKEN_EXPIRED');
    });
    final api = client(adapter);

    await Future.wait([for (var i = 0; i < 4; i++) api.get<Object?>('/matches/$i')]);
    // The server rotates refresh tokens; a second refresh would be rejected.
    expect(adapter.requests.where((r) => r.path == '/auth/refresh'), hasLength(1));
  });

  test('ends the session when the refresh token is refused', () async {
    var ended = false;
    final adapter = FakeAdapter(
      (request) => request.path == '/auth/refresh' ? fail(401, 'AUTH_UNAUTHORIZED') : fail(401, 'AUTH_TOKEN_EXPIRED'),
    );
    await expectLater(client(adapter, onEnded: () => ended = true).get<Object?>('/auth/me'), throwsA(isA<ApiException>()));
    expect(ended, isTrue);
    expect(await tokens.read(), isNull);
  });

  test('keeps the session when the refresh fails only because the phone is offline', () async {
    var ended = false;
    late FakeAdapter adapter;
    adapter = FakeAdapter((request) {
      // The API answers the first call, then the connection drops.
      adapter.offline = true;
      return fail(401, 'AUTH_TOKEN_EXPIRED');
    });
    await expectLater(client(adapter, onEnded: () => ended = true).get<Object?>('/auth/me'), throwsA(isA<ApiException>()));
    expect(ended, isFalse);
    expect(await tokens.read(), isNotNull);
  });

  test('sign-in calls never trigger a refresh', () async {
    final adapter = FakeAdapter((_) => fail(401, 'OTP_INVALID'));
    await expectLater(
      client(adapter).postPublic<Object?>('/auth/otp/verify', body: {'mobile': '9586545430', 'otp': '000000'}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'OTP_INVALID')),
    );
    expect(adapter.requests, hasLength(1));
  });
}
