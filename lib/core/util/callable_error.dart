import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// A short message for a failed Cloud Function call. Our functions return
/// plain-language messages for expected failures (sold out, window closed),
/// so those are shown as-is; anything else gets a generic message.
String callableErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    if (error.code == 'internal' || error.code == 'unknown') {
      return 'Something went wrong. Please try again.';
    }
    final message = error.message;
    if (message != null && message.isNotEmpty) return message;
  }
  if (kDebugMode) return error.toString();
  return 'Something went wrong. Please try again.';
}
