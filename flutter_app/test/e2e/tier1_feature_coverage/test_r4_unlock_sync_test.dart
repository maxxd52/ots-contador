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

  group('R4: Tier 1 - 120-Day Unlock Cycle Synchronization', () {
    test('TEST-R4-T1-01: Lote.copyWith auto-recalculates unlock date on ultimoInicio change', () {
      final initialDate = DateTime(2026, 10, 1, 10, 0);
      final initialLote = LoteBuilder()
          .withId('lote_sync_1')
          .withUltimoInicio(initialDate, autoCalculateDesbloqueo: true)
          .build();

      final newStartDate = DateTime(2026, 11, 15, 14, 30);
      final updatedLote = initialLote.copyWith(ultimoInicio: newStartDate);

      expect(updatedLote.ultimoInicio, equals(newStartDate));
      final expectedUnlock = TimeCalculator.calcularProximoDesbloqueo(newStartDate);
      expect(updatedLote.proximoDesbloqueo, equals(expectedUnlock));
      expect(updatedLote.proximoDesbloqueo, isNot(equals(initialLote.proximoDesbloqueo)));
    });

    testWidgets('TEST-R4-T1-02: ModalLoteSheet edits synchronize proximoDesbloqueo', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Lote? savedLote;
      final initialDate = DateTime(2026, 5, 1, 10, 0);
      final initialLote = LoteBuilder()
          .withId('lote_edit_1')
          .withSupermercado('Carrefour Central')
          .withArea('Bebidas')
          .withUltimoInicio(initialDate, autoCalculateDesbloqueo: true)
          .build();

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          loteParaEditar: initialLote,
          onGuardar: (l) => savedLote = l,
        ),
      );

      // Verify modal mounted with edit title
      expect(find.text('Modificar Lote'), findsOneWidget);

      // Tap to open DatePicker via specific InkWell
      final inkWellFinder = find.widgetWithText(InkWell, 'Última Fecha/Hora de Fotos (Opcional)');
      expect(inkWellFinder, findsOneWidget);
      await tester.tap(inkWellFinder);
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Select day 20 on the calendar
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      // Confirm DatePicker with OK
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Confirm TimePicker with OK
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Save changes
      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      final expectedNewDate = DateTime(2026, 5, 20, 10, 0);
      expect(savedLote, isNotNull);
      expect(savedLote!.id, equals('lote_edit_1'));
      expect(savedLote!.ultimoInicio, equals(expectedNewDate));
      final expectedUnlock = TimeCalculator.calcularProximoDesbloqueo(expectedNewDate);
      expect(savedLote!.proximoDesbloqueo, equals(expectedUnlock));
      expect(savedLote!.proximoDesbloqueo, isNot(equals(initialLote.proximoDesbloqueo)));
      expect(savedLote!.proximoDesbloqueo!.difference(savedLote!.ultimoInicio!).inDays, equals(120));
    });

    testWidgets('TEST-R4-T1-03: Clearing ultimoInicio resets proximoDesbloqueo to null', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Lote? savedLote;
      final loteWithDate = LoteBuilder()
          .withId('lote_clear_1')
          .withUltimoInicio(DateTime(2026, 10, 10, 8, 0), autoCalculateDesbloqueo: true)
          .build();

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          loteParaEditar: loteWithDate,
          onGuardar: (l) => savedLote = l,
        ),
      );

      // Tap the clear icon on the date decorator
      final clearBtn = find.byIcon(Icons.clear);
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // Submit changes
      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(savedLote, isNotNull);
      expect(savedLote!.ultimoInicio, isNull);
      expect(savedLote!.proximoDesbloqueo, isNull);
    });

    test('TEST-R4-T1-04: Editing unrelated fields preserves existing unlock date', () {
      final initialDate = DateTime(2026, 10, 1, 9, 0);
      final initialUnlock = TimeCalculator.calcularProximoDesbloqueo(initialDate);
      final initialLote = LoteBuilder()
          .withId('lote_preserve_1')
          .withSupermercado('Coto Flores')
          .withArea('Almacén')
          .withUltimoInicio(initialDate)
          .withProximoDesbloqueo(initialUnlock)
          .build();

      final updated = initialLote.copyWith(
        supermercado: 'Coto Caballito',
        area: 'Perfumería',
        cantidadProductos: 99,
      );

      expect(updated.supermercado, equals('Coto Caballito'));
      expect(updated.area, equals('Perfumería'));
      expect(updated.cantidadProductos, equals(99));
      expect(updated.ultimoInicio, equals(initialDate));
      expect(updated.proximoDesbloqueo, equals(initialUnlock));
    });

    test('TEST-R4-T1-05: Lote.crear with ultimoInicio computes +120 days', () {
      final date = DateTime(2026, 11, 12, 10, 0);
      final loteWithDate = Lote.crear(
        supermercado: 'Jumbo Palermo',
        area: 'Lácteos',
        ultimoInicio: date,
      );
      final loteWithoutDate = Lote.crear(
        supermercado: 'Jumbo Palermo',
        area: 'Lácteos',
        ultimoInicio: null,
      );

      expect(loteWithDate.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(date)));
      expect(loteWithoutDate.proximoDesbloqueo, isNull);
    });
  });
}
