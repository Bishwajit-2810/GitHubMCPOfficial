import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

/// Three-tier storage:
/// - flutter_secure_storage  → JWT token (encrypted)
/// - shared_preferences      → simple boolean/string flags
/// - hive                    → structured data (context, tasks cache)
class StorageService {
  StorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kContextBox = 'context_cache';
  static const _kTasksBox = 'tasks_cache';

  // ── Hive box openers (call once in main before runApp) ────────────────────

  static Future<void> initHive() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_kContextBox);
    await Hive.openBox<String>(_kTasksBox);
  }

  // ── JWT (flutter_secure_storage) ──────────────────────────────────────────

  static Future<void> saveToken(String token) =>
      _storage.write(key: Constants.kBackendToken, value: token);

  static Future<String?> readToken() =>
      _storage.read(key: Constants.kBackendToken);

  static Future<void> deleteToken() =>
      _storage.delete(key: Constants.kBackendToken);

  // ── GitHub connection flag (shared_preferences) ───────────────────────────

  static Future<void> setGithubConnected(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Constants.kGithubConnected, value);
  }

  static Future<bool> isGithubConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(Constants.kGithubConnected) ?? false;
  }

  // ── User context (hive) ───────────────────────────────────────────────────

  static Future<void> saveContextToHive(
      String? owner, String? repo, int? project) async {
    final box = Hive.box<String>(_kContextBox);
    await box.put('data', jsonEncode({
      'owner': owner,
      'repo': repo,
      'project': project,
    }));
  }

  static Map<String, dynamic> readContextFromHive() {
    final box = Hive.box<String>(_kContextBox);
    final raw = box.get('data');
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  // ── Tasks cache (hive) ────────────────────────────────────────────────────

  static Future<void> cacheTaskList(String key, List<Map<String, dynamic>> tasks) async {
    final box = Hive.box<String>(_kTasksBox);
    await box.put(key, jsonEncode(tasks));
  }

  static List<Map<String, dynamic>> getCachedTaskList(String key) {
    final box = Hive.box<String>(_kTasksBox);
    final raw = box.get(key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ── Full clear (logout) ────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await Hive.box<String>(_kContextBox).clear();
    await Hive.box<String>(_kTasksBox).clear();
  }
}
