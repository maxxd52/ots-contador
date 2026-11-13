import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/lote.dart';
import '../../domain/models/registro_trabajo.dart';
import '../datasources/seed_data.dart';
import 'ots_repository.dart';

/// Repositorio sincronizado en tiempo real con Google Cloud Firestore
/// Incluye persistencia offline automática para operar en góndolas sin señal.
class FirestoreOtsRepository implements OtsRepository {
  final FirebaseFirestore? _customFirestore;
  final SharedPreferences? prefs;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  static const String keyLotes = 'ots_lotes';
  static const String keyRegistros = 'ots_registros';
  static const String keySesionActiva = 'ots_sesion_activa';
  static const Duration timeoutDuration = Duration(seconds: 5);

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  FirestoreOtsRepository({
    FirebaseFirestore? firestore,
    this.prefs,
  }) : _customFirestore = firestore;

  Future<SharedPreferences> _getPrefs() async {
    final existing = prefs;
    if (existing != null) return existing;
    return await SharedPreferences.getInstance();
  }

  @override
  Future<List<Lote>> obtenerLotes() async {
    try {
      final snapshot = await _firestore
          .collection('lotes')
          .get()
          .timeout(timeoutDuration);
      final lotes = snapshot.docs.map((doc) => Lote.fromJson(doc.data())).toList();
      lotes.sort((a, b) => a.supermercado.compareTo(b.supermercado));

      _isOffline = false;
      await _guardarLotesEnCache(lotes);
      return lotes;
    } catch (_) {
      _isOffline = true;
      final cachedLotes = await _obtenerLotesDeCache();
      if (cachedLotes.isNotEmpty) {
        return cachedLotes;
      }
      final seed = SeedData.obtenerLotesIniciales();
      await _guardarLotesEnCache(seed);
      return seed;
    }
  }

  Future<List<Lote>> _obtenerLotesDeCache() async {
    try {
      final p = await _getPrefs();
      final jsonStr = p.getString(keyLotes);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      final lotes = list
          .map((item) => Lote.fromJson(item as Map<String, dynamic>))
          .toList();
      lotes.sort((a, b) => a.supermercado.compareTo(b.supermercado));
      return lotes;
    } catch (_) {
      return [];
    }
  }

  Future<void> _guardarLotesEnCache(List<Lote> lotes) async {
    try {
      final p = await _getPrefs();
      final list = lotes.map((l) => l.toJson()).toList();
      await p.setString(keyLotes, jsonEncode(list));
    } catch (_) {
      // Ignorar fallas secundarias de cache
    }
  }

  @override
  Future<Lote> guardarLote(Lote lote) async {
    await _firestore
        .collection('lotes')
        .doc(lote.id)
        .set(lote.toJson(), SetOptions(merge: true));
    return lote;
  }

  @override
  Future<void> eliminarLote(String id) async {
    await _firestore.collection('lotes').doc(id).delete();
  }

  @override
  Future<List<RegistroTrabajo>> obtenerRegistros() async {
    try {
      final snapshot = await _firestore
          .collection('registros_trabajo')
          .get()
          .timeout(timeoutDuration);
      final registros = snapshot.docs
          .map((doc) => RegistroTrabajo.fromJson(doc.data()))
          .toList();
      registros.sort((a, b) => b.inicio.compareTo(a.inicio));

      _isOffline = false;
      await _guardarRegistrosEnCache(registros);
      return registros;
    } catch (_) {
      _isOffline = true;
      return await _obtenerRegistrosDeCache();
    }
  }

  Future<List<RegistroTrabajo>> _obtenerRegistrosDeCache() async {
    try {
      final p = await _getPrefs();
      final jsonStr = p.getString(keyRegistros);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      final registros = list
          .map((item) => RegistroTrabajo.fromJson(item as Map<String, dynamic>))
          .toList();
      registros.sort((a, b) => b.inicio.compareTo(a.inicio));
      return registros;
    } catch (_) {
      return [];
    }
  }

  Future<void> _guardarRegistrosEnCache(List<RegistroTrabajo> registros) async {
    try {
      final p = await _getPrefs();
      final list = registros.map((r) => r.toJson()).toList();
      await p.setString(keyRegistros, jsonEncode(list));
    } catch (_) {
      // Ignorar fallas secundarias de cache
    }
  }

  @override
  Future<RegistroTrabajo> guardarRegistro(RegistroTrabajo registro) async {
    final registroRef = _firestore.collection('registros_trabajo').doc(registro.id);
    final loteRef = _firestore.collection('lotes').doc(registro.loteId);

    // 1. Preparar el lote actualizado antes de la mutación atómica.
    // Si la lectura remota falla o timeout por red/offline, recurrir al cache local de lotes.
    Lote? loteExistente;
    try {
      final loteSnap = await loteRef.get().timeout(timeoutDuration);
      if (loteSnap.exists && loteSnap.data() != null) {
        loteExistente = Lote.fromJson(loteSnap.data()!);
      }
    } catch (_) {
      final cachedLotes = await _obtenerLotesDeCache();
      final idx = cachedLotes.indexWhere((l) => l.id == registro.loteId);
      if (idx >= 0) {
        loteExistente = cachedLotes[idx];
      }
    }

    final Lote loteActualizado;
    if (loteExistente != null) {
      loteActualizado = loteExistente.copyWith(
        supermercado: registro.supermercado,
        area: registro.area,
        cantidadProductos: registro.cantidadProductos > 0
            ? registro.cantidadProductos
            : loteExistente.cantidadProductos,
        ultimoInicio: registro.inicio,
        proximoDesbloqueo: registro.nuevoDesbloqueo,
      );
    } else {
      loteActualizado = Lote(
        id: registro.loteId,
        supermercado: registro.supermercado,
        area: registro.area,
        cantidadProductos: registro.cantidadProductos,
        ultimoInicio: registro.inicio,
        proximoDesbloqueo: registro.nuevoDesbloqueo,
        creadoEn: registro.creadoEn,
      );
    }

    // 2. Ejecutar escritura atómica indivisible con WriteBatch
    final batch = _firestore.batch();
    batch.set(registroRef, registro.toJson(), SetOptions(merge: true));
    batch.set(loteRef, loteActualizado.toJson(), SetOptions(merge: true));
    await batch.commit();

    // 3. Actualizar cache local defensivamente sólo tras commit exitoso
    try {
      final cachedLotes = await _obtenerLotesDeCache();
      final idx = cachedLotes.indexWhere((l) => l.id == loteActualizado.id);
      if (idx >= 0) {
        cachedLotes[idx] = loteActualizado;
      } else {
        cachedLotes.add(loteActualizado);
      }
      await _guardarLotesEnCache(cachedLotes);

      final cachedRegistros = await _obtenerRegistrosDeCache();
      cachedRegistros.removeWhere((r) => r.id == registro.id);
      cachedRegistros.insert(0, registro);
      await _guardarRegistrosEnCache(cachedRegistros);
    } catch (_) {
      // Ignorar fallas secundarias de cache
    }

    return registro;
  }

  @override
  Future<void> guardarSesionActiva(Map<String, dynamic> sesion) async {
    final p = await _getPrefs();
    await p.setString(keySesionActiva, jsonEncode(sesion));
  }

  @override
  Future<Map<String, dynamic>?> obtenerSesionActiva() async {
    final p = await _getPrefs();
    final str = p.getString(keySesionActiva);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> limpiarSesionActiva() async {
    final p = await _getPrefs();
    await p.remove(keySesionActiva);
  }
}
