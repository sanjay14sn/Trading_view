import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiService {
  String baseUrl;

  ApiService({String? baseUrl})
      : baseUrl = baseUrl ??
            dotenv.env['API_BASE_URL'] ??
            dotenv.env['SERVER_URL'] ??
            'http://13.205.189.169:3010';

  void updateBaseUrl(String url) {
    if (url.endsWith('/')) {
      baseUrl = url.substring(0, url.length - 1);
    } else {
      baseUrl = url;
    }
  }

  // Default headers to handle ngrok free tier warning pages and standard json requests
  Map<String, String> get _defaultHeaders => {
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'User-Agent': 'FlutterMobileApp',
      };

  // Health check
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'), headers: _defaultHeaders)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'OK';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Fetch Dashboard Stats
  Future<Map<String, dynamic>?> getDashboard() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/dashboard'), headers: _defaultHeaders)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('ApiService Error (getDashboard): $e');
    }
    return null;
  }

  // Fetch Trade List
  Future<List<dynamic>> getTrades({String? status}) async {
    try {
      final uri = status != null && status.isNotEmpty
          ? Uri.parse('$baseUrl/trades?status=$status')
          : Uri.parse('$baseUrl/trades');
      final response =
          await http.get(uri, headers: _defaultHeaders).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      print('ApiService Error (getTrades): $e');
    }
    return [];
  }

  // Fetch Signals List
  Future<List<dynamic>> getSignals() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/signals'), headers: _defaultHeaders)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      print('ApiService Error (getSignals): $e');
    }
    return [];
  }

  // Close Trade Manually
  Future<Map<String, dynamic>?> closeTrade(String tradeId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/trades/$tradeId/close'),
            headers: {
              ..._defaultHeaders,
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('ApiService Error (closeTrade): $e');
    }
    return null;
  }
}
