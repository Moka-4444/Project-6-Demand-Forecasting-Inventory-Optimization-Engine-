import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/alert_item.dart';

class ApiService {
  static String baseUrl = _defaultBaseUrl();
  static String? _authToken;

  static final Map<String, double> lastLatencies = {
    '/products': 12.0,
    '/products/{id}/simulate': 34.0,
    '/inventory/alerts': 18.0,
  };

  static String _defaultBaseUrl() {
    // Production: Live Azure App Service (UAE North)
    const prodUrl = 'https://stocksense-backend-eui.azurewebsites.net';
    if (kIsWeb) return prodUrl;
    if (!kIsWeb && Platform.isAndroid) return prodUrl;
    return prodUrl;
  }

  static void setBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<void> saveBaseUrl(String url) async {
    setBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', baseUrl);
  }

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    // NOTE: baseUrl is hardcoded to the live Azure endpoint.
    // We intentionally do NOT restore api_base_url from prefs here,
    // as old locally-saved URLs could silently override the live server.
  }

  static Future<void> saveSession(String token, {String? url, String? role}) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    if (role != null) await prefs.setString('user_role', role);
    if (url != null) {
      baseUrl = url;
      await prefs.setString('api_base_url', url);
    }
  }

  static Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  static Future<void> clearSession() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_role');
  }

  static Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (_authToken != null) headers['Authorization'] = 'Bearer $_authToken';
    return headers;
  }

  // Auth
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers(json: true),
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        await saveSession(
          data['token'] as String,
          role: data['role'] as String?,
        );
        return data;
      }
    } catch (e) {
      print('Login error: $e');
    }
    return null;
  }

  static Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}
    await clearSession();
  }

  static bool get isAuthenticated => _authToken != null;

  // Health check
  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('Health check error: $e');
    }
    return {'status': 'error', 'products_count': 0, 'models_loaded': false};
  }

  // List all products
  static Future<List<Product>> getProducts() async {
    final stopwatch = Stopwatch()..start();
    try {
      final res = await http.get(Uri.parse('$baseUrl/products')).timeout(const Duration(seconds: 8));
      stopwatch.stop();
      lastLatencies['/products'] = stopwatch.elapsedMilliseconds.toDouble();
      if (res.statusCode == 200) {
        final List dynamicList = jsonDecode(res.body);
        return dynamicList.map((item) => Product.fromJson(item)).toList();
      }
    } catch (e) {
      print('Get products error: $e');
    }
    return [];
  }

  // Validate SKU exists
  static Future<bool> validateSku(String itemId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/products/$itemId')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Get single product details
  static Future<Product?> getProduct(String itemId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/products/$itemId')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return Product.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      print('Get product error: $e');
    }
    return null;
  }

  // Get alerts list
  static Future<List<AlertItem>> getAlerts() async {
    final stopwatch = Stopwatch()..start();
    try {
      final res = await http.get(Uri.parse('$baseUrl/inventory/alerts')).timeout(const Duration(seconds: 8));
      stopwatch.stop();
      lastLatencies['/inventory/alerts'] = stopwatch.elapsedMilliseconds.toDouble();
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final List alertsList = data['alerts'] ?? [];
        return alertsList.map((item) => AlertItem.fromJson(item)).toList();
      }
    } catch (e) {
      print('Get alerts error: $e');
    }
    return [];
  }

  // Get inventory report
  static Future<List<Map<String, dynamic>>> getInventoryReport() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/inventory')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final List reportList = data['report'] ?? [];
        return reportList.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Get inventory report error: $e');
    }
    return [];
  }

  // Get weekly flow (actuals vs forecasts)
  static Future<Map<String, dynamic>> getWeeklyFlow() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/inventory/weekly-flow')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('Get weekly flow error: $e');
    }
    return {};
  }

  // Brand performance matrix
  static Future<Map<String, dynamic>?> getBrandMatrix() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/inventory/brand-matrix')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('Get brand matrix error: $e');
    }
    return null;
  }

  // Product weekly history for telemetry chart
  static Future<Map<String, dynamic>?> getProductWeeklyHistory(String itemId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/products/$itemId/weekly-history')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('Get weekly history error: $e');
    }
    return null;
  }

  // What-If Simulation
  static Future<Map<String, dynamic>?> simulateWhatIf(String itemId, double price, int promo) async {
    final stopwatch = Stopwatch()..start();
    try {
      final url = Uri.parse('$baseUrl/products/$itemId/simulate?new_price=$price&new_promo=$promo');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      stopwatch.stop();
      lastLatencies['/products/{id}/simulate'] = stopwatch.elapsedMilliseconds.toDouble();
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('Simulation error: $e');
    }
    return null;
  }

  // Adjust current stock
  static Future<bool> adjustStock(String itemId, double change) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/products/$itemId/adjust-stock'),
        headers: _headers(json: true),
        body: jsonEncode({'quantity_change': change}),
      ).timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (e) {
      print('Adjust stock error: $e');
    }
    return false;
  }

  // Submit procurement order
  static Future<Map<String, dynamic>?> submitProcurement({
    required String itemId,
    required double quantity,
    required String vendor,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/inventory/procurement'),
        headers: _headers(json: true),
        body: jsonEncode({
          'item_id': itemId,
          'quantity': quantity,
          'vendor': vendor,
        }),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('Procurement error: $e');
    }
    return null;
  }

  // Get vendor list
  static Future<List<String>> getVendors() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/inventory/vendors')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['vendors'] as List).map((v) => v.toString()).toList();
      }
    } catch (e) {
      print('Get vendors error: $e');
    }
    return [
      'Giza Logistics & Warehousing',
      'Delta FMCG Distributors',
      'Cairo Central Logistics Corp',
    ];
  }

  // Get drift metrics from MLOps
  static Future<Map<String, dynamic>?> getDriftCheck() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/mlops/drift-check')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('Drift check error: $e');
    }
    return null;
  }

  // Get stored model metrics
  static Future<Map<String, dynamic>?> getModelMetrics() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/mlops/model-metrics')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('Model metrics error: $e');
    }
    return null;
  }

  // Trigger retraining
  static Future<Map<String, dynamic>?> triggerRetraining() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/mlops/retrain')).timeout(const Duration(seconds: 120));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('Retraining error: $e');
    }
    return null;
  }

  // Get Expired/Near Expiry batches
  static Future<List<Map<String, dynamic>>> getExpiry() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/inventory/expiry')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List dataList = jsonDecode(res.body);
        return dataList.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          map['days_to_expiry'] = map['days_to_expiry'] ?? map['days_remaining'] ?? 0;
          return map;
        }).toList();
      }
    } catch (e) {
      print('Get expiry error: $e');
    }
    return [];
  }

  // Clear expired batch
  static Future<bool> clearExpiry(String itemId) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/inventory/expiry/$itemId/clear')).timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (e) {
      print('Clear expiry error: $e');
    }
    return false;
  }
}
