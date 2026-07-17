import 'package:flutter/material.dart';

/// Parses times like "3:00 PM" or "15:00" as stored on ClassModel.startTime
/// / booking docs. Returns null if unparseable.
TimeOfDay? parseTimeString(String text) {
  try {
    final cleaned = text.toUpperCase().replaceAll(' ', '');
    final isPM = cleaned.contains('PM');
    final isAM = cleaned.contains('AM');
    final digits = cleaned.replaceAll('AM', '').replaceAll('PM', '');
    final parts = digits.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
    if (isPM && hour != 12) hour += 12;
    if (isAM && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  } catch (_) {
    return null;
  }
}

/// Combines a calendar [date] with a time string into a full DateTime.
/// Returns null if [timeStr] doesn't parse.
DateTime? combineDateAndTime(DateTime date, String timeStr) {
  final t = parseTimeString(timeStr);
  if (t == null) return null;
  return DateTime(date.year, date.month, date.day, t.hour, t.minute);
}
