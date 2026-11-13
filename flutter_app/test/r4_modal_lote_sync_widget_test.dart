import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/logic/time_calculator.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/ui/views/modal_lote_sheet.dart';
import 'e2e/harness/widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R4: ModalLoteSheet - Sincronización de ProximoDesbloqueo en UI', () {
    testWidgets('Limpiar fecha de último relevamiento mediante botón clear resetea proximoDesbloqueo a null', (tester) async {
      final inicio = DateTime(2026, 11, 5, 10, 0);
      final loteInicial = Lote.crear(
        id: 'lote_edit_1',
        supermercado: 'Carrefour San Martín',
        area: 'Lácteos',
        cantidadProductos: 80,
        ultimoInicio: inicio,
      );
      expect(loteInicial.proximoDesbloqueo, isNotNull);

      Lote? loteGuardado;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          loteParaEditar: loteInicial,
          onGuardar: (lote) {
            loteGuardado = lote;
          },
        ),
      );

      // Presionar el botón de limpiar fecha (Icons.clear)
      final clearButtonFinder = find.byIcon(Icons.clear);
      expect(clearButtonFinder, findsOneWidget);
      await tester.tap(clearButtonFinder);
      await tester.pumpAndSettle();

      // Guardar cambios
      final guardarButtonFinder = find.text('Guardar Cambios');
      expect(guardarButtonFinder, findsOneWidget);
      await tester.tap(guardarButtonFinder);
      await tester.pumpAndSettle();

      expect(loteGuardado, isNotNull);
      expect(loteGuardado!.ultimoInicio, isNull);
      expect(
        loteGuardado!.proximoDesbloqueo,
        isNull,
        reason: 'Al limpiar la fecha, el lote debe quedar habilitado de inmediato sin bloqueo pendiente',
      );
    });

    testWidgets('Guardar edición sin modificar fecha preserva proximoDesbloqueo original sin desincronización', (tester) async {
      final inicio = DateTime(2026, 11, 5, 10, 0);
      final loteInicial = Lote.crear(
        id: 'lote_edit_2',
        supermercado: 'Coto Belgrano',
        area: 'Bebidas',
        cantidadProductos: 60,
        ultimoInicio: inicio,
      );

      Lote? loteGuardado;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          loteParaEditar: loteInicial,
          onGuardar: (lote) {
            loteGuardado = lote;
          },
        ),
      );

      // Guardar sin alterar fechas
      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(loteGuardado, isNotNull);
      expect(loteGuardado!.ultimoInicio, equals(inicio));
      expect(loteGuardado!.proximoDesbloqueo, equals(loteInicial.proximoDesbloqueo));
    });

    testWidgets('Crear nuevo lote sin fecha inicial genera proximoDesbloqueo null', (tester) async {
      Lote? loteCreado;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          onGuardar: (lote) {
            loteCreado = lote;
          },
        ),
      );

      // Completar campos obligatorios
      await tester.enterText(find.widgetWithText(TextField, 'Ej: Carrefour San Martín'), 'Supermercado Nuevo');
      await tester.enterText(find.widgetWithText(TextField, 'Ej: Lácteos'), 'Panadería');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear Lote'));
      await tester.pumpAndSettle();

      expect(loteCreado, isNotNull);
      expect(loteCreado!.supermercado, equals('Supermercado Nuevo'));
      expect(loteCreado!.area, equals('Panadería'));
      expect(loteCreado!.ultimoInicio, isNull);
      expect(loteCreado!.proximoDesbloqueo, isNull);
    });

    testWidgets('Edición de lote recalculando proximoDesbloqueo mediante TimeCalculator en ModalLoteSheet', (tester) async {
      final fechaInicial = DateTime(2026, 6, 1, 10, 0);
      final loteInicial = Lote.crear(
        id: 'lote_sync_test',
        supermercado: 'Dia Belgrano',
        area: 'Frescos',
        cantidadProductos: 50,
        ultimoInicio: fechaInicial,
      );

      Lote? loteGuardado;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          loteParaEditar: loteInicial,
          onGuardar: (lote) {
            loteGuardado = lote;
          },
        ),
      );

      // Guardar cambios
      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(loteGuardado, isNotNull);
      expect(
        loteGuardado!.proximoDesbloqueo,
        equals(TimeCalculator.calcularProximoDesbloqueo(fechaInicial)),
      );
    });
  });
}
