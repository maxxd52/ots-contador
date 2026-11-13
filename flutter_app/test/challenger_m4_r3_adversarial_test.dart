import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/ui/views/modal_sesion_sheet.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import 'e2e/harness/fake_ots_repository.dart';
import 'e2e/harness/mock_shared_preferences.dart';
import 'e2e/harness/test_builders.dart';
import 'e2e/harness/widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockSharedPreferencesHelper.setEmpty();
  });

  // =========================================================================
  // GROUP 1: Microsecond & Millisecond Extreme Boundary Stress
  // =========================================================================
  group('ADV-R3-G1: Sub-millisecond & Millisecond Boundary Stress', () {
    testWidgets('ADV-R3-01: fin exactly 1 microsecond before inicio is rejected', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_adv_01').build();
      final inicio = DateTime(2026, 11, 12, 14, 0, 0, 0, 100); // 100 microseconds
      final fin1usBefore = inicio.subtract(const Duration(microseconds: 1));
      bool onGuardarCalled = false;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: inicio.add(const Duration(hours: 1)),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            onGuardarCalled = true;
          },
        ),
      );

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(fin1usBefore);
      await tester.pump();

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      expect(onGuardarCalled, isFalse, reason: 'onGuardar must NEVER be called when fin is 1us before inicio');
      expect(find.text('La fecha/hora de fin no puede ser anterior a la de inicio'), findsOneWidget);
      expect(find.byType(ModalSesionSheet), findsOneWidget);
      expect(state.isSubmitting, isFalse);
    });

    testWidgets('ADV-R3-02: fin exactly 1 millisecond before inicio is rejected', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_adv_02').build();
      final inicio = DateTime(2026, 11, 12, 10, 30, 0, 500);
      final fin1msBefore = inicio.subtract(const Duration(milliseconds: 1));
      bool onGuardarCalled = false;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: inicio.add(const Duration(hours: 1)),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            onGuardarCalled = true;
          },
        ),
      );

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(fin1msBefore);
      await tester.pump();

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      expect(onGuardarCalled, isFalse);
      expect(find.text('La fecha/hora de fin no puede ser anterior a la de inicio'), findsOneWidget);
      expect(find.byType(ModalSesionSheet), findsOneWidget);
    });

    testWidgets('ADV-R3-03: fin exactly equal to inicio (0 duration) is accepted and submits cleanly', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_adv_03').build();
      final inicio = DateTime(2026, 11, 12, 10, 0, 0, 0);
      bool onGuardarCalled = false;
      DateTime? submittedInicio;
      DateTime? submittedFin;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: inicio.add(const Duration(hours: 1)),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            onGuardarCalled = true;
            submittedInicio = inicio;
            submittedFin = fin;
          },
        ),
      );

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(inicio); // fin == inicio
      await tester.pump();

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      expect(onGuardarCalled, isTrue, reason: 'fin == inicio should be valid (0 duration)');
      expect(submittedInicio, equals(submittedFin));
      expect(find.byType(ModalSesionSheet), findsNothing); // Modal dismissed
    });

    testWidgets('ADV-R3-04: fin exactly 1 microsecond after inicio is accepted and submits cleanly', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_adv_04').build();
      final inicio = DateTime(2026, 11, 12, 10, 0, 0, 0);
      final fin1usAfter = inicio.add(const Duration(microseconds: 1));
      bool onGuardarCalled = false;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: inicio.add(const Duration(hours: 1)),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            onGuardarCalled = true;
          },
        ),
      );

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(fin1usAfter);
      await tester.pump();

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      expect(onGuardarCalled, isTrue);
      expect(find.byType(ModalSesionSheet), findsNothing);
    });
  });

  // =========================================================================
  // GROUP 2: Massive Temporal Inversion & Display Rendering Stability
  // =========================================================================
  group('ADV-R3-G2: Extreme Temporal Inversion & Display Rendering Stability', () {
    testWidgets('ADV-R3-05: Massive temporal inversion (1970 vs 2026) renders safely and rejects submission', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_adv_05').build();
      final inicio = DateTime(2026, 11, 12, 10, 0);
      final epochFin = DateTime(1970, 1, 1, 0, 0);
      bool onGuardarCalled = false;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: inicio.add(const Duration(hours: 1)),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            onGuardarCalled = true;
          },
        ),
      );

      // Force massive inversion
      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(epochFin);
      await tester.pump();

      // Ensure live calculation box rendered 0h 0m safely without crash
      expect(find.text('0h 0m'), findsOneWidget);

      // Tap submit
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      expect(onGuardarCalled, isFalse);
      expect(find.text('La fecha/hora de fin no puede ser anterior a la de inicio'), findsOneWidget);
      expect(find.byType(ModalSesionSheet), findsOneWidget);
    });

    testWidgets('ADV-R3-06: 100-year temporal inversion renders and rejects cleanly', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_adv_06').build();
      final inicio = DateTime(2026, 11, 12, 10, 0);
      final centennialFin = DateTime(1926, 11, 12, 10, 0);
      bool onGuardarCalled = false;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: inicio.add(const Duration(hours: 1)),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            onGuardarCalled = true;
          },
        ),
      );

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(centennialFin);
      await tester.pump();

      expect(find.text('0h 0m'), findsOneWidget);

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      expect(onGuardarCalled, isFalse);
      expect(find.text('La fecha/hora de fin no puede ser anterior a la de inicio'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 3: Consecutive Burst Submissions (Stress / Fatigue Harness)
  // =========================================================================
  group('ADV-R3-G3: High-Frequency Consecutive Invalid Submissions', () {
    testWidgets('ADV-R3-07: 25 rapid consecutive taps with invalid dates preserve form data and never call onGuardar', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_adv_07').build();
      final inicio = DateTime(2026, 11, 12, 10, 0);
      int callCount = 0;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: inicio.add(const Duration(hours: 1)),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            callCount++;
          },
        ),
      );

      // Enter detailed form data
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Jumbo Unicenter');
      await tester.enterText(textFields.at(1), 'Electrodomésticos');
      await tester.enterText(textFields.at(2), '142');
      await tester.enterText(textFields.at(3), 'Campaña especial black friday');
      await tester.pump();

      // Invalidate fin
      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(inicio.subtract(const Duration(hours: 2)));
      await tester.pump();

      // Stress harness: Fire 25 consecutive taps
      final submitButtonFinder = find.text('Guardar y Reprogramar');
      for (int i = 0; i < 25; i++) {
        await tester.tap(submitButtonFinder);
        await tester.pump(const Duration(milliseconds: 16));
        // Verify isSubmitting remains false at each burst step
        expect(state.isSubmitting, isFalse, reason: 'isSubmitting must never get stuck true on validation failure');
      }

      // Assertions after 25 consecutive invalid submissions
      expect(callCount, equals(0), reason: 'onGuardar must NEVER be called across 25 invalid attempts');
      expect(find.byType(ModalSesionSheet), findsOneWidget, reason: 'Modal must remain mounted');
      expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'No stuck loading indicators');

      // Verify all form data is 100% intact
      expect(find.text('Jumbo Unicenter'), findsOneWidget);
      expect(find.text('Electrodomésticos'), findsOneWidget);
      expect(find.text('142'), findsOneWidget);
      expect(find.text('Campaña especial black friday'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 4: Multi-Step Recovery and State Mutation Lifecycle
  // =========================================================================
  group('ADV-R3-G4: Multi-Step Recovery & Form Mutation Lifecycle', () {
    testWidgets('ADV-R3-08: Full cycle - enter data -> fail -> mutate data -> fail -> recover with chip -> submit', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_adv_08').build();
      final inicio = DateTime(2026, 11, 12, 10, 0);
      int callCount = 0;
      String? savedSuper;
      String? savedArea;
      int? savedProds;
      String? savedObs;
      DateTime? savedFin;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: inicio.add(const Duration(hours: 1)),
          onGuardar: ({
            required loteId,
            required supermercado,
            required area,
            required cantidadProductos,
            required inicio,
            required fin,
            observaciones,
          }) {
            callCount++;
            savedSuper = supermercado;
            savedArea = area;
            savedProds = cantidadProductos;
            savedObs = observaciones;
            savedFin = fin;
          },
        ),
      );

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));

      // Step 1: Initial custom inputs
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Disco Caballito');
      await tester.enterText(textFields.at(1), 'Rotisería');
      await tester.enterText(textFields.at(2), '25');
      await tester.enterText(textFields.at(3), 'Primer intento');
      await tester.pump();

      // Step 2: Set invalid fin (30 min before inicio)
      state.setFinForTesting(inicio.subtract(const Duration(minutes: 30)));
      await tester.pump();

      // Step 3: Attempt submit -> rejected
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();
      expect(callCount, equals(0));
      expect(find.text('La fecha/hora de fin no puede ser anterior a la de inicio'), findsOneWidget);

      // Step 4: Mutate user inputs while in failed state
      await tester.enterText(textFields.at(2), '88');
      await tester.enterText(textFields.at(3), 'Segundo intento con correcciones adicionales');
      await tester.pump();

      // Step 5: Attempt submit again without fixing date -> still rejected
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();
      expect(callCount, equals(0));
      expect(find.text('88'), findsOneWidget);
      expect(find.text('Segundo intento con correcciones adicionales'), findsOneWidget);

      // Step 6: Fix date using quick chip '+1 hora'
      await tester.tap(find.text('+1 hora'));
      await tester.pump();

      // Step 7: Submit successfully
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      expect(callCount, equals(1));
      expect(savedSuper, equals('Disco Caballito'));
      expect(savedArea, equals('Rotisería'));
      expect(savedProds, equals(88));
      expect(savedObs, equals('Segundo intento con correcciones adicionales'));
      expect(savedFin, equals(inicio.add(const Duration(hours: 1))));
      expect(find.byType(ModalSesionSheet), findsNothing);
    });

    testWidgets('ADV-R3-09: Recovery by moving inicio before fin via setInicioFinForTesting', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_adv_09').build();
      final inicio = DateTime(2026, 11, 12, 10, 0);
      final fin = DateTime(2026, 11, 12, 9, 0); // invalid
      bool onGuardarCalled = false;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: fin, // initState auto-corrects this to inicio + 45m
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            onGuardarCalled = true;
          },
        ),
      );

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));

      // Make fin invalid again
      state.setFinForTesting(inicio.subtract(const Duration(hours: 1)));
      await tester.pump();

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();
      expect(onGuardarCalled, isFalse);

      // Now recover by shifting inicio earlier (e.g. to 7:00 AM)
      state.setInicioFinForTesting(
        DateTime(2026, 11, 12, 7, 0),
        DateTime(2026, 11, 12, 9, 0),
      );
      await tester.pump();

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      expect(onGuardarCalled, isTrue);
      expect(find.byType(ModalSesionSheet), findsNothing);
    });
  });

  // =========================================================================
  // GROUP 5: Precedence & Combined Validation Invariants
  // =========================================================================
  group('ADV-R3-G5: Validation Order Precedence & InitState Backward Compatibility', () {
    testWidgets('ADV-R3-10: Required field validation takes precedence over date range check', (tester) async {
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
        id: 'lote_adv_10',
        supermercado: '',
        area: '',
      ).build();
      final inicio = DateTime(2026, 11, 12, 10, 0);

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: inicio.add(const Duration(hours: 1)),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {},
        ),
      );

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(inicio.subtract(const Duration(hours: 1)));
      await tester.pump();

      // Clear both text fields
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '');
      await tester.enterText(textFields.at(1), '');
      await tester.pump();

      // Tap submit with both empty fields AND invalid date
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      // Expect 'Supermercado y Área son obligatorios.' SnackBar
      expect(find.text('Supermercado y Área son obligatorios.'), findsOneWidget);
      expect(find.text('La fecha/hora de fin no puede ser anterior a la de inicio'), findsNothing);

      // Clear previous SnackBar so the next one can display immediately
      ScaffoldMessenger.of(tester.element(find.byType(ModalSesionSheet))).clearSnackBars();
      await tester.pump();

      // Now fill supermarket and area, leaving date invalid
      await tester.enterText(textFields.at(0), 'Carrefour');
      await tester.enterText(textFields.at(1), 'Lácteos');
      await tester.pump();

      // Tap submit again -> date check fires
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      expect(find.text('La fecha/hora de fin no puede ser anterior a la de inicio'), findsOneWidget);
    });

    testWidgets('ADV-R3-11: InitState backward compatibility auto-corrects fin < inicio on construction', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_adv_11').build();
      final inicio = DateTime(2026, 11, 12, 10, 0);
      final finAnterior = DateTime(2026, 11, 12, 8, 0); // 2 hours prior
      bool onGuardarCalled = false;
      DateTime? finalFin;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: finAnterior,
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            onGuardarCalled = true;
            finalFin = fin;
          },
        ),
      );

      // Tap submit immediately without modifying anything
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      // Must succeed because initState auto-corrected to inicio + 45 min
      expect(onGuardarCalled, isTrue);
      expect(finalFin, equals(inicio.add(const Duration(minutes: 45))));
      expect(find.byType(ModalSesionSheet), findsNothing);
    });
  });

  // =========================================================================
  // GROUP 6: Red Screen / Crash Immunity Across UI and ViewModel
  // =========================================================================
  group('ADV-R3-G6: Red Screen / ArgumentError Crash Immunity Across UI and ViewModel', () {
    testWidgets('ADV-R3-12: Zero unhandled FlutterError exceptions across all invalid date submissions', (tester) async {
      final List<FlutterErrorDetails> errorLog = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        errorLog.add(details);
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lote = LoteBuilder.habilitado(id: 'lote_adv_12').build();
      final inicio = DateTime(2026, 11, 12, 10, 0);

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: inicio.add(const Duration(hours: 1)),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {},
        ),
      );

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));

      // Test a spectrum of negative intervals
      final testIntervals = [
        const Duration(microseconds: 1),
        const Duration(milliseconds: 1),
        const Duration(seconds: 1),
        const Duration(minutes: 1),
        const Duration(hours: 1),
        const Duration(days: 1),
        const Duration(days: 365),
      ];

      for (final interval in testIntervals) {
        state.setFinForTesting(inicio.subtract(interval));
        await tester.pump();
        await tester.tap(find.text('Guardar y Reprogramar'));
        await tester.pump();
      }

      // Assert no ArgumentError or red-screen producing error was caught
      final unhandledExceptions = errorLog.where((e) => e.exception is ArgumentError).toList();
      expect(unhandledExceptions, isEmpty, reason: 'Zero ArgumentError exceptions should escape to FlutterError');
    });

    test('ADV-R3-13: ViewModel guard ensures isSavingSesion unlocks even if ArgumentError were thrown', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final now = DateTime.now();
      final inicio = now;
      final finAnterior = now.subtract(const Duration(hours: 1));

      // Directly invoking viewModel with invalid dates triggers RegistroTrabajo.crear ArgumentError
      await expectLater(
        () => vm.guardarSesionFotos(
          loteId: 'lote_1',
          supermercado: 'Super Coto',
          area: 'Bazar',
          cantidadProductos: 10,
          inicio: inicio,
          fin: finAnterior,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Verify ViewModel mutex was safely released in finally block
      expect(vm.isSavingSesion, isFalse, reason: 'ViewModel must not deadlock when ArgumentError occurs');

      // Subsequent valid invocation succeeds
      await vm.guardarSesionFotos(
        loteId: 'lote_1',
        supermercado: 'Super Coto',
        area: 'Bazar',
        cantidadProductos: 10,
        inicio: inicio,
        fin: inicio.add(const Duration(hours: 1)),
      );

      expect(repo.guardarRegistroCallCount, equals(1));
      expect(vm.isSavingSesion, isFalse);
    });
  });
}
