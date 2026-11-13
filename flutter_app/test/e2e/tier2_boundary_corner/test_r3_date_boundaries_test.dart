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

  group('Tier 2 - R3: Date Range Boundaries & UI Form Validation', () {
    // TEST-R3-T2-01: Exact equality fin == inicio (0 min duration) valid
    testWidgets('TEST-R3-T2-01: Exact equality fin == inicio (0 min duration) is valid and submits cleanly', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_r3_01').build();
      final exactDate = DateTime(2026, 11, 12, 10, 0);
      bool onGuardarCalled = false;
      DateTime? savedInicio;
      DateTime? savedFin;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: exactDate,
          fin: exactDate,
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
            savedInicio = inicio;
            savedFin = fin;
          },
        ),
      );

      expect(find.text('0h 0m'), findsOneWidget);

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      expect(onGuardarCalled, isTrue);
      expect(savedInicio, equals(exactDate));
      expect(savedFin, equals(exactDate));
      expect(find.byType(ModalSesionSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // TEST-R3-T2-02: Negative boundary fin = inicio - 1 second
    testWidgets('TEST-R3-T2-02: Negative boundary fin = inicio - 1 second is intercepted by UI validation', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_r3_02').build();
      final inicio = DateTime(2026, 11, 12, 10, 0, 0);
      bool onGuardarCalled = false;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: inicio.add(const Duration(minutes: 30)),
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

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(inicio.subtract(const Duration(seconds: 1)));
      await tester.pump();

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      expect(onGuardarCalled, isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('La fecha/hora de fin no puede ser anterior a la de inicio'), findsOneWidget);
      expect(find.byType(ModalSesionSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // TEST-R3-T2-03: Modifying inicio after setting fin auto-corrects or intercepts
    testWidgets('TEST-R3-T2-03: Setting inicio after fin clamps duration to 0 and intercepts submission', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_r3_03').build();
      final baseInicio = DateTime(2026, 11, 12, 10, 0);
      final baseFin = DateTime(2026, 11, 12, 11, 0);
      bool onGuardarCalled = false;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: baseInicio,
          fin: baseFin,
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

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      // Invert range: new inicio at 12:00, old fin at 11:00
      state.setInicioFinForTesting(DateTime(2026, 11, 12, 12, 0), baseFin);
      await tester.pump();

      // Live calculation safely clamps to 0h 0m
      expect(find.text('0h 0m'), findsOneWidget);

      // Attempt submission
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      expect(onGuardarCalled, isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('La fecha/hora de fin no puede ser anterior a la de inicio'), findsOneWidget);
      expect(find.byType(ModalSesionSheet), findsOneWidget);
    });

    // TEST-R3-T2-04: Dismissing date picker without selection preserves state
    testWidgets('TEST-R3-T2-04: Dismissing date picker without selection preserves previous timestamps', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_r3_04').build();
      final inicio = DateTime(2026, 11, 12, 10, 0);
      final fin = DateTime(2026, 11, 12, 10, 45);

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
          }) {},
        ),
      );

      expect(find.text('0h 45m'), findsOneWidget);

      // Open DatePicker by tapping start date selector
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Dismiss dialog by tapping Cancel
      final cancelButton = find.text('Cancel');
      if (cancelButton.evaluate().isNotEmpty) {
        await tester.tap(cancelButton);
      } else {
        await tester.tap(find.byType(TextButton).first);
      }
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.byType(ModalSesionSheet), findsOneWidget);
      expect(find.text('0h 45m'), findsOneWidget);
    });

    // TEST-R3-T2-05: Extreme inverted range (fin 1 year before inicio)
    testWidgets('TEST-R3-T2-05: Extreme inverted range is trapped at domain and UI layers with zero red screen', (tester) async {
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

      final inicio = DateTime(2026, 11, 12, 10, 0);
      final invertedFin = DateTime(2025, 11, 12, 10, 0);

      // 1. Domain model guard enforces strict validation
      expect(
        () => RegistroTrabajo.crear(
          loteId: 'lote_extreme_05',
          supermercado: 'Coto Central',
          area: 'Lácteos',
          inicio: inicio,
          fin: invertedFin,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('no puede ser anterior'),
        )),
      );

      // 2. UI form traps submission before model creation
      final lote = LoteBuilder.habilitado(id: 'lote_r3_05').build();
      bool onGuardarCalled = false;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: inicio.add(const Duration(minutes: 45)),
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

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(invertedFin);
      await tester.pump();

      // UI clamps live display safely to 0h 0m
      expect(find.text('0h 0m'), findsOneWidget);

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      expect(onGuardarCalled, isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('La fecha/hora de fin no puede ser anterior a la de inicio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
