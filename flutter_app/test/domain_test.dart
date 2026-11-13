import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/logic/time_calculator.dart';
import 'package:flutter_app/domain/models/estado_lote.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/domain/models/registro_trabajo.dart';

void main() {
  group('TimeCalculator - Regla de 120 días y horas', () {
    test('calcularProximoDesbloqueo suma exactamente 120 días calendario y preserva hora exacta', () {
      final inicio = DateTime(2026, 11, 5, 14, 30);
      final desbloqueo = TimeCalculator.calcularProximoDesbloqueo(inicio);

      // 120 días desde el 5 de nov 2026:
      // nov tiene 25 días restantes, dic (31), ene (31), feb (28), mar (5) -> 25+31+31+28+5 = 120
      expect(desbloqueo.year, equals(2027));
      expect(desbloqueo.month, equals(3));
      expect(desbloqueo.day, equals(5));
      expect(desbloqueo.hour, equals(14));
      expect(desbloqueo.minute, equals(30));
    });

    test('calcularHorasTrabajadas calcula minutos, horas y formato legible', () {
      final inicio = DateTime(2026, 11, 5, 8, 0);
      final fin = DateTime(2026, 11, 5, 9, 45);

      final duracion = TimeCalculator.calcularHorasTrabajadas(inicio, fin);
      expect(duracion.minutosTotales, equals(105));
      expect(duracion.horas, equals(1));
      expect(duracion.minutos, equals(45));
      expect(duracion.horasDecimales, equals(1.75));
      expect(duracion.texto, equals('1h 45m'));
    });

    test('formatearCronometro formatea MM:SS y HH:MM:SS', () {
      expect(TimeCalculator.formatearCronometro(0), equals('00:00'));
      expect(TimeCalculator.formatearCronometro(65), equals('01:05'));
      expect(TimeCalculator.formatearCronometro(3665), equals('01:01:05'));
    });
  });

  group('TimeCalculator - Clasificación de Estados de Lote', () {
    test('Lote sin desbloqueo previo se marca como LISTO (Habilitado)', () {
      final estado = TimeCalculator.clasificarEstadoLote(
        proximoDesbloqueo: null,
        ahora: DateTime(2026, 11, 5, 10, 0),
      );
      expect(estado.tipo, equals(TipoEstadoLote.habilitado));
      expect(estado.esAcumulado, isFalse);
    });

    test('Lote desbloqueado hoy se marca como LISTO no acumulado', () {
      final ahora = DateTime(2026, 11, 5, 12, 0);
      final desbloqueo = DateTime(2026, 11, 5, 10, 0); // Desbloqueado hace 2 horas hoy
      final estado = TimeCalculator.clasificarEstadoLote(
        proximoDesbloqueo: desbloqueo,
        ahora: ahora,
      );
      expect(estado.tipo, equals(TipoEstadoLote.habilitado));
      expect(estado.esAcumulado, isFalse);
    });

    test('Lote desbloqueado hace 2 días se marca como ACUMULADO', () {
      final ahora = DateTime(2026, 11, 5, 12, 0);
      final desbloqueo = DateTime(2026, 11, 3, 10, 0); // Martes no trabajado
      final estado = TimeCalculator.clasificarEstadoLote(
        proximoDesbloqueo: desbloqueo,
        ahora: ahora,
      );
      expect(estado.tipo, equals(TipoEstadoLote.habilitado));
      expect(estado.esAcumulado, isTrue);
      expect(estado.etiqueta, equals('ACUMULADO'));
    });

    test('Lote con desbloqueo en 3 días entra en proximo7Dias', () {
      final ahora = DateTime(2026, 11, 5, 12, 0);
      final desbloqueo = DateTime(2026, 11, 8, 12, 0);
      final estado = TimeCalculator.clasificarEstadoLote(
        proximoDesbloqueo: desbloqueo,
        ahora: ahora,
      );
      expect(estado.tipo, equals(TipoEstadoLote.proximo7Dias));
      expect(estado.diasFaltantes, equals(3));
    });

    test('Lote con desbloqueo en 30 días entra en futuro', () {
      final ahora = DateTime(2026, 11, 5, 12, 0);
      final desbloqueo = DateTime(2026, 12, 5, 12, 0);
      final estado = TimeCalculator.clasificarEstadoLote(
        proximoDesbloqueo: desbloqueo,
        ahora: ahora,
      );
      expect(estado.tipo, equals(TipoEstadoLote.futuro));
      expect(estado.diasFaltantes, equals(30));
    });
  });

  group('Modelos Lote y RegistroTrabajo', () {
    test('Lote.crear valida campos requeridos y calcula proximoDesbloqueo', () {
      final inicio = DateTime(2026, 11, 5, 10, 0);
      final lote = Lote.crear(
        supermercado: 'Coto Belgrano',
        area: 'Perfumería',
        cantidadProductos: 140,
        ultimoInicio: inicio,
      );

      expect(lote.supermercado, equals('Coto Belgrano'));
      expect(lote.area, equals('Perfumería'));
      expect(lote.cantidadProductos, equals(140));
      expect(lote.proximoDesbloqueo, isNotNull);
      expect(lote.proximoDesbloqueo!.day, equals(5));
      expect(lote.proximoDesbloqueo!.month, equals(3));
      expect(lote.proximoDesbloqueo!.year, equals(2027));
    });

    test('RegistroTrabajo.crear calcula horas y nuevo desbloqueo', () {
      final inicio = DateTime(2026, 11, 5, 14, 0);
      final fin = DateTime(2026, 11, 5, 15, 30);
      final reg = RegistroTrabajo.crear(
        loteId: 'lote_1',
        supermercado: 'Jumbo Palermo',
        area: 'Lácteos',
        cantidadProductos: 95,
        inicio: inicio,
        fin: fin,
      );

      expect(reg.duracionMinutos, equals(90));
      expect(reg.horasDecimales, equals(1.5));
      expect(reg.duracionTexto, equals('1h 30m'));
      expect(reg.nuevoDesbloqueo.day, equals(5));
      expect(reg.nuevoDesbloqueo.month, equals(3));
      expect(reg.nuevoDesbloqueo.year, equals(2027));
    });
  });

  group('Lote.copyWith - Sincronización del ciclo de 120 días (R4)', () {
    test('Al modificar ultimoInicio sin especificar proximoDesbloqueo, se recalcula automáticamente a +120 días', () {
      final inicioOriginal = DateTime(2026, 11, 5, 10, 0);
      final loteOriginal = Lote.crear(
        id: 'lote_1',
        supermercado: 'Coto Belgrano',
        area: 'Perfumería',
        ultimoInicio: inicioOriginal,
      );

      // Desbloqueo original: 5 de marzo 2027
      expect(loteOriginal.proximoDesbloqueo, equals(DateTime(2027, 3, 5, 10, 0)));

      // Modificar ultimoInicio a 10 días después (15 de nov 2026)
      final nuevoInicio = DateTime(2026, 11, 15, 14, 0);
      final loteActualizado = loteOriginal.copyWith(ultimoInicio: nuevoInicio);

      expect(loteActualizado.ultimoInicio, equals(nuevoInicio));
      expect(loteActualizado.proximoDesbloqueo, isNotNull);
      // 120 días desde el 15 de nov 2026: 15 de marzo 2027
      expect(loteActualizado.proximoDesbloqueo!.year, equals(2027));
      expect(loteActualizado.proximoDesbloqueo!.month, equals(3));
      expect(loteActualizado.proximoDesbloqueo!.day, equals(15));
      expect(loteActualizado.proximoDesbloqueo!.hour, equals(14));
      expect(loteActualizado.proximoDesbloqueo!.minute, equals(0));
    });

    test('Respeta proximoDesbloqueo explícito cuando el llamador lo provee', () {
      final lote = Lote.crear(
        supermercado: 'Jumbo',
        area: 'Carnes',
        ultimoInicio: DateTime(2026, 11, 5),
      );

      final fechaPersonalizada = DateTime(2027, 6, 1, 12, 0);
      final actualizado = lote.copyWith(
        ultimoInicio: DateTime(2026, 12, 1),
        proximoDesbloqueo: fechaPersonalizada,
      );

      expect(actualizado.proximoDesbloqueo, equals(fechaPersonalizada));
    });

    test('resetUltimoInicio: true limpia tanto ultimoInicio como proximoDesbloqueo a null', () {
      final lote = Lote.crear(
        supermercado: 'Disco',
        area: 'Bebidas',
        ultimoInicio: DateTime(2026, 11, 5),
      );
      expect(lote.proximoDesbloqueo, isNotNull);

      final reseteado = lote.copyWith(resetUltimoInicio: true);
      expect(reseteado.ultimoInicio, isNull);
      expect(reseteado.proximoDesbloqueo, isNull);
    });

    test('resetDesbloqueo: true limpia proximoDesbloqueo a null preservando ultimoInicio', () {
      final fechaInicio = DateTime(2026, 11, 5);
      final lote = Lote.crear(
        supermercado: 'Disco',
        area: 'Bebidas',
        ultimoInicio: fechaInicio,
      );

      final actualizado = lote.copyWith(resetDesbloqueo: true);
      expect(actualizado.ultimoInicio, equals(fechaInicio));
      expect(actualizado.proximoDesbloqueo, isNull);
    });

    test('Modificar campos no relacionados (supermercado, cantidadProductos, notas) no altera fechas', () {
      final inicio = DateTime(2026, 11, 5, 10, 0);
      final lote = Lote.crear(
        supermercado: 'Carrefour',
        area: 'Limpieza',
        cantidadProductos: 50,
        ultimoInicio: inicio,
      );
      final desbloqueoOriginal = lote.proximoDesbloqueo;

      final actualizado = lote.copyWith(
        supermercado: 'Carrefour Express',
        cantidadProductos: 100,
        notas: 'Notas adicionales',
      );

      expect(actualizado.supermercado, equals('Carrefour Express'));
      expect(actualizado.cantidadProductos, equals(100));
      expect(actualizado.ultimoInicio, equals(inicio));
      expect(actualizado.proximoDesbloqueo, equals(desbloqueoOriginal));
    });

    test('Lote previamente sin fotos (habilitado) adquiere proximoDesbloqueo (+120 días) al recibir ultimoInicio', () {
      final loteHabilitado = Lote.crear(
        supermercado: 'Dia',
        area: 'Frescos',
      );
      expect(loteHabilitado.ultimoInicio, isNull);
      expect(loteHabilitado.proximoDesbloqueo, isNull);

      final nuevoInicio = DateTime(2026, 11, 20, 9, 30);
      final actualizado = loteHabilitado.copyWith(ultimoInicio: nuevoInicio);

      expect(actualizado.ultimoInicio, equals(nuevoInicio));
      expect(actualizado.proximoDesbloqueo, isNotNull);
      expect(actualizado.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(nuevoInicio)));
    });
  });
}
