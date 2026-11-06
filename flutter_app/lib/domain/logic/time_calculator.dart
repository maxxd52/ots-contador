import '../models/estado_lote.dart';

class DuracionTrabajada {
  final int minutosTotales;
  final int horas;
  final int minutos;
  final double horasDecimales;
  final String texto;

  const DuracionTrabajada({
    required this.minutosTotales,
    required this.horas,
    required this.minutos,
    required this.horasDecimales,
    required this.texto,
  });
}

abstract class TimeCalculator {
  static const int diasCicloDesbloqueo = 120;
  static const int msPorDia = 24 * 60 * 60 * 1000;

  /// Suma exactamente 120 días calendario (120 * 86.400.000 ms) preservando la hora exacta.
  static DateTime calcularProximoDesbloqueo(DateTime fechaHoraInicio, [int dias = diasCicloDesbloqueo]) {
    return fechaHoraInicio.add(Duration(days: dias));
  }

  /// Calcula la duración entre inicio y fin con desglose en minutos, horas y texto formateado.
  static DuracionTrabajada calcularHorasTrabajadas(DateTime inicio, DateTime fin) {
    int diffMs = fin.difference(inicio).inMilliseconds;
    if (diffMs < 0) diffMs = 0;

    final minutosTotales = diffMs ~/ 60000;
    final horas = minutosTotales ~/ 60;
    final minutos = minutosTotales % 60;
    final horasDecimales = double.parse((minutosTotales / 60.0).toStringAsFixed(2));

    return DuracionTrabajada(
      minutosTotales: minutosTotales,
      horas: horas,
      minutos: minutos,
      horasDecimales: horasDecimales,
      texto: '${horas}h ${minutos}m',
    );
  }

  /// Clasifica el lote según el estado temporal frente a la fecha de corte [ahora].
  static EstadoLoteInfo clasificarEstadoLote({
    DateTime? proximoDesbloqueo,
    bool esSesionActiva = false,
    DateTime? ahora,
  }) {
    final ref = ahora ?? DateTime.now();

    if (esSesionActiva) {
      return const EstadoLoteInfo(
        tipo: TipoEstadoLote.enCurso,
        etiqueta: 'EN CURSO',
        descripcion: 'Sesión fotográfica activa en este momento.',
      );
    }

    if (proximoDesbloqueo == null) {
      return const EstadoLoteInfo(
        tipo: TipoEstadoLote.habilitado,
        etiqueta: 'LISTO',
        descripcion: 'Listo para fotografiar (nuevo lote sin registro previo).',
      );
    }

    final diffMs = proximoDesbloqueo.difference(ref).inMilliseconds;

    // Si ya venció o vence exactamente en este instante
    if (diffMs <= 0) {
      final inicioHoy = DateTime(ref.year, ref.month, ref.day);
      final inicioDesbloqueo = DateTime(
        proximoDesbloqueo.year,
        proximoDesbloqueo.month,
        proximoDesbloqueo.day,
      );
      final esAcumulado = inicioDesbloqueo.isBefore(inicioHoy);

      return EstadoLoteInfo(
        tipo: TipoEstadoLote.habilitado,
        esAcumulado: esAcumulado,
        etiqueta: esAcumulado ? 'ACUMULADO' : 'LISTO HOY',
        descripcion: esAcumulado
            ? 'Habilitado en días anteriores / fin de semana acumulado.'
            : 'Desbloqueado hoy listo para fotografiar.',
      );
    }

    final diffDias = diffMs / msPorDia;
    final faltanDias = diffMs ~/ msPorDia;
    final faltanHoras = (diffMs % msPorDia) ~/ (60 * 60 * 1000);

    if (diffDias <= 7.0) {
      return EstadoLoteInfo(
        tipo: TipoEstadoLote.proximo7Dias,
        etiqueta: 'PRÓXIMO 7D',
        descripcion: 'Se habilitará dentro del itinerario de los próximos 7 días.',
        diasFaltantes: faltanDias,
        horasFaltantes: faltanHoras,
      );
    }

    return EstadoLoteInfo(
      tipo: TipoEstadoLote.futuro,
      etiqueta: 'FUTURO',
      descripcion: 'Habilitación programada a más de 7 días.',
      diasFaltantes: faltanDias,
      horasFaltantes: faltanHoras,
    );
  }

  /// Formatea segundos a formato MM:SS o HH:MM:SS
  static String formatearCronometro(int segundosTotales) {
    if (segundosTotales < 0) segundosTotales = 0;
    final horas = segundosTotales ~/ 3600;
    final minutos = (segundosTotales % 3600) ~/ 60;
    final segs = segundosTotales % 60;

    final mStr = minutos.toString().padLeft(2, '0');
    final sStr = segs.toString().padLeft(2, '0');

    if (horas > 0) {
      final hStr = horas.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }
}
