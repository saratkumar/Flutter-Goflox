import 'dart:convert';
import 'package:http/http.dart' as http;

class ConfigService {
  // After deploying your Apps Script, paste the /exec URL here.
  // Apps Script → Deploy → New deployment → Web app → Execute as Me → Anyone → Deploy
  static const _scriptUrl = 'https://script.google.com/macros/s/AKfycbw2X5iVPGyTJTsV-e3epeOjeIMztjo5s1ZcVWWWqiEQqhz6znHVv_-4wN0kykQl4Adg/exec';

  static Map<String, String>? _cache;
  static List<Map<String, String>>? _facilitiesCache;
  static List<Map<String, String>>? _typesCache;

  static Future<Map<String, String>> _fetch() async {
    if (_cache != null) return _cache!;
    final response = await http
        .get(Uri.parse(_scriptUrl))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Config fetch failed: ${response.statusCode}');
    }
    final raw = jsonDecode(response.body) as Map<String, dynamic>;
    _cache = raw.map((k, v) => MapEntry(k, v.toString()));
    return _cache!;
  }

  static Future<String> get(String key) async {
    final config = await _fetch();
    final value = config[key];
    if (value == null || value.isEmpty) {
      throw Exception('Config key "$key" not found in Google Sheet');
    }
    return value;
  }

  static void clearCache() {
    _cache = null;
    _facilitiesCache = null;
    _typesCache = null;
  }

  // ── Facilities ────────────────────────────────────────────────────────────

  static Future<List<Map<String, String>>> getFacilities() async {
    if (_facilitiesCache != null) return _facilitiesCache!;
    final uri = Uri.parse(_scriptUrl)
        .replace(queryParameters: {'action': 'get_facilities'});
    final response =
        await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    if (data is! List) return [];
    _facilitiesCache = data
        .map<Map<String, String>>((e) =>
            (e as Map).map((k, v) => MapEntry(k.toString(), v.toString())))
        .toList();
    return _facilitiesCache!;
  }

  static Future<void> addFacility(
      String name, String address, String description) async {
    await _sheetAction(
        'add_facility', {'name': name, 'address': address, 'description': description});
    _facilitiesCache = null;
  }

  static Future<void> updateFacility(
      String id, String name, String address, String description) async {
    await _sheetAction('update_facility',
        {'id': id, 'name': name, 'address': address, 'description': description});
    _facilitiesCache = null;
  }

  static Future<void> deleteFacility(String id) async {
    await _sheetAction('delete_facility', {'id': id});
    _facilitiesCache = null;
  }

  // ── Types ──────────────────────────────────────────────────────────────────

  /// Returns [{name, imageUrl}, …] from the Types sheet.
  static Future<List<Map<String, String>>> getTypes() async {
    if (_typesCache != null) return _typesCache!;
    final uri = Uri.parse(_scriptUrl)
        .replace(queryParameters: {'action': 'get_types'});
    final response =
        await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    if (data is! List) return [];
    _typesCache = data
        .map<Map<String, String>>((e) =>
            (e as Map).map((k, v) => MapEntry(k.toString(), v.toString())))
        .toList();
    return _typesCache!;
  }

  static Future<void> addType(String name, String imageUrl) async {
    await _sheetAction('add_type', {'name': name, 'imageUrl': imageUrl});
    _typesCache = null;
  }

  static Future<void> updateType(
      String originalName, String name, String imageUrl) async {
    await _sheetAction('update_type',
        {'originalName': originalName, 'name': name, 'imageUrl': imageUrl});
    _typesCache = null;
  }

  static Future<void> deleteType(String name) async {
    await _sheetAction('delete_type', {'name': name});
    _typesCache = null;
  }

  // ── Google Sheets class CRUD ──────────────────────────────────────────────

  // fields must include: day, mode, coach, location, groupSize, duration,
  // detailLocation, startTime, type, image, occurrence, specificDate
  static Future<void> addClass(Map<String, String> fields) =>
      _sheetAction('add_class', fields);

  static Future<void> updateClass(
          String originalKey, Map<String, String> fields) =>
      _sheetAction('update_class', {'originalKey': originalKey, ...fields});

  static Future<void> deleteClass(String key) =>
      _sheetAction('delete_class', {'key': key});

  static Future<void> _sheetAction(
      String action, Map<String, String> params) async {
    final uri = Uri.parse(_scriptUrl).replace(
        queryParameters: {'action': action, ...params});
    await http.get(uri).timeout(const Duration(seconds: 10));
  }

  // ── Transactions ──────────────────────────────────────────────────────────────

  /// Fetches all rows from the Transactions sheet.
  /// Returns [{invoiceNumber, txId, clientName, clientEmail, planName, credits, amount, currency, date}, …]
  static Future<List<Map<String, String>>> getTransactions() async {
    final uri = Uri.parse(_scriptUrl)
        .replace(queryParameters: {'action': 'get_transactions'});
    final response =
        await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
          'Response is not JSON. Body: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
    }
    // Accept plain array OR {data: [...]} / {records: [...]} wrapper
    if (data is Map) {
      data = data['data'] ?? data['records'] ?? data['rows'];
    }
    if (data is! List) {
      throw Exception(
          'Unexpected response shape from Apps Script: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }
    return data
        .map<Map<String, String>>((e) =>
            (e as Map).map((k, v) => MapEntry(k.toString(), v.toString())))
        .toList();
  }

  /// Records a transaction row to the Transactions sheet via the same Apps Script.
  static Future<void> recordTransaction({
    required String invoiceNumber,
    required String paymentIntentId,
    required String clientName,
    required String clientEmail,
    required String planName,
    required int credits,
    required double amount,
    required String currency,
    required String date,
  }) async {
    final uri = Uri.parse(_scriptUrl).replace(queryParameters: {
      'action': 'record_transaction',
      'invoiceNumber': invoiceNumber,
      'txId': paymentIntentId,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'planName': planName,
      'credits': credits.toString(),
      'amount': amount.toStringAsFixed(2),
      'currency': currency,
      'date': date,
    });
    await http.get(uri).timeout(const Duration(seconds: 10));
  }
}
