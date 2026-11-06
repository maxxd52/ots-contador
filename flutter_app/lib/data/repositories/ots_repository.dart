import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/lote.dart';
import '../../domain/models/registro_trabajo.dart';
import '../datasources/seed_data.dart';

abstract class OtsRepository {
  Future<List<Lote>> obtenerLotes();
  Future<Lote> guardarLote(Lote lote);
  Future<void> eliminarLote(String id);

  Future<List<RegistroTrabajo>> obtenerRegistros();
  Future<RegistroTrabajo> guardarRegistro(RegistroTrabajo registro);

  Future<void> guardarSesionActiva(Map<String, dynamic> sesion);
  Future<Map<String, dynamic>?> obtenerSesionActiva();
  Future<void> limpiarSesionActiva();
}

class LocalOtsRepository implements OtsRepository {
  static const String keyLotes = 'ots_lotes';
  static const String keyRegistros = 'ots_registros';
  static const String keySesionActiva = 'ots_sesion_activa';

  final SharedPreferences? _prefs;

  LocalOtsRepository([this._prefs]);

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs;
    return await SharedPreferences.getInstance();
  }

  @override
  Future<List<Lote>> obtenerLotes() async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(keyLotes);

    if (jsonStr == null || jsonStr.isEmpty) {
      final iniciales = SeedData.obtenerLotesIniciales();
      await _guardarListaLotes(prefs, iniciales);
      return iniciales;
    }

    try {
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => Lote.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      final iniciales = SeedData.obtenerLotesIniciales();
      await _guardarListaLotes(prefs, iniciales);
      return iniciales;
    }
  }

  Future<void> _guardarListaLotes(SharedPreferences prefs, List<Lote> lotes) async {
    final list = lotes.map((l) => l.toJson()).toList();
    await prefs.setString(keyLotes, jsonEncode(list));
  }

  @override
  Future<Lote> guardarLote(Lote lote) async {
    final prefs = await _getPrefs();
    final lotes = await obtenerLotes();
    final index = lotes.indexWhere((l) => l.id == lote.id);

    if (index >= 0) {
      lotes[index] = lote;
    } else {
      lotes.add(lote);
    }

    await _guardarListaLotes(prefs, lotes);
    return lote;
  }

  @override
  Future<void> eliminarLote(String id) async {
    final prefs = await _getPrefs();
    final lotes = await obtenerLotes();
    lotes.removeWhere((l) => l.id == id);
    await _guardarListaLotes(prefs, lotes);
  }

  @override
  Future<List<RegistroTrabajo>> obtenerRegistros() async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(keyRegistros);

    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      final registros = list.map((item) => RegistroTrabajo.fromJson(item as Map<String, dynamic>)).toList();
      registros.sort((a, b) => b.inicio.compareTo(a.inicio));
      return registros;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<RegistroTrabajo> guardarRegistro(RegistroTrabajo registro) async {
    final prefs = await _getPrefs();
    final registros = await obtenerRegistros();
    registros.insert(0, registro);

    final list = registros.map((r) => r.toJson()).toList();
    await prefs.setString(keyRegistros, jsonEncode(list));

    // Actualizar automáticamente el lote asociado
    final lotes = await obtenerLotes();
    final index = lotes.indexWhere((l) => l.id == registro.loteId);
    if (index >= 0) {
      final loteActual = lotes[index];
      final loteActualizado = loteActual.copyWith(
        ultimoInicio: registro.inicio,
        proximoDesbloqueo: registro.nuevoDesbloqueo,
        cantidadProductos: registro.cantidadProductos > 0
            ? registro.cantidadProductos
            : loteActual.cantidadProductos,
      );
      lotes[index] = loteActualizado;
      await _guardarListaLotes(prefs, lotes);
    }

    return registro;
  }

  @override
  Future<void> guardarSesionActiva(Map<String, dynamic> sesion) async {
    final prefs = await _getPrefs();
    await prefs.setString(keySesionActiva, jsonEncode(sesion));
  }

  @override
  Future<Map<String, dynamic>?> obtenerSesionActiva() async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(keySesionActiva);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> limpiarSesionActiva() async {
    final prefs = await _getPrefs();
    await prefs.remove(keySesionActiva);
  }
}
