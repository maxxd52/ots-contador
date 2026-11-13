import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/domain/models/registro_trabajo.dart';

/// Helper fixtures and utilities for initializing and inspecting [SharedPreferences]
/// in E2E tests, particularly for R7 (Resilient Session Parsing) and R1 (Cache Fallback).
class MockSharedPreferencesHelper {
  static const String keySesionActiva = 'ots_sesion_activa';
  static const String keyLotes = 'ots_lotes';
  static const String keyRegistros = 'ots_registros';

  /// Internal state registry tracking current mock preferences keys and values.
  static final Map<String, Object> _mockState = <String, Object>{};

  /// Returns an unmodifiable view of the current in-memory mock state registry.
  static Map<String, Object> get currentMockState =>
      Map<String, Object>.unmodifiable(_mockState);

  /// Sets empty preferences initial values and clears internal tracking.
  static void setEmpty() {
    _mockState.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  }

  /// Sets composite mock state in [SharedPreferences], preserving existing keys
  /// when [merge] is true (the default).
  ///
  /// This method enables simultaneous or incremental configuration of cached lots,
  /// cached work records, active session payloads (structured or corrupted), and
  /// arbitrary additional preference keys without clobbering previously configured state.
  ///
  /// Parameters:
  /// - [lotes]: Domain [Lote] objects encoded to JSON under [keyLotes].
  /// - [rawLotes]: Raw string stored directly under [keyLotes] (e.g. malformed JSON).
  /// - [registros]: Domain [RegistroTrabajo] objects encoded to JSON under [keyRegistros].
  /// - [rawRegistros]: Raw string stored directly under [keyRegistros] (e.g. malformed JSON).
  /// - [sesionActiva]: Session map encoded to JSON under [keySesionActiva].
  /// - [rawSesionActiva]: Raw string stored directly under [keySesionActiva] (e.g. malformed timestamp).
  /// - [additionalValues]: Additional primitive mock values (int, bool, String, double, `List<String>`).
  /// - [removeKeys]: Keys to remove from the current mock state.
  /// - [merge]: If true (default), merges with existing mock keys; if false, clears prior mock keys first.
  static void setMockState({
    List<Lote>? lotes,
    String? rawLotes,
    List<RegistroTrabajo>? registros,
    String? rawRegistros,
    Map<String, dynamic>? sesionActiva,
    String? rawSesionActiva,
    Map<String, Object>? additionalValues,
    Iterable<String>? removeKeys,
    bool merge = true,
  }) {
    if (lotes != null && rawLotes != null) {
      throw ArgumentError('Cannot provide both lotes and rawLotes to setMockState.');
    }
    if (registros != null && rawRegistros != null) {
      throw ArgumentError('Cannot provide both registros and rawRegistros to setMockState.');
    }
    if (sesionActiva != null && rawSesionActiva != null) {
      throw ArgumentError('Cannot provide both sesionActiva and rawSesionActiva to setMockState.');
    }

    if (!merge) {
      _mockState.clear();
    }

    if (rawLotes != null) {
      _mockState[keyLotes] = rawLotes;
    } else if (lotes != null) {
      _mockState[keyLotes] = jsonEncode(lotes.map((l) => l.toJson()).toList());
    }

    if (rawRegistros != null) {
      _mockState[keyRegistros] = rawRegistros;
    } else if (registros != null) {
      _mockState[keyRegistros] = jsonEncode(registros.map((r) => r.toJson()).toList());
    }

    if (rawSesionActiva != null) {
      _mockState[keySesionActiva] = rawSesionActiva;
    } else if (sesionActiva != null) {
      _mockState[keySesionActiva] = jsonEncode(sesionActiva);
    }

    if (additionalValues != null) {
      _mockState.addAll(additionalValues);
    }

    if (removeKeys != null) {
      for (final key in removeKeys) {
        _mockState.remove(key);
      }
    }

    SharedPreferences.setMockInitialValues(Map<String, Object>.from(_mockState));
  }

