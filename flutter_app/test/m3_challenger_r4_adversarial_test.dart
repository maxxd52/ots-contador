import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/logic/time_calculator.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/domain/models/estado_lote.dart';
import 'package:flutter_app/ui/views/modal_lote_sheet.dart';
import 'e2e/harness/widget_test_harness.dart';

/// Specification Oracle for Lote.copyWith:
/// Returns expected (nuevoUltimoInicio, nuevoProximoDesbloqueo) based on specification:
/// 1. nuevoUltimoInicio:
///    if resetUltimoInicio == true -> null
///    else -> ultimoInicio ?? base.ultimoInicio
/// 2. nuevoProximoDesbloqueo:
///    Branch 1: if resetDesbloqueo == true -> null
///    Branch 2: else if proximoDesbloqueo != null -> proximoDesbloqueo
///    Branch 3: else if resetUltimoInicio == true -> null
///    Branch 4: else if ultimoInicio != null -> TimeCalculator.calcularProximoDesbloqueo(ultimoInicio)
///    Branch 5: else -> base.proximoDesbloqueo
({DateTime? ultimoInicio, DateTime? proximoDesbloqueo}) _specOracle({
  required Lote base,
  DateTime? ultimoInicio,
  DateTime? proximoDesbloqueo,
  bool resetDesbloqueo = false,
  bool resetUltimoInicio = false,
}) {
  final DateTime? expectedUltimoInicio = resetUltimoInicio
      ? null
      : (ultimoInicio ?? base.ultimoInicio);

  final DateTime? expectedProximoDesbloqueo;
  if (resetDesbloqueo) {
    expectedProximoDesbloqueo = null;
  } else if (proximoDesbloqueo != null) {
    expectedProximoDesbloqueo = proximoDesbloqueo;
  } else if (resetUltimoInicio) {
    expectedProximoDesbloqueo = null;
  } else if (ultimoInicio != null) {
    expectedProximoDesbloqueo = TimeCalculator.calcularProximoDesbloqueo(ultimoInicio);
  } else {
    expectedProximoDesbloqueo = base.proximoDesbloqueo;
  }

  return (
    ultimoInicio: expectedUltimoInicio,
    proximoDesbloqueo: expectedProximoDesbloqueo,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CHALLENGE 1: Fuzz & Property-Based Testing of Lote.copyWith 5-Branch Precedence', () {
    test('Empirical Fuzzing: 500 randomized combinations strictly match specification oracle', () {
      final random = Random(42); // Seeded for reproducibility

      final candidateDates = <DateTime?>[
        null,
        DateTime(2020, 2, 29, 10, 15, 30), // Leap year 2020
        DateTime(2024, 2, 29, 23, 59, 59), // Leap year 2024
        DateTime(2028, 2, 29, 12, 0, 0),   // Leap year 2028
        DateTime(2026, 12, 31, 23, 59, 59), // Year boundary
        DateTime(2026, 1, 1, 0, 0, 0),      // Year start
        DateTime(2023, 12, 31, 14, 0, 0),   // Transition into leap year 2024
        DateTime(2026, 11, 5, 8, 30),       // Standard operating date
        DateTime(2035, 6, 15, 9, 0),        // Future date
        DateTime(2019, 10, 20, 16, 45),     // Historical date
      ];

      for (int i = 0; i < 500; i++) {
        // Construct random base lote
        final baseInicio = candidateDates[random.nextInt(candidateDates.length)];
        final baseDesbloqueo = baseInicio != null && random.nextBool()
            ? TimeCalculator.calcularProximoDesbloqueo(baseInicio)
            : (random.nextBool() ? candidateDates[random.nextInt(candidateDates.length)] : null);

        final baseLote = Lote(
          id: 'lote_fuzz_$i',
          supermercado: 'Supermercado $i',
          area: 'Sector $i',
          cantidadProductos: random.nextInt(500),
          ultimoInicio: baseInicio,
          proximoDesbloqueo: baseDesbloqueo,
          creadoEn: DateTime(2026, 1, 1),
        );

        // Generate randomized input parameters for copyWith
        final hasArgUltimoInicio = random.nextBool();
        final argUltimoInicio = hasArgUltimoInicio
            ? candidateDates[random.nextInt(candidateDates.length)]
            : null;

        final hasArgProximoDesbloqueo = random.nextBool();
        final argProximoDesbloqueo = hasArgProximoDesbloqueo
            ? candidateDates[random.nextInt(candidateDates.length)]
            : null;

        final argResetDesbloqueo = random.nextBool();
        final argResetUltimoInicio = random.nextBool();

        // Calculate oracle expectation
        final oracle = _specOracle(
          base: baseLote,
          ultimoInicio: argUltimoInicio,
          proximoDesbloqueo: argProximoDesbloqueo,
          resetDesbloqueo: argResetDesbloqueo,
          resetUltimoInicio: argResetUltimoInicio,
        );

        // Execute actual copyWith
        final actual = baseLote.copyWith(
          ultimoInicio: argUltimoInicio,
          proximoDesbloqueo: argProximoDesbloqueo,
          resetDesbloqueo: argResetDesbloqueo,
          resetUltimoInicio: argResetUltimoInicio,
        );

        // Verify strictly matches oracle
        expect(
          actual.ultimoInicio,
          equals(oracle.ultimoInicio),
          reason: 'Iteration $i: ultimoInicio mismatch against oracle.',
        );
        expect(
          actual.proximoDesbloqueo,
          equals(oracle.proximoDesbloqueo),
          reason: 'Iteration $i: proximoDesbloqueo mismatch against oracle.',
        );

        // Verify JSON roundtrip consistency
        final json = actual.toJson();
        final reconstructed = Lote.fromJson(json);
        expect(reconstructed.id, equals(actual.id));
        expect(reconstructed.supermercado, equals(actual.supermercado));
        expect(reconstructed.ultimoInicio, equals(actual.ultimoInicio));
        expect(reconstructed.proximoDesbloqueo, equals(actual.proximoDesbloqueo));
      }
    });

    test('Systematic Truth Table: All 16 combinations of precedence flags verify explicit priorities', () {
      final baseDate = DateTime(2026, 11, 5, 10, 0);
      final baseDesbloqueo = TimeCalculator.calcularProximoDesbloqueo(baseDate);

      final base = Lote(
        id: 'base_truth_table',
        supermercado: 'Coto',
        area: 'Almacén',
        ultimoInicio: baseDate,
        proximoDesbloqueo: baseDesbloqueo,
        creadoEn: DateTime(2026, 1, 1),
      );

      final overrideDate = DateTime(2026, 12, 1, 15, 0);
      final explicitDesbloqueo = DateTime(2027, 8, 1, 12, 0);

      final flags = [false, true];

      for (final rDesbloqueo in flags) {
        for (final rUltimoInicio in flags) {
          for (final passUltimoInicio in flags) {
            for (final passProximoDesbloqueo in flags) {
              final argUltimoInicio = passUltimoInicio ? overrideDate : null;
              final argProximoDesbloqueo = passProximoDesbloqueo ? explicitDesbloqueo : null;

              final oracle = _specOracle(
                base: base,
                ultimoInicio: argUltimoInicio,
                proximoDesbloqueo: argProximoDesbloqueo,
                resetDesbloqueo: rDesbloqueo,
                resetUltimoInicio: rUltimoInicio,
              );

              final result = base.copyWith(
                ultimoInicio: argUltimoInicio,
                proximoDesbloqueo: argProximoDesbloqueo,
                resetDesbloqueo: rDesbloqueo,
                resetUltimoInicio: rUltimoInicio,
              );

              expect(
                result.ultimoInicio,
                equals(oracle.ultimoInicio),
                reason: 'Failed truth table combination: rDesbloqueo=$rDesbloqueo, '
                    'rUltimoInicio=$rUltimoInicio, passUltimoInicio=$passUltimoInicio, '
                    'passProximoDesbloqueo=$passProximoDesbloqueo',
              );
              expect(
                result.proximoDesbloqueo,
                equals(oracle.proximoDesbloqueo),
                reason: 'Failed truth table combination: rDesbloqueo=$rDesbloqueo, '
                    'rUltimoInicio=$rUltimoInicio, passUltimoInicio=$passUltimoInicio, '
                    'passProximoDesbloqueo=$passProximoDesbloqueo',
              );
            }
          }
        }
      }
    });

    test('Precedence Branch 1 (resetDesbloqueo == true) overrides explicit proximoDesbloqueo and ultimoInicio', () {
      final base = Lote.crear(
        supermercado: 'Carrefour',
        area: 'Bebidas',
        ultimoInicio: DateTime(2026, 11, 5),
      );

      final result = base.copyWith(
        resetDesbloqueo: true,
        proximoDesbloqueo: DateTime(2027, 5, 1), // Explicit date passed
        ultimoInicio: DateTime(2026, 12, 1),     // New start date passed
      );

      expect(result.ultimoInicio, equals(DateTime(2026, 12, 1)));
      expect(result.proximoDesbloqueo, isNull, reason: 'resetDesbloqueo must have absolute priority over proximoDesbloqueo and ultimoInicio');
    });

    test('Precedence Branch 2 (explicit proximoDesbloqueo) overrides branch 3, 4 and 5', () {
      final base = Lote.crear(
        supermercado: 'Dia',
        area: 'Carnicería',
        ultimoInicio: DateTime(2026, 11, 5),
      );

      final explicitUnlock = DateTime(2027, 9, 20, 18, 0);

      // Explicit proximoDesbloqueo with resetUltimoInicio: true
      final result1 = base.copyWith(
        proximoDesbloqueo: explicitUnlock,
        resetUltimoInicio: true,
      );
      expect(result1.ultimoInicio, isNull);
      expect(result1.proximoDesbloqueo, equals(explicitUnlock));

      // Explicit proximoDesbloqueo with new ultimoInicio
      final result2 = base.copyWith(
        ultimoInicio: DateTime(2026, 12, 15),
        proximoDesbloqueo: explicitUnlock,
      );
      expect(result2.ultimoInicio, equals(DateTime(2026, 12, 15)));
      expect(result2.proximoDesbloqueo, equals(explicitUnlock));
    });

    test('Precedence Branch 3 (resetUltimoInicio == true) clears both dates when proximoDesbloqueo is not provided', () {
      final base = Lote.crear(
        supermercado: 'Disco',
        area: 'Verdulería',
        ultimoInicio: DateTime(2026, 11, 5),
      );

      final result = base.copyWith(resetUltimoInicio: true);
      expect(result.ultimoInicio, isNull);
      expect(result.proximoDesbloqueo, isNull);
    });

    test('Precedence Branch 4 (ultimoInicio != null) recalculates proximoDesbloqueo to exactly +120 days', () {
      final base = Lote.crear(
        supermercado: 'Jumbo',
        area: 'Perfumería',
        ultimoInicio: DateTime(2026, 11, 5, 10, 0),
      );

      final nuevoInicio = DateTime(2026, 12, 1, 16, 30);
      final result = base.copyWith(ultimoInicio: nuevoInicio);

      expect(result.ultimoInicio, equals(nuevoInicio));
      expect(result.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(nuevoInicio)));
      expect(result.proximoDesbloqueo!.difference(nuevoInicio).inDays, equals(120));
    });

    test('Precedence Branch 5 (no date args) preserves existing dates identically', () {
      final base = Lote.crear(
        supermercado: 'Makro',
        area: 'Bazar',
        cantidadProductos: 50,
        ultimoInicio: DateTime(2026, 11, 5, 10, 0),
      );

      final result = base.copyWith(
        supermercado: 'Makro San Justo',
        cantidadProductos: 75,
        notas: 'Nuevas notas',
      );

      expect(result.supermercado, equals('Makro San Justo'));
      expect(result.cantidadProductos, equals(75));
      expect(result.ultimoInicio, equals(base.ultimoInicio));
      expect(result.proximoDesbloqueo, equals(base.proximoDesbloqueo));
    });

    test('Zero-argument copyWith is strictly idempotent', () {
      final base = Lote.crear(
        id: 'lote_idempotent',
        supermercado: 'Vea',
        area: 'Panadería',
        cantidadProductos: 35,
        ultimoInicio: DateTime(2026, 11, 5, 8, 0),
        notas: 'Nota prueba',
      );

      final clone = base.copyWith();

      expect(clone.id, equals(base.id));
      expect(clone.supermercado, equals(base.supermercado));
      expect(clone.area, equals(base.area));
      expect(clone.cantidadProductos, equals(base.cantidadProductos));
      expect(clone.ultimoInicio, equals(base.ultimoInicio));
      expect(clone.proximoDesbloqueo, equals(base.proximoDesbloqueo));
      expect(clone.notas, equals(base.notas));
      expect(clone.creadoEn, equals(base.creadoEn));
    });
  });

  group('CHALLENGE 2: Edge Dates, Leap Years & Temporal Boundary Stress', () {
    test('Leap Day 2024-02-29 adds exactly 120 days reaching 2024-06-28 without throwing', () {
      final leapDay = DateTime(2024, 2, 29, 14, 30, 45);
      final lote = Lote.crear(
        supermercado: 'Super Bisiesto',
        area: 'Congelados',
        ultimoInicio: leapDay,
      );

      expect(lote.proximoDesbloqueo, isNotNull);
      // 2024 is a leap year (Feb 29 exists):
      // March: 31 days, April: 30 days, May: 31 days -> 92 days
      // 120 - 92 = 28 days -> June 28, 2024
      expect(lote.proximoDesbloqueo!.year, equals(2024));
      expect(lote.proximoDesbloqueo!.month, equals(6));
      expect(lote.proximoDesbloqueo!.day, equals(28));
      expect(lote.proximoDesbloqueo!.hour, equals(14));
      expect(lote.proximoDesbloqueo!.minute, equals(30));
      expect(lote.proximoDesbloqueo!.second, equals(45));
    });

    test('Leap Day 2028-02-29 and 2020-02-29 verify multi-leap cycle consistency', () {
      for (final leapYear in [2020, 2024, 2028]) {
        final start = DateTime(leapYear, 2, 29, 10, 0);
        final lote = Lote.crear(supermercado: 'Super $leapYear', area: 'Rotisería').copyWith(
          ultimoInicio: start,
        );

        expect(lote.proximoDesbloqueo!.year, equals(leapYear));
        expect(lote.proximoDesbloqueo!.month, equals(6));
        expect(lote.proximoDesbloqueo!.day, equals(28));
      }
    });

    test('Leap Year Transition: 2023-12-31 traversing February 2024 leap day reaches 2024-04-29', () {
      final start = DateTime(2023, 12, 31, 12, 0);
      final lote = Lote.crear(supermercado: 'Coto Fin de Año', area: 'Fiestas', ultimoInicio: start);

      // Dec 31 has 0 days left in Dec
      // Jan 2024: 31 days
      // Feb 2024 (Leap): 29 days (31 + 29 = 60)
      // Mar 2024: 31 days (60 + 31 = 91)
      // Apr 2024: 120 - 91 = 29 days -> April 29, 2024!
      expect(lote.proximoDesbloqueo!.year, equals(2024));
      expect(lote.proximoDesbloqueo!.month, equals(4));
      expect(lote.proximoDesbloqueo!.day, equals(29));
      expect(lote.proximoDesbloqueo!.difference(start).inDays, equals(120));
    });

    test('Year Boundary: 2026-12-31 23:59:59.999 transitions smoothly to 2027-04-30 23:59:59.999', () {
      final boundaryDate = DateTime(2026, 12, 31, 23, 59, 59, 999);
      final lote = Lote.crear(supermercado: 'Año Nuevo', area: 'Bebidas').copyWith(
        ultimoInicio: boundaryDate,
      );

      // Dec 31 has 0 days left
      // Jan 2027: 31 days
      // Feb 2027 (Non-leap): 28 days (31 + 28 = 59)
      // Mar 2027: 31 days (59 + 31 = 90)
      // Apr 2027: 120 - 90 = 30 days -> April 30, 2027
      expect(lote.proximoDesbloqueo!.year, equals(2027));
      expect(lote.proximoDesbloqueo!.month, equals(4));
      expect(lote.proximoDesbloqueo!.day, equals(30));
      expect(lote.proximoDesbloqueo!.hour, equals(23));
      expect(lote.proximoDesbloqueo!.minute, equals(59));
      expect(lote.proximoDesbloqueo!.second, equals(59));
      expect(lote.proximoDesbloqueo!.millisecond, equals(999));
    });

    test('Chained copyWith updates ensure no stale unlock dates persist across successive edits', () {
      final d1 = DateTime(2026, 1, 10, 8, 0);
      final d2 = DateTime(2026, 5, 20, 11, 0);
      final d3 = DateTime(2026, 9, 15, 16, 0);

      var lote = Lote.crear(supermercado: 'Super Chain', area: 'Frescos', ultimoInicio: d1);
      expect(lote.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(d1)));

      lote = lote.copyWith(ultimoInicio: d2);
      expect(lote.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(d2)));

      lote = lote.copyWith(ultimoInicio: d3);
      expect(lote.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(d3)));

      // Now clear date
      lote = lote.copyWith(resetUltimoInicio: true);
      expect(lote.ultimoInicio, isNull);
      expect(lote.proximoDesbloqueo, isNull);

      // Re-assign date
      lote = lote.copyWith(ultimoInicio: d1);
      expect(lote.ultimoInicio, equals(d1));
      expect(lote.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(d1)));
    });

    test('Classification of estado lote on edge and leap dates', () {
      final leapDate = DateTime(2024, 2, 29, 10, 0);
      final desbloqueo = TimeCalculator.calcularProximoDesbloqueo(leapDate); // 2024-06-28

      // When 'ahora' is before unlock date (> 7 days) -> Futuro
      final estadoFuturo = TimeCalculator.clasificarEstadoLote(
        proximoDesbloqueo: desbloqueo,
        ahora: DateTime(2024, 3, 15),
      );
      expect(estadoFuturo.tipo, equals(TipoEstadoLote.futuro));

      // When 'ahora' is 3 days before unlock date -> proximo7Dias
      final estado7d = TimeCalculator.clasificarEstadoLote(
        proximoDesbloqueo: desbloqueo,
        ahora: DateTime(2024, 6, 25, 10, 0),
      );
      expect(estado7d.tipo, equals(TipoEstadoLote.proximo7Dias));
      expect(estado7d.diasFaltantes, equals(3));

      // When 'ahora' is on the exact unlock day -> Habilitado (Listo hoy)
      final estadoListo = TimeCalculator.clasificarEstadoLote(
        proximoDesbloqueo: desbloqueo,
        ahora: DateTime(2024, 6, 28, 12, 0),
      );
      expect(estadoListo.tipo, equals(TipoEstadoLote.habilitado));
      expect(estadoListo.esAcumulado, isFalse);

      // When 'ahora' is past unlock day -> Habilitado (Acumulado)
      final estadoAcumulado = TimeCalculator.clasificarEstadoLote(
        proximoDesbloqueo: desbloqueo,
        ahora: DateTime(2024, 7, 5),
      );
      expect(estadoAcumulado.tipo, equals(TipoEstadoLote.habilitado));
      expect(estadoAcumulado.esAcumulado, isTrue);
    });
  });

  group('CHALLENGE 3: ModalLoteSheet UI Adversarial & Integration Verification', () {
    testWidgets('ModalLoteSheet preserves leap day date and unlocks accurately on save', (tester) async {
      final leapDay = DateTime(2024, 2, 29, 11, 45);
      final loteInicial = Lote.crear(
        id: 'lote_leap_ui',
        supermercado: 'Jumbo Bisiesto',
        area: 'Bazar',
        cantidadProductos: 120,
        ultimoInicio: leapDay,
      );

      Lote? guardado;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          loteParaEditar: loteInicial,
          onGuardar: (l) => guardado = l,
        ),
      );

      // Tap Guardar Cambios
      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(guardado, isNotNull);
      expect(guardado!.ultimoInicio, equals(leapDay));
      expect(guardado!.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(leapDay)));
      expect(guardado!.proximoDesbloqueo!.day, equals(28));
      expect(guardado!.proximoDesbloqueo!.month, equals(6));
      expect(guardado!.proximoDesbloqueo!.year, equals(2024));
    });

    testWidgets('ModalLoteSheet clearing date via Icons.clear updates UI preview and saves null dates', (tester) async {
      final loteInicial = Lote.crear(
        id: 'lote_clear_test',
        supermercado: 'Dia Express',
        area: 'Panadería',
        ultimoInicio: DateTime(2026, 11, 5, 14, 0),
      );

      Lote? guardado;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          loteParaEditar: loteInicial,
          onGuardar: (l) => guardado = l,
        ),
      );

      // Verify clear icon is present
      final clearFinder = find.byIcon(Icons.clear);
      expect(clearFinder, findsOneWidget);

      // Tap clear icon
      await tester.tap(clearFinder);
      await tester.pumpAndSettle();

      // Verify UI text changed to indicate lot is enabled immediately
      expect(
        find.text('Sin fotos previas (quedará habilitado de inmediato)'),
        findsOneWidget,
      );

      // Clear icon must disappear once date is null
      expect(find.byIcon(Icons.clear), findsNothing);

      // Save changes
      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(guardado, isNotNull);
      expect(guardado!.ultimoInicio, isNull);
      expect(guardado!.proximoDesbloqueo, isNull);
    });

    testWidgets('ModalLoteSheet blocks save with SnackBar when required fields are whitespace only', (tester) async {
      bool onGuardarCalled = false;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          onGuardar: (_) => onGuardarCalled = true,
        ),
      );

      // Enter spaces into supermarket and area
      await tester.enterText(find.widgetWithText(TextField, 'Ej: Carrefour San Martín'), '     ');
      await tester.enterText(find.widgetWithText(TextField, 'Ej: Lácteos'), '   ');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear Lote'));
      await tester.pumpAndSettle();

      expect(onGuardarCalled, isFalse);
      expect(find.text('Supermercado y Área son obligatorios.'), findsOneWidget);
    });

    testWidgets('ModalLoteSheet sanitizes whitespace, unicode characters and invalid product counts', (tester) async {
      Lote? guardado;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          onGuardar: (l) => guardado = l,
        ),
      );

      // Enter padded names with unicode / emoji
      await tester.enterText(find.widgetWithText(TextField, 'Ej: Carrefour San Martín'), '   Super Coto 🛒   ');
      await tester.enterText(find.widgetWithText(TextField, 'Ej: Lácteos'), '   Frutería 🍎   ');
      await tester.enterText(find.widgetWithText(TextField, '100'), 'not_a_number');
      await tester.enterText(find.widgetWithText(TextField, 'Ej: Góndola 3, pasillo central'), '   Pasillo 4   ');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear Lote'));
      await tester.pumpAndSettle();

      expect(guardado, isNotNull);
      expect(guardado!.supermercado, equals('Super Coto 🛒'));
      expect(guardado!.area, equals('Frutería 🍎'));
      expect(guardado!.cantidadProductos, equals(0)); // non-number fallback to 0
      expect(guardado!.notas, equals('Pasillo 4'));
      expect(guardado!.ultimoInicio, isNull);
      expect(guardado!.proximoDesbloqueo, isNull);
    });

    testWidgets('ModalLoteSheet editing preserves notes and calculates unlock for year boundary date', (tester) async {
      final boundaryDate = DateTime(2026, 12, 31, 23, 59);
      final lote = Lote.crear(
        id: 'lote_boundary_ui',
        supermercado: 'Carrefour Express',
        area: 'Góndolas',
        cantidadProductos: 45,
        ultimoInicio: boundaryDate,
        notas: 'Notas importantes de inventario',
      );

      Lote? guardado;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          loteParaEditar: lote,
          onGuardar: (l) => guardado = l,
        ),
      );

      // Verify initial fields populated
      expect(find.text('Carrefour Express'), findsOneWidget);
      expect(find.text('Góndolas'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('Notas importantes de inventario'), findsOneWidget);

      // Update area
      await tester.enterText(find.widgetWithText(TextField, 'Góndolas'), 'Carnicería Premium');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(guardado, isNotNull);
      expect(guardado!.area, equals('Carnicería Premium'));
      expect(guardado!.ultimoInicio, equals(boundaryDate));
      expect(guardado!.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(boundaryDate)));
      expect(guardado!.proximoDesbloqueo!.year, equals(2027));
      expect(guardado!.proximoDesbloqueo!.month, equals(4));
      expect(guardado!.proximoDesbloqueo!.day, equals(30));
    });

    testWidgets('ModalLoteSheet date picker cancellation preserves previous date state', (tester) async {
      final initialDate = DateTime(2026, 8, 15, 10, 0);
      final lote = Lote.crear(
        id: 'lote_cancel_picker',
        supermercado: 'Jumbo Almagro',
        area: 'Lácteos',
        ultimoInicio: initialDate,
      );

      Lote? guardado;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          loteParaEditar: lote,
          onGuardar: (l) => guardado = l,
        ),
      );

      // Tap on the InkWell that triggers _seleccionarFechaInicio
      final inkWellFinder = find.widgetWithText(InkWell, 'Última Fecha/Hora de Fotos (Opcional)');
      expect(inkWellFinder, findsOneWidget);
      await tester.tap(inkWellFinder);
      await tester.pumpAndSettle();

      // Check if DatePickerDialog is visible
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Save changes
      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(guardado, isNotNull);
      expect(guardado!.ultimoInicio, equals(initialDate));
      expect(guardado!.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(initialDate)));
    });

    testWidgets('Interactive DatePicker and TimePicker flow selects new date and synchronizes proximoDesbloqueo', (tester) async {
      Lote? guardado;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          onGuardar: (l) => guardado = l,
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Ej: Carrefour San Martín'), 'Vea Caballito');
      await tester.enterText(find.widgetWithText(TextField, 'Ej: Lácteos'), 'Bebidas');
      await tester.pumpAndSettle();

      // Tap to open DatePicker via InkWell
      final inkWellFinder = find.widgetWithText(InkWell, 'Última Fecha/Hora de Fotos (Opcional)');
      expect(inkWellFinder, findsOneWidget);
      await tester.tap(inkWellFinder);
      await tester.pumpAndSettle();

      // Confirm DatePicker with 'OK'
      final okDateFinder = find.text('OK');
      expect(okDateFinder, findsOneWidget);
      await tester.tap(okDateFinder);
      await tester.pumpAndSettle();

      // TimePicker dialog should now be visible
      final okTimeFinder = find.text('OK');
      expect(okTimeFinder, findsOneWidget);
      await tester.tap(okTimeFinder);
      await tester.pumpAndSettle();

      // Save new lot
      await tester.tap(find.text('Crear Lote'));
      await tester.pumpAndSettle();

      expect(guardado, isNotNull);
      expect(guardado!.ultimoInicio, isNotNull);
      expect(guardado!.proximoDesbloqueo, isNotNull);
      expect(
        guardado!.proximoDesbloqueo,
        equals(TimeCalculator.calcularProximoDesbloqueo(guardado!.ultimoInicio!)),
      );
      expect(
        guardado!.proximoDesbloqueo!.difference(guardado!.ultimoInicio!).inDays,
        equals(120),
      );
    });
  });

  group('CHALLENGE 4: Time Zone, DST & UTC Boundary Fuzzing', () {
    test('UTC Timestamps around international DST shifts preserve 120-day duration exactly', () {
      // European DST shift dates in 2024 (March 31 and October 27)
      final dstDates = [
        DateTime.utc(2024, 3, 31, 1, 0), // European spring forward
        DateTime.utc(2024, 10, 27, 1, 0), // European fall back
        DateTime.utc(2024, 3, 10, 2, 0),  // US spring forward
        DateTime.utc(2024, 11, 3, 2, 0),  // US fall back
      ];

      for (final utcDate in dstDates) {
        final lote = Lote.crear(
          supermercado: 'Super UTC',
          area: 'Internacional',
          ultimoInicio: utcDate,
        );

        expect(lote.proximoDesbloqueo, isNotNull);
        expect(lote.proximoDesbloqueo!.isUtc, isTrue);
        expect(lote.proximoDesbloqueo!.difference(utcDate).inDays, equals(120));

        // Serialization must preserve ISO8601 UTC format
        final json = lote.toJson();
        expect((json['ultimoInicio'] as String).endsWith('Z'), isTrue);
        expect((json['proximoDesbloqueo'] as String).endsWith('Z'), isTrue);

        final deserialized = Lote.fromJson(json);
        expect(deserialized.ultimoInicio!.isUtc, isTrue);
        expect(deserialized.proximoDesbloqueo!.isUtc, isTrue);
        expect(deserialized.ultimoInicio, equals(utcDate));
        expect(deserialized.proximoDesbloqueo, equals(lote.proximoDesbloqueo));
      }
    });

    test('Lote.crear input contract enforcement', () {
      expect(
        () => Lote.crear(supermercado: '', area: 'Área'),
        throwsArgumentError,
      );
      expect(
        () => Lote.crear(supermercado: '   ', area: 'Área'),
        throwsArgumentError,
      );
      expect(
        () => Lote.crear(supermercado: 'Super', area: ''),
        throwsArgumentError,
      );
      expect(
        () => Lote.crear(supermercado: 'Super', area: '   '),
        throwsArgumentError,
      );

      // Negative quantity clamped to 0
      final loteNeg = Lote.crear(
        supermercado: 'Super',
        area: 'Área',
        cantidadProductos: -99,
      );
      expect(loteNeg.cantidadProductos, equals(0));
    });
  });
}
