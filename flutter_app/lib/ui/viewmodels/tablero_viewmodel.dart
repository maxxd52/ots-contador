import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/datasources/seed_data.dart';
import '../../data/repositories/firestore_repository.dart';
import '../../data/repositories/ots_repository.dart';
import '../../domain/logic/time_calculator.dart';
import '../../domain/models/estado_lote.dart';
import '../../domain/models/lote.dart';
import '../../domain/models/registro_trabajo.dart';

class TableroViewModel extends ChangeNotifier {
  final OtsRepository repository;

  bool _isOffline = false;
  bool get isOffline =>
      _isOffline ||
      (repository is LocalOtsRepository) ||
      (repository is FirestoreOtsRepository && (repository as FirestoreOtsRepository).isOffline);

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  TableroViewModel({
    required this.repository,
    bool isOffline = false,
  }) {
    _isOffline = isOffline;
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSavingSesion = false;
  bool get isSavingSesion => _isSavingSesion;

  bool _isSavingLote = false;
  bool get isSavingLote => _isSavingLote;

  List<Lote> _lotes = [];
  List<Lote> get lotes => _lotes;

  List<RegistroTrabajo> _registros = [];
  List<RegistroTrabajo> get registros => _registros;

  Map<String, dynamic>? _sesionActiva;
  Map<String, dynamic>? get sesionActiva => _sesionActiva;

  int _segundosTranscurridos = 0;
  int get segundosTranscurridos => _segundosTranscurridos;
  String get cronometroTexto => TimeCalculator.formatearCronometro(_segundosTranscurridos);

  Timer? _timerTicker;

  // Lotes clasificados
  List<Lote> get lotesHabilitados {
    final ahora = DateTime.now();
    final habilitados = _lotes.where((l) {
      if (_sesionActiva != null && _sesionActiva!['loteId'] == l.id) return true;
      final estado = TimeCalculator.clasificarEstadoLote(
        proximoDesbloqueo: l.proximoDesbloqueo,
        ahora: ahora,
      );
      return estado.tipo == TipoEstadoLote.habilitado;
    }).toList();

    // Ordenar: primero acumulados, luego los listos de hoy
    habilitados.sort((a, b) {
      final aEsActivo = _sesionActiva != null && _sesionActiva!['loteId'] == a.id;
      final bEsActivo = _sesionActiva != null && _sesionActiva!['loteId'] == b.id;
      if (aEsActivo) return -1;
      if (bEsActivo) return 1;

      final estA = TimeCalculator.clasificarEstadoLote(proximoDesbloqueo: a.proximoDesbloqueo, ahora: ahora);
      final estB = TimeCalculator.clasificarEstadoLote(proximoDesbloqueo: b.proximoDesbloqueo, ahora: ahora);
      if (estA.esAcumulado && !estB.esAcumulado) return -1;
      if (!estA.esAcumulado && estB.esAcumulado) return 1;
      return a.supermercado.compareTo(b.supermercado);
    });

    return habilitados;
  }

  Map<String, List<Lote>> get itinerarioProximos7Dias {
    final ahora = DateTime.now();
    final Map<String, List<Lote>> grupos = {};

    final proximos = _lotes.where((l) {
      if (_sesionActiva != null && _sesionActiva!['loteId'] == l.id) return false;
      final estado = TimeCalculator.clasificarEstadoLote(
        proximoDesbloqueo: l.proximoDesbloqueo,
        ahora: ahora,
      );
      return estado.tipo == TipoEstadoLote.proximo7Dias;
    }).toList();

    proximos.sort((a, b) => a.proximoDesbloqueo!.compareTo(b.proximoDesbloqueo!));

    for (final lote in proximos) {
      final f = lote.proximoDesbloqueo!;
      final claveFecha = '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';
      grupos.putIfAbsent(claveFecha, () => []).add(lote);
    }

    return grupos;
  }

  List<Lote> get lotesFuturos {
    final ahora = DateTime.now();
    final futuros = _lotes.where((l) {
      if (_sesionActiva != null && _sesionActiva!['loteId'] == l.id) return false;
      final estado = TimeCalculator.clasificarEstadoLote(
        proximoDesbloqueo: l.proximoDesbloqueo,
        ahora: ahora,
      );
      return estado.tipo == TipoEstadoLote.futuro;
    }).toList();

    futuros.sort((a, b) => a.proximoDesbloqueo!.compareTo(b.proximoDesbloqueo!));
    return futuros;
  }

  // KPIs
  String get kpiHorasHoy {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    int mins = 0;
    for (final reg in _registros) {
      final inicioReg = DateTime(reg.inicio.year, reg.inicio.month, reg.inicio.day);
      if (inicioReg.isAtSameMomentAs(hoy)) {
        mins += reg.duracionMinutos;
      }
    }
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}m';
  }