  /// Incrementally updates or adds mock preference key-value pairs without
  /// erasing existing entries.
  static void updateMockValues(Map<String, Object> values) {
    _mockState.addAll(values);
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(_mockState));
  }

  /// Asynchronously captures live keys from [SharedPreferences] (including app runtime
  /// mutations), merges newly supplied fixture parameters, and reapplies mock storage.
  static Future<void> mergeLiveState({
    List<Lote>? lotes,
    String? rawLotes,
    List<RegistroTrabajo>? registros,
    String? rawRegistros,
    Map<String, dynamic>? sesionActiva,
    String? rawSesionActiva,
    Map<String, Object>? additionalValues,
    Iterable<String>? removeKeys,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      final val = prefs.get(key);
      if (val != null) {
        _mockState[key] = val;
      }
    }
    setMockState(
      lotes: lotes,
      rawLotes: rawLotes,
      registros: registros,
      rawRegistros: rawRegistros,
      sesionActiva: sesionActiva,
      rawSesionActiva: rawSesionActiva,
      additionalValues: additionalValues,
      removeKeys: removeKeys,
      merge: true,
    );
  }

  /// Sets a valid active session fixture in SharedPreferences with ISO-8601 string.
  static void setValidSession({
    required String loteId,
    required DateTime inicio,
    bool merge = false,
  }) {
    setMockState(
      sesionActiva: {
        'loteId': loteId,
        'inicio': inicio.toIso8601String(),
      },
      merge: merge,
    );
  }

  /// Sets an active session where `inicio` is an integer epoch millisecond timestamp.
  static void setSessionWithEpochMs({
    required String loteId,
    required int epochMs,
    bool merge = false,
  }) {
    setMockState(
      sesionActiva: {
        'loteId': loteId,
        'inicio': epochMs,
      },
      merge: merge,
    );
  }

  /// Sets an active session fixture that is missing the required `inicio` key.
  static void setSessionWithMissingInicio({
    required String loteId,
    bool merge = false,
  }) {
    setMockState(
      sesionActiva: {
        'loteId': loteId,
      },
      merge: merge,
    );
  }

  /// Sets an active session fixture where `inicio` contains an unparseable, malformed date string.
  static void setSessionWithMalformedDate({
    required String loteId,
    String malformedDate = 'not-a-valid-iso8601-timestamp',
    bool merge = false,
  }) {
    setMockState(
      sesionActiva: {
        'loteId': loteId,
        'inicio': malformedDate,
      },
      merge: merge,
    );
  }

  /// Sets an active session fixture where `inicio` is a non-string / non-integer type (e.g. bool, array, map).
  static void setSessionWithNonStringInicio({
    required String loteId,
    dynamic nonStringValue = true,
    bool merge = false,
  }) {
    setMockState(
      sesionActiva: {
        'loteId': loteId,
        'inicio': nonStringValue,
      },
      merge: merge,
    );
  }

  /// Sets a completely corrupted, non-JSON raw string under the session key.
  static void setSessionWithNonJsonString({
    String corruptedPayload = 'CORRUPTED_RAW_{{{[[INVALID_JSON_PAYLOAD##',
    bool merge = false,
  }) {
    setMockState(
      rawSesionActiva: corruptedPayload,
      merge: merge,
    );
  }

  /// Sets an empty string `""` under the session key.
  static void setSessionEmptyString({bool merge = false}) {
    setMockState(
      rawSesionActiva: '',
      merge: merge,
    );
  }

  /// Sets an oversized garbage string under the session key (e.g. 1 MB).
  static void setLargeGarbageSession(int byteCount, {bool merge = false}) {
    final buffer = StringBuffer();
    for (int i = 0; i < byteCount; i++) {
      buffer.write('X');
    }
    setMockState(
      rawSesionActiva: buffer.toString(),
      merge: merge,
    );
  }

  /// Sets cached lotes in SharedPreferences.
  static void setLotes(List<Lote> lotes, {bool merge = false}) {
    setMockState(
      lotes: lotes,
      merge: merge,
    );
  }

  /// Sets corrupted non-JSON data under the lotes cache key.
  static void setCorruptedLotes({
    String corruptedPayload = 'corrupted-non-json-lotes',
    bool merge = false,
  }) {
    setMockState(
      rawLotes: corruptedPayload,
      merge: merge,
    );
  }

  /// Sets cached registros in SharedPreferences.
  static void setRegistros(List<RegistroTrabajo> registros, {bool merge = false}) {
    setMockState(
      registros: registros,
      merge: merge,
    );
  }

  /// Sets corrupted non-JSON data under the registros cache key.
  static void setCorruptedRegistros({
    String corruptedPayload = 'corrupted-non-json-registros',
    bool merge = false,
  }) {
    setMockState(
      rawRegistros: corruptedPayload,
      merge: merge,
    );
  }

  /// Inspects whether the active session key is absent or purged from SharedPreferences.
  static Future<bool> isSessionPurged() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keySesionActiva) == null;
  }

  /// Reads the raw string stored under the active session key.
  static Future<String?> getRawSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keySesionActiva);
  }

  /// Decodes and returns the session map if valid JSON, or null otherwise.
  static Future<Map<String, dynamic>?> getDecodedSession() async {
    final raw = await getRawSession();
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Reads the raw string stored under the lotes cache key.
  static Future<String?> getRawLotes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyLotes);
  }

  /// Decodes and returns the cached lotes list if valid JSON, or null otherwise.
  static Future<List<dynamic>?> getDecodedLotes() async {
    final raw = await getRawLotes();
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Reads the raw string stored under the registros cache key.
  static Future<String?> getRawRegistros() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyRegistros);
  }

  /// Decodes and returns the cached registros list if valid JSON, or null otherwise.
  static Future<List<dynamic>?> getDecodedRegistros() async {
    final raw = await getRawRegistros();
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Returns all currently stored preference keys from [SharedPreferences].
  static Future<Set<String>> getStoredKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys();
  }

  /// Returns the stored typed preference value for the given [key].
  static Future<T?> getStoredValue<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.get(key) as T?;
  }
}
