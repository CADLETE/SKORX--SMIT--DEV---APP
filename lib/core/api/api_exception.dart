/// An API failure the UI can act on. [code] is the server's error code
/// (backend/src/common/constants/error-codes.ts), or one of the client-side
/// codes below; switch on it, never on [message].
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.status});

  /// No response reached us: offline, DNS, timeout.
  static const network = 'NETWORK';

  /// A response arrived but was not the SkorX envelope.
  static const badResponse = 'BAD_RESPONSE';

  final String code;

  /// Written for players; safe to show as is.
  final String message;
  final int? status;

  bool get isNetwork => code == network;

  @override
  String toString() => 'ApiException($code, $status): $message';
}
