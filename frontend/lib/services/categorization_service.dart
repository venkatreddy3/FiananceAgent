import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'storage_service.dart';

class CategorizationService {
  static final CategorizationService _instance = CategorizationService._internal();
  factory CategorizationService() => _instance;
  CategorizationService._internal() {
    _loadLearnedRules();
  }

  // In-memory resolved merchant cache (prevents duplicate lookups)
  final Map<String, Map<String, dynamic>> _cache = {};

  // Method 1: Local Merchant Dictionary
  final Map<String, String> _localDictionary = {
    "swiggy": "Food & Dining",
    "zomato": "Food & Dining",
    "blinkit": "Food & Dining",
    "zepto": "Food & Dining",
    "starbucks": "Food & Dining",
    "mcdonalds": "Food & Dining",
    "dominos": "Food & Dining",
    "kfc": "Food & Dining",
    "instamart": "Food & Dining",
    "bigbasket": "Food & Dining",
    "whole foods": "Food & Dining",
    "trader joe's": "Food & Dining",
    "uber": "Transportation",
    "ola": "Transportation",
    "rapido": "Transportation",
    "namma yatri": "Transportation",
    "irctc": "Transportation",
    "shell": "Transportation",
    "hp petrol": "Transportation",
    "indian oil": "Transportation",
    "amazon": "Shopping",
    "flipkart": "Shopping",
    "myntra": "Shopping",
    "ajio": "Shopping",
    "nike": "Shopping",
    "zara": "Shopping",
    "bescom": "Bills & Utilities",
    "airtel": "Bills & Utilities",
    "jio": "Bills & Utilities",
    "act fibernet": "Bills & Utilities",
    "tata power": "Bills & Utilities",
    "netflix": "Entertainment",
    "spotify": "Entertainment",
    "youtube": "Entertainment",
    "bookmyshow": "Entertainment",
    "pvr": "Entertainment",
    "apollo pharmacy": "Healthcare",
    "1mg": "Healthcare",
    "pharmeasy": "Healthcare",
    "downtown realty": "Housing",
    "nobroker": "Housing",
  };

  // Method 2: Keyword Rules
  final Map<String, String> _keywordRules = {
    "salon": "Personal",
    "spa": "Personal",
    "haircut": "Personal",
    "beauty": "Personal",
    "barber": "Personal",
    "gym": "Personal",
    "fitness": "Personal",
    "fuel": "Transportation",
    "petrol": "Transportation",
    "diesel": "Transportation",
    "toll": "Transportation",
    "parking": "Transportation",
    "metro": "Transportation",
    "taxi": "Transportation",
    "cab": "Transportation",
    "flight": "Transportation",
    "airline": "Transportation",
    "train": "Transportation",
    "restaurant": "Food & Dining",
    "cafe": "Food & Dining",
    "bakery": "Food & Dining",
    "dhaba": "Food & Dining",
    "bistro": "Food & Dining",
    "hotel": "Food & Dining",
    "tea": "Food & Dining",
    "coffee": "Food & Dining",
    "snacks": "Food & Dining",
    "supermarket": "Food & Dining",
    "grocery": "Food & Dining",
    "mart": "Food & Dining",
    "hospital": "Healthcare",
    "clinic": "Healthcare",
    "medicals": "Healthcare",
    "pharmacy": "Healthcare",
    "diagnostic": "Healthcare",
    "doctor": "Healthcare",
    "electricity": "Bills & Utilities",
    "broadband": "Bills & Utilities",
    "water": "Bills & Utilities",
    "gas": "Bills & Utilities",
    "recharge": "Bills & Utilities",
    "bill": "Bills & Utilities",
    "cinema": "Entertainment",
    "movie": "Entertainment",
    "theatre": "Entertainment",
    "games": "Entertainment",
    "gaming": "Entertainment",
    "rent": "Housing",
    "maintenance": "Housing",
    "furniture": "Housing",
  };

  void _loadLearnedRules() {
    try {
      final learned = StorageService().getLearnedMerchants();
      _localDictionary.addAll(learned);
    } catch (_) {}
  }

