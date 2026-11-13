import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/domain/models/registro_trabajo.dart';
import 'package:flutter_app/domain/logic/time_calculator.dart';

/// Fluent test builder for constructing [Lote] instances in E2E test suites.
class LoteBuilder {
  String _id;
  String _supermercado;
  String _area;
  int _cantidadProductos;
  DateTime? _ultimoInicio;
  DateTime? _proximoDesbloqueo;
  String? _notas;
  DateTime _creadoEn;

  LoteBuilder({
    this._id = 'lote_test_default',
    this._supermercado = 'Supermercado Test',
    this._area = 'Sector Central',
    this._cantidadProductos = 50,
    this._ultimoInicio,
    this._proximoDesbloqueo,
    this._notas,
    DateTime? creadoEn,
  }) : _creadoEn = creadoEn ?? DateTime(2026, 11, 1, 10, 0);

  /// Preset factory for a lot that is currently enabled (LISTO) for photography today.
  factory LoteBuilder.habilitado({
    String id = 'lote_habilitado',
    String supermercado = 'Carrefour Express',
    String area = 'Bebidas',
    int cantidadProductos = 60,
  }) {
    return LoteBuilder(
      id: id,
      supermercado: supermercado,
      area: area,
      cantidadProductos: cantidadProductos,
      ultimoInicio: null,
      proximoDesbloqueo: null,
    );
  }

  /// Preset factory for a lot unlocked today (LISTO no acumulado).
  factory LoteBuilder.listoHoy({
    String id = 'lote_listo_hoy',
    String supermercado = 'Coto Once',
    String area = 'Lácteos',
    int cantidadProductos = 80,
  }) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day, 8, 0);
    return LoteBuilder(
      id: id,
      supermercado: supermercado,
      area: area,
      cantidadProductos: cantidadProductos,
      ultimoInicio: todayMidnight.subtract(const Duration(days: 120)),
      proximoDesbloqueo: todayMidnight,
    );
  }

  /// Preset factory for an accumulated lot (unlocked several days ago).
  factory LoteBuilder.acumulado({
    String id = 'lote_acumulado',
    String supermercado = 'Jumbo Palermo',
    String area = 'Limpieza',
    int cantidadProductos = 120,
    int daysAgo = 5,
  }) {
    final now = DateTime.now();
    final unlockDate = now.subtract(Duration(days: daysAgo));
    return LoteBuilder(
      id: id,
      supermercado: supermercado,
      area: area,
      cantidadProductos: cantidadProductos,
      ultimoInicio: unlockDate.subtract(const Duration(days: 120)),
      proximoDesbloqueo: unlockDate,
    );
  }

  /// Preset factory for a lot scheduled in the future (> 7 days).
  factory LoteBuilder.futuro({
    String id = 'lote_futuro',
    String supermercado = 'Dia San Telmo',
    String area = 'Perfumería',
    int cantidadProductos = 40,
    int daysAhead = 60,
  }) {
    final now = DateTime.now();
    final unlockDate = now.add(Duration(days: daysAhead));
    return LoteBuilder(
      id: id,
      supermercado: supermercado,
      area: area,
      cantidadProductos: cantidadProductos,
      ultimoInicio: unlockDate.subtract(const Duration(days: 120)),
      proximoDesbloqueo: unlockDate,
    );
  }

  /// Preset factory for a lot scheduled in the upcoming 7 days.
  factory LoteBuilder.proximo7Dias({
    String id = 'lote_proximo_7dias',
    String supermercado = 'Disco Recoleta',
    String area = 'Carnicería',
    int cantidadProductos = 75,
    int daysAhead = 3,
  }) {
    final now = DateTime.now();
    final unlockDate = now.add(Duration(days: daysAhead));
    return LoteBuilder(
      id: id,
      supermercado: supermercado,
      area: area,
      cantidadProductos: cantidadProductos,
      ultimoInicio: unlockDate.subtract(const Duration(days: 120)),
      proximoDesbloqueo: unlockDate,
    );
  }

  LoteBuilder withId(String id) {
    _id = id;
    return this;
  }

  LoteBuilder withSupermercado(String supermercado) {
    _supermercado = supermercado;
    return this;
  }

  LoteBuilder withArea(String area) {
    _area = area;
    return this;
  }

  LoteBuilder withCantidadProductos(int cantidad) {
    _cantidadProductos = cantidad;
    return this;
  }

  LoteBuilder withUltimoInicio(DateTime? date, {bool autoCalculateDesbloqueo = false}) {
    _ultimoInicio = date;
    if (autoCalculateDesbloqueo && date != null) {
      _proximoDesbloqueo = TimeCalculator.calcularProximoDesbloqueo(date);
    }
    return this;
  }

  LoteBuilder withProximoDesbloqueo(DateTime? date) {
    _proximoDesbloqueo = date;
    return this;
  }

  LoteBuilder withNotas(String? notas) {
    _notas = notas;
    return this;
  }

  LoteBuilder withCreadoEn(DateTime date) {
    _creadoEn = date;
    return this;
  }

  Lote build() {
    return Lote(
      id: _id,
      supermercado: _supermercado,
      area: _area,
      cantidadProductos: _cantidadProductos,
      ultimoInicio: _ultimoInicio,
      proximoDesbloqueo: _proximoDesbloqueo,
      notas: _notas,
      creadoEn: _creadoEn,
    );
  }
}

