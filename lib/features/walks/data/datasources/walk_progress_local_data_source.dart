// =============================================================================
// WALK PROGRESS LOCAL DATA SOURCE
// =============================================================================
// Guarda en el teléfono (SharedPreferences, no Firestore) el progreso del paseo
// en curso. Se sobrescribe en cada guardado y se borra al finalizar o cancelar,
// por lo que no crece.
// =============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

abstract class WalkProgressLocalDataSource {
  Future<void> write(Map<String, dynamic> json);
  Future<Map<String, dynamic>?> read();
  Future<void> delete();
}

class WalkProgressLocalDataSourceImpl implements WalkProgressLocalDataSource {
  static const String _key = 'walk_progress_v1';

  @override
  Future<void> write(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(json));
  }

  /// Null si no hay nada guardado o el contenido está corrupto (en ese caso se borra).
  @override
  Future<Map<String, dynamic>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      await prefs.remove(_key);
      return null;
    }
  }

  @override
  Future<void> delete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
