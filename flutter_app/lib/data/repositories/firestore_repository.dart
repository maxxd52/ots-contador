import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/lote.dart';
import '../../domain/models/registro_trabajo.dart';
import 'ots_repository.dart';

/// Repositorio sincronizado en tiempo real con Google Cloud Firestore
/// Incluye persistencia offline automática para operar en góndolas sin señal.
class FirestoreOtsRepository implements OtsRepository {
  final FirebaseFirestore _firestore;
  final SharedPreferences? prefs;

  static const String keySesionActiva = 'ots_sesion_activa';

  FirestoreOtsRepository({
    FirebaseFirestore? firestore,
    this.prefs,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<SharedPreferences> _getPrefs() async {
    final existing = prefs;
    if (existing != null) return existing;
    return await SharedPreferences.getInstance();
  }

  @override
  Future<List<Lote>> obtenerLotes() async {
    final snapshot = await _firestore.collection('lotes').get();
    final lotes = snapshot.docs.map((doc) => Lote.fromJson(doc.data())).toList();
    lotes.sort((a, b) => a.supermercado.compareTo(b.supermercado));
    return lotes;
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
    final snapshot = await _firestore.collection('registros_trabajo').get();
    final registros = snapshot.docs
        .map((doc) => RegistroTrabajo.fromJson(doc.data()))
        .toList();
    registros.sort((a, b) => b.inicio.compareTo(a.inicio));
    return registros;
  }

  @override
  Future<RegistroTrabajo> guardarRegistro(RegistroTrabajo registro) async {
    await _firestore
        .collection('registros_trabajo')
        .doc(registro.id)
        .set(registro.toJson(), SetOptions(merge: true));
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
