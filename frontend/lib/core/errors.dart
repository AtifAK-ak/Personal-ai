import 'dart:async';
import 'dart:io';

import 'api_client.dart';
import 'direct/key_store.dart';

/// Turns an exception into a short, useful sentence for the user.
String describeError(Object e) {
  if (e is SocketException) {
    return 'No internet connection or the service cannot be reached (${e.message}).';
  }
  if (e is TimeoutException) return 'The service took too long to answer.';
  if (e is HandshakeException) {
    return 'Secure connection failed. Check that the phone date and time are automatic.';
  }
  if (e is ProviderException) {
    return e.status == 0
        ? e.detail
        : 'The service returned error ${e.status}. ${e.detail}'.trim();
  }
  if (e is ApiException) return 'The backend returned error ${e.statusCode}.';
  if (e is FormatException) return 'The service sent an unexpected answer.';
  return 'Unexpected problem: $e';
}
