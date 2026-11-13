import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/logic/time_calculator.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/ui/views/modal_lote_sheet.dart';
import '../harness/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockSharedPreferencesHelper.setEmpty();
  });

  group('Tier 2 - R4: Unlock Boundaries & Calendar Traversal', () {
    // TEST-R4-T2-01: Leap-year February 29 traversal calculates 120 days
    test('TEST-R4-T2-01: Leap-year February 29 traversal accounts for leap day in 120-day calculation', () {
      final leapStart = DateTime(2028, 2, 20, 10, 0);
      final leapLote = LoteBuilder()
          .withId('lote_leap_2028')
          .withUltimoInicio(leapStart, autoCalculateDesbloqueo: true)
          .build();

      // In 2028 (leap year), Feb has 29 days (9 remaining in Feb + 31 Mar + 30 Apr + 31 May + 19 Jun = 120)
      expect(leapLote.proximoDesbloqueo, equals(DateTime(2028, 6, 19, 10, 0)));
      expect(leapLote.proximoDesbloqueo!.difference(leapStart).inDays, equals(120));

      // In 2027 (non-leap year), Feb has 28 days -> June 20
      final nonLeapStart = DateTime(2027, 2, 20, 10, 0);
      final nonLeapLote = LoteBuilder()
          .withId('lote_non_leap_2027')
          .withUltimoInicio(nonLeapStart, autoCalculateDesbloqueo: true)
          .build();

      expect(nonLeapLote.proximoDesbloqueo, equals(DateTime(2027, 6, 20, 10, 0)));
      expect(nonLeapLote.proximoDesbloqueo!.difference(nonLeapStart).inDays, equals(120));
    });

    // TEST-R4-T2-02: Exact hour, minute, second preservation across 120d
    test('TEST-R4-T2-02: Exact hour, minute, second, and millisecond are preserved across 120 days', () {
      final start = DateTime(2026, 7, 15, 17, 42, 19, 850);
      final unlock = TimeCalculator.calcularProximoDesbloqueo(start);

      expect(unlock.year, equals(2026));
      expect(unlock.month, equals(11));
      expect(unlock.day, equals(12));
      expect(unlock.hour, equals(17));
      expect(unlock.minute, equals(42));
      expect(unlock.second, equals(19));
      expect(unlock.millisecond, equals(850));
      expect(unlock.difference(start).inDays, equals(120));
    });

    // TEST-R4-T2-03: Rapidly updating date back and forth in ModalLoteSheet
    testWidgets('TEST-R4-T2-03: Rapid date toggling in ModalLoteSheet isolates state to final selection', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Lote? savedLote;
      final initialDate = DateTime(2026, 5, 1, 10, 0);
      final initialLote = LoteBuilder()
          .withId('lote_toggle_03')
          .withSupermercado('Carrefour Norte')
          .withArea('Lácteos')
          .withUltimoInicio(initialDate, autoCalculateDesbloqueo: true)
          .build();

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          loteParaEditar: initialLote,
          onGuardar: (l) => savedLote = l,
        ),
      );

      final inkWellFinder = find.widgetWithText(InkWell, 'Última Fecha/Hora de Fotos (Opcional)');
      expect(inkWellFinder, findsOneWidget);

      // 1. First selection: select day 10
      await tester.tap(inkWellFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // Confirm DatePicker
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // Confirm TimePicker
      await tester.pumpAndSettle();

      // 2. Second selection: immediately change to day 25
      await tester.tap(inkWellFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('25'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // Confirm DatePicker
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // Confirm TimePicker
      await tester.pumpAndSettle();

      // 3. Submit and verify final state
      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      final expectedDate = DateTime(2026, 5, 25, 10, 0);
      expect(savedLote, isNotNull);
      expect(savedLote!.ultimoInicio, equals(expectedDate));
      expect(savedLote!.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(expectedDate)));
      expect(savedLote!.proximoDesbloqueo!.difference(expectedDate).inDays, equals(120));
    });

    // TEST-R4-T2-04: copyWith(resetDesbloqueo: true) overrides ultimoInicio
    test('TEST-R4-T2-04: copyWith with resetDesbloqueo: true overrides automatic unlock calculation', () {
      final initial = LoteBuilder.futuro(daysAhead: 60).build();
      final updated = initial.copyWith(
        ultimoInicio: DateTime(2026, 11, 1, 10, 0),
        resetDesbloqueo: true,
      );

      expect(updated.ultimoInicio, equals(DateTime(2026, 11, 1, 10, 0)));
      expect(updated.proximoDesbloqueo, isNull);
    });

    // TEST-R4-T2-05: copyWith with identical date maintains synchronization
    test('TEST-R4-T2-05: copyWith with identical date or non-date fields maintains exact synchronization', () {
      final initialDate = DateTime(2026, 10, 1, 10, 0);
      final initialLote = LoteBuilder()
          .withId('lote_idem_05')
          .withUltimoInicio(initialDate, autoCalculateDesbloqueo: true)
          .build();

      final updatedSameDate = initialLote.copyWith(ultimoInicio: initialDate);
      expect(updatedSameDate.proximoDesbloqueo, equals(initialLote.proximoDesbloqueo));

      final updatedNonDate = initialLote.copyWith(
        supermercado: 'Jumbo Nuevo',
        cantidadProductos: 99,
      );
      expect(updatedNonDate.proximoDesbloqueo, equals(initialLote.proximoDesbloqueo));
      expect(updatedNonDate.supermercado, equals('Jumbo Nuevo'));
      expect(updatedNonDate.cantidadProductos, equals(99));
    });
  });
}