/// Fluent test builder for constructing [RegistroTrabajo] instances in E2E test suites.
class RegistroTrabajoBuilder {
  String _id;
  String _loteId;
  String _supermercado;
  String _area;
  int _cantidadProductos;
  DateTime _inicio;
  DateTime _fin;
  int? _duracionMinutos;
  double? _horasDecimales;
  String? _duracionTexto;
  DateTime? _nuevoDesbloqueo;
  String? _observaciones;
  DateTime _creadoEn;

  RegistroTrabajoBuilder({
    this._id = 'reg_test_default',
    this._loteId = 'lote_test_default',
    this._supermercado = 'Supermercado Test',
    this._area = 'Sector Central',
    this._cantidadProductos = 50,
    DateTime? inicio,
    DateTime? fin,
    this._duracionMinutos,
    this._horasDecimales,
    this._duracionTexto,
    this._nuevoDesbloqueo,
    this._observaciones,
    DateTime? creadoEn,
  })  : _inicio = inicio ?? DateTime(2026, 11, 12, 10, 0),
        _fin = fin ?? DateTime(2026, 11, 12, 10, 45),
        _creadoEn = creadoEn ?? (fin ?? DateTime(2026, 11, 12, 10, 45));

  /// Preset factory for a nominal 45-minute work session.
  factory RegistroTrabajoBuilder.standard({
    String id = 'reg_standard',
    String loteId = 'lote_test_default',
    String supermercado = 'Carrefour San Martín',
    String area = 'Galletitas',
    int cantidadProductos = 80,
    DateTime? inicio,
    int minutes = 45,
    String? observaciones,
  }) {
    final start = inicio ?? DateTime(2026, 11, 12, 10, 0);
    final end = start.add(Duration(minutes: minutes));
    return RegistroTrabajoBuilder(
      id: id,
      loteId: loteId,
      supermercado: supermercado,
      area: area,
      cantidadProductos: cantidadProductos,
      inicio: start,
      fin: end,
      observaciones: observaciones,
    );
  }

  /// Preset factory for a boundary zero-duration work session (`inicio == fin`).
  factory RegistroTrabajoBuilder.zeroDuration({
    String id = 'reg_zero_duration',
    String loteId = 'lote_test_default',
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime(2026, 11, 12, 14, 0);
    return RegistroTrabajoBuilder(
      id: id,
      loteId: loteId,
      inicio: now,
      fin: now,
      duracionMinutos: 0,
      horasDecimales: 0.0,
      duracionTexto: '0m',
      observaciones: 'Zero duration check',
    );
  }

  RegistroTrabajoBuilder withId(String id) {
    _id = id;
    return this;
  }

  RegistroTrabajoBuilder withLoteId(String loteId) {
    _loteId = loteId;
    return this;
  }

  RegistroTrabajoBuilder withSupermercado(String supermercado) {
    _supermercado = supermercado;
    return this;
  }

  RegistroTrabajoBuilder withArea(String area) {
    _area = area;
    return this;
  }

  RegistroTrabajoBuilder withCantidadProductos(int cantidad) {
    _cantidadProductos = cantidad;
    return this;
  }

  RegistroTrabajoBuilder withInicio(DateTime inicio) {
    _inicio = inicio;
    return this;
  }

  RegistroTrabajoBuilder withFin(DateTime fin) {
    _fin = fin;
    return this;
  }

  RegistroTrabajoBuilder withExplicitDuration({
    required int minutos,
    required double horas,
    required String texto,
  }) {
    _duracionMinutos = minutos;
    _horasDecimales = horas;
    _duracionTexto = texto;
    return this;
  }

  RegistroTrabajoBuilder withExplicitDesbloqueo(DateTime nuevoDesbloqueo) {
    _nuevoDesbloqueo = nuevoDesbloqueo;
    return this;
  }

  RegistroTrabajoBuilder withObservaciones(String? observaciones) {
    _observaciones = observaciones;
    return this;
  }

  RegistroTrabajoBuilder withCreadoEn(DateTime creadoEn) {
    _creadoEn = creadoEn;
    return this;
  }

  RegistroTrabajo build() {
    final duracionCalculada = TimeCalculator.calcularHorasTrabajadas(_inicio, _fin);
    final desbloqueoCalculado = TimeCalculator.calcularProximoDesbloqueo(_inicio);

    return RegistroTrabajo(
      id: _id,
      loteId: _loteId,
      supermercado: _supermercado,
      area: _area,
      cantidadProductos: _cantidadProductos,
      inicio: _inicio,
      fin: _fin,
      duracionMinutos: _duracionMinutos ?? duracionCalculada.minutosTotales,
      horasDecimales: _horasDecimales ?? duracionCalculada.horasDecimales,
      duracionTexto: _duracionTexto ?? duracionCalculada.texto,
      nuevoDesbloqueo: _nuevoDesbloqueo ?? desbloqueoCalculado,
      observaciones: _observaciones,
      creadoEn: _creadoEn,
    );
  }
}