  int get kpiListosHoy => lotesHabilitados.length;

  int get kpiProximos7d {
    final ahora = DateTime.now();
    return _lotes.where((l) {
      final estado = TimeCalculator.clasificarEstadoLote(
        proximoDesbloqueo: l.proximoDesbloqueo,
        ahora: ahora,
      );
      return estado.tipo == TipoEstadoLote.proximo7Dias;
    }).length;
  }

  /// Parsea de forma segura un timestamp dinámico a [DateTime].
  /// Soporta:
  /// - Instancias de [DateTime] directamente.
  /// - [String] en formato ISO-8601 o string numérico de época.
  /// - [int] o [num] representando milisegundos o segundos desde la época Unix.
  /// Retorna `null` si el valor es nulo, inválido o no parseable sin lanzar excepciones.
  static DateTime? parsearFechaInicio(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is int) {
      try {
        final ms = raw < 10000000000 ? raw * 1000 : raw;
        return DateTime.fromMillisecondsSinceEpoch(ms);
      } catch (_) {
        return null;
      }
    }
    if (raw is num) {
      try {
        final val = raw.toInt();
        final ms = val < 10000000000 ? val * 1000 : val;
        return DateTime.fromMillisecondsSinceEpoch(ms);
      } catch (_) {
        return null;
      }
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;

      // Check numeric epoch string first if it consists entirely of digits
      if (RegExp(r'^\d+$').hasMatch(trimmed)) {
        final numeric = int.tryParse(trimmed);
        if (numeric != null && numeric >= 1000000000) {
          try {
            final ms = numeric < 10000000000 ? numeric * 1000 : numeric;
            return DateTime.fromMillisecondsSinceEpoch(ms);
          } catch (_) {
            return null;
          }
        }
        return null;
      }

      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        if (trimmed.contains('-')) {
          final parts = trimmed.split(RegExp(r'[-T\s:]'));
          if (parts.length >= 2) {
            final m = int.tryParse(parts[1]);
            if (m != null && (m < 1 || m > 12)) return null;
          }
          if (parts.length >= 3) {
            final d = int.tryParse(parts[2]);
            if (d != null && (d < 1 || d > 31)) return null;
          }
        }
        return parsed;
      }
      return null;
    }
    return null;
  }

  Future<void> inicializar() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _lotes = await repository.obtenerLotes();
      _registros = await repository.obtenerRegistros();
      final sesion = await repository.obtenerSesionActiva();

      if (repository is FirestoreOtsRepository) {
        _isOffline = (repository as FirestoreOtsRepository).isOffline;
      } else if (repository is! LocalOtsRepository) {
        _isOffline = false;
      }

      if (sesion != null) {
        final inicio = parsearFechaInicio(sesion['inicio']);
        final loteId = sesion['loteId'];
        if (inicio != null && loteId is String && loteId.isNotEmpty) {
          _sesionActiva = sesion;
          _iniciarTimerCronometro();
        } else {
          // Sesión corrupta o incompleta detectada en almacenamiento: purgar de inmediato
          _sesionActiva = null;
          _segundosTranscurridos = 0;
          await repository.limpiarSesionActiva();
        }
      } else {
        _sesionActiva = null;
        _segundosTranscurridos = 0;
      }
    } catch (e, stackTrace) {
      _isOffline = true;
      _errorMessage = e.toString();
      if (_lotes.isEmpty) {
        _lotes = SeedData.obtenerLotesIniciales();
      }
      debugPrint('Error en inicializar() en TableroViewModel: $e\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reintentar() async {
    await inicializar();
  }

  void _iniciarTimerCronometro() {
    _detenerTimerCronometro();
    _actualizarSegundos();
    if (_sesionActiva == null) return;
    _timerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _actualizarSegundos();
      notifyListeners();
    });
  }

  void _actualizarSegundos() {
    if (_sesionActiva == null) {
      _segundosTranscurridos = 0;
      return;
    }

    final inicio = parsearFechaInicio(_sesionActiva!['inicio']);
    if (inicio == null) {
      // Auto-recuperación ante timestamp corrupto o ausente
      _recuperarSesionCorrupta();
      return;
    }

    final diff = DateTime.now().difference(inicio).inSeconds;
    _segundosTranscurridos = diff < 0 ? 0 : diff;
  }

  void _recuperarSesionCorrupta() {
    _detenerTimerCronometro();
    _sesionActiva = null;
    _segundosTranscurridos = 0;
    try {
      repository.limpiarSesionActiva().catchError((e) {
        debugPrint('Error al purgar sesión activa corrupta: $e');
      });
    } catch (e) {
      debugPrint('Error sincrónico al purgar sesión activa corrupta: $e');
    }
    notifyListeners();
  }

  void _detenerTimerCronometro() {
    _timerTicker?.cancel();
    _timerTicker = null;
  }

  Future<void> iniciarFotos(Lote lote) async {
    final ahora = DateTime.now();
    _sesionActiva = {
      'loteId': lote.id,
      'supermercado': lote.supermercado,
      'area': lote.area,
      'cantidadProductos': lote.cantidadProductos,
      'inicio': ahora.toIso8601String(),
    };

    await repository.guardarSesionActiva(_sesionActiva!);
    _iniciarTimerCronometro();
    notifyListeners();
  }

  Future<void> cancelarSesionActiva() async {
    _detenerTimerCronometro();
    _sesionActiva = null;
    _segundosTranscurridos = 0;
    await repository.limpiarSesionActiva();
    notifyListeners();
  }

  Future<void> guardarSesionFotos({
    required String loteId,
    required String supermercado,
    required String area,
    required int cantidadProductos,
    required DateTime inicio,
    required DateTime fin,
    String? observaciones,
  }) async {
    if (_isSavingSesion) return;
    _isSavingSesion = true;

    try {
      final registro = RegistroTrabajo.crear(
        loteId: loteId,
        supermercado: supermercado,
        area: area,
        cantidadProductos: cantidadProductos,
        inicio: inicio,
        fin: fin,
        observaciones: observaciones,
      );

      // La persistencia atómica en el repositorio actualiza el registro y reprograma el lote (+120 días).
      await repository.guardarRegistro(registro);

      await cancelarSesionActiva();
      _lotes = await repository.obtenerLotes();
      _registros = await repository.obtenerRegistros();
    } finally {
      _isSavingSesion = false;
      notifyListeners();
    }
  }

  Future<void> guardarLote(Lote lote) async {
    if (_isSavingLote) return;
    _isSavingLote = true;

    try {
      await repository.guardarLote(lote);
      _lotes = await repository.obtenerLotes();
    } finally {
      _isSavingLote = false;
      notifyListeners();
    }
  }

  Future<void> eliminarLote(String id) async {
    if (_sesionActiva != null && _sesionActiva!['loteId'] == id) {
      await cancelarSesionActiva();
    }
    await repository.eliminarLote(id);
    _lotes = await repository.obtenerLotes();
    notifyListeners();
  }

  Future<void> desbloquearLoteAnticipadamente(Lote lote) async {
    final loteActualizado = lote.copyWith(
      resetUltimoInicio: true,
      resetDesbloqueo: true,
    );
    await repository.guardarLote(loteActualizado);
    _lotes = await repository.obtenerLotes();
    notifyListeners();
  }

  @override
  void dispose() {
    _detenerTimerCronometro();
    super.dispose();
  }
}
