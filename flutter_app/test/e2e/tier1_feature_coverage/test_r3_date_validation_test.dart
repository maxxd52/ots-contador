import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/models/registro_trabajo.dart';
import 'package:flutter_app/ui/views/modal_sesion_sheet.dart';
import '../harness/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockSharedPreferencesHelper.setEmpty();
  });

  group('Tier 1 - R3: Date Range Validation in Session Registration', () {
    // TEST-R3-T1-01: Valid date range (fin > inicio) submits
    testWidgets('TEST-R3-T1-01: Valid date range (fin > inicio) submits and dismisses modal', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lote = LoteBuilder.habilitado(
        id: 'lote_modal_01',
        supermercado: 'Carrefour San Martín',
        area: 'Galletitas',
        cantidadProductos: 50,
      ).build();

      final inicio = DateTime(2026, 11, 12, 10, 0);
      final fin = DateTime(2026, 11, 12, 10, 45);
      bool onGuardarCalled = false;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: fin,
          onGuardar: ({
            required loteId,
            required supermercado,
            required area,
            required cantidadProductos,
            required inicio,
            required fin,
            observaciones,
          }) {
            onGuardarCalled = true;
          },
        ),
      );

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      expect(onGuardarCalled, isTrue);
      expect(tester.takeException(), isNull);
    });

    // TEST-R3-T1-02: End date earlier than start date auto-corrected by UI validation
    testWidgets('TEST-R3-T1-02: End date earlier than start date is auto-corrected by UI validation', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lote = LoteBuilder.habilitado(id: 'lote_modal_02').build();
      final inicio = DateTime(2026, 11, 12, 10, 0);
      final invalidFin = DateTime(2026, 11, 12, 9, 0); // 1 hour earlier
      DateTime? submittedInicio;
      DateTime? submittedFin;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: invalidFin,
          onGuardar: ({
            required loteId,
            required supermercado,
            required area,
            required cantidadProductos,
            required inicio,
            required fin,
            observaciones,
          }) {
            submittedInicio = inicio;
            submittedFin = fin;
          },
        ),
      );

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      // UI validation in initState auto-corrects inverted date so fin is strictly after inicio
      expect(submittedInicio, equals(inicio));
      expect(submittedFin, isNotNull);
      expect(submittedFin!.isAfter(submittedInicio!), isTrue);
      expect(submittedFin, equals(inicio.add(const Duration(minutes: 45))));
      expect(tester.takeException(), isNull);
    });

    // TEST-R3-T1-03: No ArgumentError red screen on invalid range
    testWidgets('TEST-R3-T1-03: No ArgumentError or red screen thrown when invalid date range is submitted', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Verify domain model throws if unvalidated fin < inicio is forced
      final inicio = DateTime(2026, 11, 12, 14, 0);
      final invalidFin = DateTime(2026, 11, 12, 13, 0);
      expect(
        () => RegistroTrabajo.crear(
          loteId: 'lote_test',
          supermercado: 'Super',
          area: 'Area',
          inicio: inicio,
          fin: invalidFin,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('no puede ser anterior'),
        )),
      );

      // Verify Modal UI prevents the crash from reaching the user
      final lote = LoteBuilder.habilitado(id: 'lote_modal_03').build();
      RegistroTrabajo? createdRecord;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: invalidFin,
          onGuardar: ({
            required loteId,
            required supermercado,
            required area,
            required cantidadProductos,
            required inicio,
            required fin,
            observaciones,
          }) {
            createdRecord = RegistroTrabajo.crear(
              loteId: loteId,
              supermercado: supermercado,
              area: area,
              cantidadProductos: cantidadProductos,
              inicio: inicio,
              fin: fin,
            );
          },
        ),
      );

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      // Modal sanitized the input so RegistroTrabajo.crear succeeded without ArgumentError
      expect(tester.takeException(), isNull);
      expect(createdRecord, isNotNull);
      expect(createdRecord!.fin.isAfter(createdRecord!.inicio), isTrue);
    });

    // TEST-R3-T1-04: Quick duration chips guarantee fin > inicio
    testWidgets('TEST-R3-T1-04: Quick duration chips guarantee fin > inicio and update live box', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lote = LoteBuilder.habilitado(id: 'lote_modal_04').build();
      final inicio = DateTime(2026, 11, 12, 10, 0);

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {},
        ),
      );

      // Tap '+30 min' chip
      await tester.tap(find.text('+30 min'));
      await tester.pump();
      expect(find.text('0h 30m'), findsOneWidget);

      // Tap '+1 hora' chip
      await tester.tap(find.text('+1 hora'));
      await tester.pump();
      expect(find.text('1h 0m'), findsOneWidget);

      // Tap '+1.5 h' chip
      await tester.tap(find.text('+1.5 h'));
      await tester.pump();
      expect(find.text('1h 30m'), findsOneWidget);
    });

    // TEST-R3-T1-05: Live calculation box reflects correct duration
    testWidgets('TEST-R3-T1-05: Live calculation box reflects correct duration and projected unlock date', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lote = LoteBuilder.habilitado(id: 'lote_modal_05').build();
      final inicio = DateTime(2026, 11, 12, 10, 0);
      final fin = DateTime(2026, 11, 12, 11, 30); // Exactly 1 hour 30 min

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: fin,
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {},
        ),
      );

      expect(find.text('Tiempo trabajado:'), findsOneWidget);
      expect(find.text('1h 30m'), findsOneWidget);
      expect(find.text('+120 días exactos'), findsOneWidget);
      expect(find.text('Próximo desbloqueo:'), findsOneWidget);
    });
  });
}
