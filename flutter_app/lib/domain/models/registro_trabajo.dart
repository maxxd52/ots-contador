import '../logic/time_calculator.dart';

class RegistroTrabajo {
  final String id;
  final String loteId;
  final String supermercado;
  final String area;
  final int cantidadProductos;
  final DateTime inicio;
  final DateTime fin;
  final int duracionMinutos;
  final double horasDecimales;
  final String duracionTexto;
  final DateTime nuevoDesbloqueo;
  final String? observaciones;
  final DateTime creadoEn;

  const RegistroTrabajo({
    required this.id,
    required this.loteId,
    required this.supermercado,
    required this.area,
    required this.cantidadProductos,
    required this.inicio,
    required this.fin,
    required this.duracionMinutos,
    required this.horasDecimales,
    required this.duracionTexto,
    required this.nuevoDesbloqueo,
    this.observaciones,
    required this.creadoEn,
  });

  factory RegistroTrabajo.crear({
    String? id,
    required String loteId,
    required String supermercado,
    required String area,
    int cantidadProductos = 0,
    required DateTime inicio,
    required DateTime fin,
    String? observaciones,
    DateTime? creadoEn,
  }) {
    if (fin.isBefore(inicio)) {
      throw ArgumentError('La fecha de fin no puede ser anterior a la de inicio.');
    }

    final now = creadoEn ?? DateTime.now();
    final duracion = TimeCalculator.calcularHorasTrabajadas(inicio, fin);
    final nuevoDesbloqueo = TimeCalculator.calcularProximoDesbloqueo(inicio);

    return RegistroTrabajo(
      id: id ?? 'reg_${now.millisecondsSinceEpoch}',
      loteId: loteId,
      supermercado: supermercado.trim(),
      area: area.trim(),
      cantidadProductos: cantidadProductos >= 0 ? cantidadProductos : 0,
      inicio: inicio,
      fin: fin,
      duracionMinutos: duracion.minutosTotales,
      horasDecimales: duracion.horasDecimales,
      duracionTexto: duracion.texto,
      nuevoDesbloqueo: nuevoDesbloqueo,
      observaciones: observaciones?.trim().isEmpty == true ? null : observaciones?.trim(),
      creadoEn: now,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loteId': loteId,
      'supermercado': supermercado,
      'area': area,
      'cantidadProductos': cantidadProductos,
      'inicio': inicio.toIso8601String(),
      'fin': fin.toIso8601String(),
      'duracionMinutos': duracionMinutos,
      'horasDecimales': horasDecimales,
      'duracionTexto': duracionTexto,
      'nuevoDesbloqueo': nuevoDesbloqueo.toIso8601String(),
      'observaciones': observaciones,
      'creadoEn': creadoEn.toIso8601String(),
    };
  }

  factory RegistroTrabajo.fromJson(Map<String, dynamic> json) {
    return RegistroTrabajo(
      id: json['id'] as String,
      loteId: json['loteId'] as String,
      supermercado: json['supermercado'] as String,
      area: json['area'] as String,
      cantidadProductos: (json['cantidadProductos'] as num?)?.toInt() ?? 0,
      inicio: DateTime.parse(json['inicio'] as String),
      fin: DateTime.parse(json['fin'] as String),
      duracionMinutos: (json['duracionMinutos'] as num).toInt(),
      horasDecimales: (json['horasDecimales'] as num).toDouble(),
      duracionTexto: json['duracionTexto'] as String,
      nuevoDesbloqueo: DateTime.parse(json['nuevoDesbloqueo'] as String),
      observaciones: json['observaciones'] as String?,
      creadoEn: json['creadoEn'] != null ? DateTime.parse(json['creadoEn'] as String) : DateTime.now(),
    );
  }
}
