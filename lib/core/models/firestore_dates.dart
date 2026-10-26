import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads a date field written either by the app (ISO-8601 string) or by Cloud
/// Functions (Firestore [Timestamp], e.g. `serverTimestamp()`). Returns null
/// for a missing or unparseable value instead of throwing.
DateTime? readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  if (value is DateTime) return value;
  return null;
}
