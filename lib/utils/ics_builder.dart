/// Builds a minimal RFC 5545 VCALENDAR string for a single event, suitable
/// as an email attachment (Nodemailer/the Trigger Email extension pass
/// `message.attachments` straight through, so this just needs to be a
/// valid .ics body).
class IcsBuilder {
  static String build({
    required String summary,
    required DateTime start,
    int durationMinutes = 60,
    String location = '',
    String description = '',
  }) {
    final end = start.add(Duration(minutes: durationMinutes));
    final uid = '${start.millisecondsSinceEpoch}-${summary.hashCode}@psas.app';
    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//PSAS//Booking//EN',
      'METHOD:REQUEST',
      'BEGIN:VEVENT',
      'UID:$uid',
      'DTSTAMP:${_fmt(DateTime.now())}',
      'DTSTART:${_fmt(start)}',
      'DTEND:${_fmt(end)}',
      'SUMMARY:${_escape(summary)}',
      if (location.isNotEmpty) 'LOCATION:${_escape(location)}',
      if (description.isNotEmpty) 'DESCRIPTION:${_escape(description)}',
      'STATUS:CONFIRMED',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
  }

  static String _fmt(DateTime d) {
    final u = d.toUtc();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${p2(u.month)}${p2(u.day)}T${p2(u.hour)}${p2(u.minute)}${p2(u.second)}Z';
  }

  static String _escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;')
      .replaceAll('\n', '\\n');
}