  /// 4-Method Categorization Cascade
  Future<Map<String, dynamic>> categorize({
    required String merchantName,
    required double amount,
    required String rawText,
    bool isP2P = false,
  }) async {
    final cleanKey = merchantName.trim().toLowerCase();

    // 0. Check in-memory cache
    if (_cache.containsKey(cleanKey)) {
      return _cache[cleanKey]!;
    }

    if (isP2P) {
      final res = {
        "category": "Uncategorized",
        "confidence": 0.40,
        "method": "p2p_detected",
      };
      _cache[cleanKey] = res;
      return res;
    }

    // --- Method 1: Local Merchant Dictionary (Cheapest / Instant) ---
    if (_localDictionary.containsKey(cleanKey)) {
      final res = {
        "category": _localDictionary[cleanKey]!,
        "confidence": 1.0,
        "method": "local_dictionary",
      };
      _cache[cleanKey] = res;
      return res;
    }

    // Word-boundary match on cleanKey (merchant name only)
    for (var entry in _localDictionary.entries) {
      final pattern = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false);
      if (pattern.hasMatch(cleanKey)) {
        final res = {
          "category": entry.value,
          "confidence": 0.95,
          "method": "local_dictionary_fuzzy",
        };
        _cache[cleanKey] = res;
        return res;
      }
    }

    // --- Method 2: Keyword Rules (Whole-word regex match on merchant name ONLY) ---
    for (var entry in _keywordRules.entries) {
      final pattern = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false);
      if (pattern.hasMatch(cleanKey)) {
        final res = {
          "category": entry.value,
          "confidence": 0.90,
          "method": "keyword_rules",
        };
        _cache[cleanKey] = res;
        return res;
      }
    }

    // --- Method 3: resolveMerchant (Google Places API / Cloud Function) ---
    final placesCategory = await _resolveWithGooglePlaces(cleanKey);
    if (placesCategory != null && placesCategory.isNotEmpty && placesCategory != "Uncategorized") {
      final res = {
        "category": placesCategory,
        "confidence": 0.88,
        "method": "google_places_resolve",
      };
      _cache[cleanKey] = res;
      return res;
    }

    // --- Method 4: Ollama LLM Fallback (Last Resort) ---
    final llmCategory = await _resolveWithOllama(merchantName, amount);
    if (llmCategory != null && llmCategory['confidence'] >= 0.75) {
      final res = {
        "category": llmCategory['category'],
        "confidence": llmCategory['confidence'],
        "method": "ollama_llm",
      };
      _cache[cleanKey] = res;
      return res;
    }

    // Fallback if nothing resolves (Do NOT cache network failures / unresolved)
    return {
      "category": "Uncategorized",
      "confidence": 0.0,
      "method": "unresolved",
    };
  }

  Future<void> learnMerchant(String merchantName, String category) async {
    final cleanKey = merchantName.trim().toLowerCase();
    _localDictionary[cleanKey] = category;
    _cache[cleanKey] = {
      "category": category,
      "confidence": 1.0,
      "method": "user_learned",
    };
    await StorageService().saveLearnedMerchant(cleanKey, category);
    await ApiService().learnMerchantMapping(cleanKey, category);
  }

  Future<String?> _resolveWithGooglePlaces(String merchantName) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiService().baseUrl}/api/resolve-merchant'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': StorageService().apiKey,
        },
        body: json.encode({'merchant_name': merchantName}),
      ).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['found'] == true && data['category'] != null) {
          return data['category'];
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _resolveWithOllama(String merchantName, double amount) async {
    try {
      final res = await ApiService().parseNotification("Paid Rs $amount at $merchantName");
      final catData = res["categorization"];
      if (catData != null && catData["category"] != null && catData["category"] != "Uncategorized") {
        return {
          "category": catData["category"],
          "confidence": (catData["confidence"] as num?)?.toDouble() ?? 0.75,
        };
      }
    } catch (_) {}
    return null;
  }
}
