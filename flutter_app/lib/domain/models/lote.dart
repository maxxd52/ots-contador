import '../logic/time_calculator.dart';

class Lote {
  final String id;
  final String supermercado;
  final String area;
  final int cantidadProductos;
  final DateTime? ultimoInicio;
  final DateTime? proximoDesbloqueo;
  final String? notas;
  final DateTime creadoEn;

  const Lote({
    required this.id,
    required this.supermercado,
    required this.area,
    this.cantidadProductos = 0,
    this.ultimoInicio,
    this.proximoDesbloqueo,
    this.notas,
    required this.creadoEn,
  });

  factory Lote.crear({
    String? id,
    required String supermercado,
    required String area,
    int cantidadProductos = 0,
    DateTime? ultimoInicio,
    String? notas,
    DateTime? creadoEn,
  }) {
    final now = creadoEn ?? DateTime.now();
    final cleanSuper = supermercado.trim();
    final cleanArea = area.trim();

    if (cleanSuper.isEmpty) {
      throw ArgumentError('El nombre del supermercado es obligatorio.');
    }
    if (cleanArea.isEmpty) {
      throw ArgumentError('El área o sector es obligatorio.');
    }

    DateTime? calcDesbloqueo;
    if (ultimoInicio != null) {
      calcDesbloqueo = TimeCalculator.calcularProximoDesbloqueo(ultimoInicio);
    }

    return Lote(
      id: id ?? 'lote_${now.millisecondsSinceEpoch}_${cleanSuper.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
      supermercado: cleanSuper,
      area: cleanArea,
      cantidadProductos: cantidadProductos >= 0 ? cantidadProductos : 0,
      ultimoInicio: ultimoInicio,
      proximoDesbloqueo: calcDesbloqueo,
      notas: notas?.trim().isEmpty == true ? null : notas?.trim(),
      creadoEn: now,
    );
  }

  Lote copyWith({
    String? id,
    String? supermercado,
    String? area,
    int? cantidadProductos,
    DateTime? ultimoInicio,
    DateTime? proximoDesbloqueo,
    bool resetDesbloqueo = false,
    bool resetUltimoInicio = false,
    String? notas,
    DateTime? creadoEn,
  }) {
    return Lote(
      id: id ?? this.id,
      supermercado: supermercado ?? this.supermercado,
      area: area ?? this.area,
      cantidadProductos: cantidadProductos ?? this.cantidadProductos,
      ultimoInicio: resetUltimoInicio ? null : (ultimoInicio ?? this.ultimoInicio),
      proximoDesbloqueo: resetDesbloqueo ? null : (proximoDesbloqueo ?? this.proximoDesbloqueo),
      notas: notas ?? this.notas,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supermercado': supermercado,
      'area': area,
      'cantidadProductos': cantidadProductos,
      'ultimoInicio': ultimoInicio?.toIso8601String(),
      'proximoDesbloqueo': proximoDesbloqueo?.toIso8601String(),
      'notas': notas,
      'creadoEn': creadoEn.toIso8601String(),
    };
  }

  factory Lote.fromJson(Map<String, dynamic> json) {
    return Lote(
      id: json['id'] as String,
      supermercado: json['supermercado'] as String,
      area: json['area'] as String,
      cantidadProductos: (json['cantidadProductos'] as num?)?.toInt() ?? 0,
      ultimoInicio: json['ultimoInicio'] != null ? DateTime.parse(json['ultimoInicio'] as String) : null,
      proximoDesbloqueo: json['proximoDesbloqueo'] != null ? DateTime.parse(json['proximoDesbloqueo'] as String) : null,
      notas: json['notas'] as String?,
      creadoEn: json['creadoEn'] != null ? DateTime.parse(json['creadoEn'] as String) : DateTime.now(),
    );
  }
}
