import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/ots_repository.dart';
import '../../domain/logic/time_calculator.dart';
import '../../domain/models/estado_lote.dart';
import '../../domain/models/lote.dart';
import '../../domain/models/registro_trabajo.dart';

class TableroViewModel extends ChangeNotifier {
  final OtsRepository repository;

  TableroViewModel({required this.repository});

  bool _isLoading = false;
  bool get isLoading => _isLoading;

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

  Future<void> inicializar() async {
    _isLoading = true;
    notifyListeners();

    try {
      _lotes = await repository.obtenerLotes();
      _registros = await repository.obtenerRegistros();
      _sesionActiva = await repository.obtenerSesionActiva();

      if (_sesionActiva != null) {
        _iniciarTimerCronometro();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _iniciarTimerCronometro() {
    _detenerTimerCronometro();
    _actualizarSegundos();
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
    final inicioStr = _sesionActiva!['inicio'] as String;
    final inicio = DateTime.parse(inicioStr);
    _segundosTranscurridos = DateTime.now().difference(inicio).inSeconds;
    if (_segundosTranscurridos < 0) _segundosTranscurridos = 0;
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
    final registro = RegistroTrabajo.crear(
      loteId: loteId,
      supermercado: supermercado,
      area: area,
      cantidadProductos: cantidadProductos,
      inicio: inicio,
      fin: fin,
      observaciones: observaciones,
    );

    await repository.guardarRegistro(registro);
    await cancelarSesionActiva();
    _lotes = await repository.obtenerLotes();
    _registros = await repository.obtenerRegistros();
    notifyListeners();
  }

  Future<void> guardarLote(Lote lote) async {
    await repository.guardarLote(lote);
    _lotes = await repository.obtenerLotes();
    notifyListeners();
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
