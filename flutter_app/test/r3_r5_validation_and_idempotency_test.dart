import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/domain/models/registro_trabajo.dart';
import 'package:flutter_app/ui/views/modal_sesion_sheet.dart';
import 'package:flutter_app/ui/views/modal_lote_sheet.dart';
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
  // Group 1: R3 - Date Range Validation in ModalSesionSheet
  // =========================================================================
  group('R3: Date Range Validation in Session Registration', () {
    test('TEST-R3-01: Domain invariant - RegistroTrabajo.crear rejects fin before inicio with ArgumentError', () {
      final inicio = DateTime(2026, 11, 12, 10, 0);
      final finAnterior = DateTime(2026, 11, 12, 9, 30);
      final finIgual = DateTime(2026, 11, 12, 10, 0);
      final finPosterior = DateTime(2026, 11, 12, 11, 0);

      // Rejection when fin < inicio
      expect(
        () => RegistroTrabajo.crear(
          loteId: 'lote_1',
          supermercado: 'Coto',
          area: 'Lácteos',
          inicio: inicio,
          fin: finAnterior,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('no puede ser anterior'),
        )),
      );

      // fin == inicio is allowed (0 duration)
      final regCero = RegistroTrabajo.crear(
        loteId: 'lote_1',
        supermercado: 'Coto',
        area: 'Lácteos',
        inicio: inicio,
        fin: finIgual,
      );
      expect(regCero.duracionMinutos, equals(0));

      // fin > inicio is normal
      final regNormal = RegistroTrabajo.crear(
        loteId: 'lote_1',
        supermercado: 'Coto',
        area: 'Lácteos',
        inicio: inicio,
        fin: finPosterior,
      );
      expect(regNormal.duracionMinutos, equals(60));
    });

    testWidgets('TEST-R3-02: Pre-submission validation shows SnackBar and blocks onGuardar when fin < inicio', (tester) async {
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
        id: 'lote_r3_01',
        supermercado: 'Carrefour San Martín',
        area: 'Galletitas',
        cantidadProductos: 50,
      ).build();

      final inicio = DateTime(2026, 11, 12, 10, 0);
      final finValido = DateTime(2026, 11, 12, 11, 0);
      bool onGuardarCalled = false;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: finValido,
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

      // Simulate the user selecting an invalid end date via date picker / test helper
      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(DateTime(2026, 11, 12, 9, 0));
      await tester.pump();

      // Tap submit
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      // Verify onGuardar was NOT called
      expect(onGuardarCalled, isFalse);

      // Verify user-friendly SnackBar is displayed with exact message
      expect(
        find.text('La fecha/hora de fin no puede ser anterior a la de inicio'),
        findsOneWidget,
      );

      // Verify modal remains open
      expect(find.byType(ModalSesionSheet), findsOneWidget);
    });

    testWidgets('TEST-R3-03: Form data is preserved across date range validation failure', (tester) async {
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

      // Modify form fields
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Supermercado Disco');
      await tester.enterText(textFields.at(1), 'Perfumería');
      await tester.enterText(textFields.at(2), '77');
      await tester.enterText(textFields.at(3), 'Stock verificado al 100%');
      await tester.pump();

      // Invalidate end date
      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(inicio.subtract(const Duration(minutes: 30)));
      await tester.pump();

      // Tap submit
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      // SnackBar shows error
      expect(find.text('La fecha/hora de fin no puede ser anterior a la de inicio'), findsOneWidget);

      // Inputs preserved exactly
      expect(find.text('Supermercado Disco'), findsOneWidget);
      expect(find.text('Perfumería'), findsOneWidget);
      expect(find.text('77'), findsOneWidget);
      expect(find.text('Stock verificado al 100%'), findsOneWidget);
    });

    testWidgets('TEST-R3-04: User can recover from invalid date error using quick chips and submit successfully', (tester) async {
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
      final inicio = DateTime(2026, 11, 12, 10, 0);
      bool submitted = false;
      DateTime? finalFin;

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
            submitted = true;
            finalFin = fin;
          },
        ),
      );

      // Invalidate end date and try to submit
      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(inicio.subtract(const Duration(minutes: 15)));
      await tester.pump();

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();
      expect(submitted, isFalse);

      // Recover using '+45 min' quick chip
      await tester.tap(find.text('+45 min'));
      await tester.pump();

      // Submit again
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      expect(submitted, isTrue);
      expect(finalFin, equals(inicio.add(const Duration(minutes: 45))));
      expect(find.byType(ModalSesionSheet), findsNothing); // Dialog dismissed
    });

    testWidgets('TEST-R3-05: Boundary condition - fin == inicio is accepted without throwing', (tester) async {
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
      bool submitted = false;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: inicio.add(const Duration(hours: 1)),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            submitted = true;
          },
        ),
      );

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      state.setFinForTesting(inicio); // fin == inicio
      await tester.pump();

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      expect(submitted, isTrue);
    });
  });

  // =========================================================================
  // Group 2: R5 - UI Debouncing in ModalSesionSheet
  // =========================================================================
  group('R5: UI Debouncing in ModalSesionSheet', () {
    testWidgets('TEST-R5-SESION-01: Rapid multiple taps on submit button trigger onGuardar only once', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_deb_01').build();
      final completer = Completer<void>();
      int callCount = 0;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: DateTime(2026, 11, 12, 10, 0),
          fin: DateTime(2026, 11, 12, 11, 0),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            callCount++;
            return completer.future;
          },
        ),
      );

      // Tap 1
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump(); // Deliver tap event and rebuild frame with _isSubmitting = true

      expect(callCount, equals(1));

      // Visual feedback: CircularProgressIndicator is displayed inside submit button
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Tap 2, 3, 4 rapidly
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();

      // Invocations remain strictly 1
      expect(callCount, equals(1));

      // Resolve async save
      completer.complete();
      await tester.pumpAndSettle();

      // Modal closed, total invocations still 1
      expect(callCount, equals(1));
      expect(find.byType(ModalSesionSheet), findsNothing);
    });

    testWidgets('TEST-R5-SESION-02: Cancel, close icon, and quick chips are disabled during submission', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_deb_02').build();
      final completer = Completer<void>();

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: DateTime(2026, 11, 12, 10, 0),
          fin: DateTime(2026, 11, 12, 11, 0),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            return completer.future;
          },
        ),
      );

      // Submit once
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      // Cancel button is disabled
      final cancelButton = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Cancelar'));
      expect(cancelButton.onPressed, isNull);

      // Close icon button is disabled
      final closeButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close));
      expect(closeButton.onPressed, isNull);

      // Quick chip buttons are disabled
      final chipButton = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '+30 min'));
      expect(chipButton.onPressed, isNull);

      // Finish save
      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('TEST-R5-SESION-03: On async error in onGuardar, _isSubmitting resets and user can retry', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_deb_03').build();
      int attempt = 0;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: DateTime(2026, 11, 12, 10, 0),
          fin: DateTime(2026, 11, 12, 11, 0),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) async {
            attempt++;
            if (attempt == 1) {
              throw Exception('Simulated network timeout');
            }
          },
        ),
      );

      // Attempt 1 fails
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      expect(attempt, equals(1));
      expect(find.textContaining('Error al guardar la sesión: Exception: Simulated network timeout'), findsOneWidget);
      expect(find.byType(ModalSesionSheet), findsOneWidget); // Still mounted

      // State recovered: button is active again
      expect(find.text('Guardar y Reprogramar'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Attempt 2 succeeds
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      expect(attempt, equals(2));
      expect(find.byType(ModalSesionSheet), findsNothing); // Dialog dismissed
    });
  });

  // =========================================================================
  // Group 3: R5 - UI Debouncing in ModalLoteSheet
  // =========================================================================
  group('R5: UI Debouncing in ModalLoteSheet', () {
    testWidgets('TEST-R5-LOTE-01: Rapid multiple taps on submit button trigger onGuardar only once', (tester) async {
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

      final completer = Completer<void>();
      int callCount = 0;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          onGuardar: (lote) {
            callCount++;
            return completer.future;
          },
        ),
      );

      // Fill required fields
      await tester.enterText(find.widgetWithText(TextField, 'Supermercado *'), 'Jumbo Palermo');
      await tester.enterText(find.widgetWithText(TextField, 'Área / Sector *'), 'Bebidas');
      await tester.pump();

      // Tap 1
      await tester.tap(find.text('Crear Lote'));
      await tester.pump();

      expect(callCount, equals(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Additional rapid taps
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();

      expect(callCount, equals(1));

      // Controls are disabled
      final cancelButton = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Cancelar'));
      expect(cancelButton.onPressed, isNull);
      final closeButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close));
      expect(closeButton.onPressed, isNull);

      // Complete async save
      completer.complete();
      await tester.pumpAndSettle();

      expect(callCount, equals(1));
      expect(find.byType(ModalLoteSheet), findsNothing);
    });

    testWidgets('TEST-R5-LOTE-02: On async error in onGuardar, _isSubmitting resets and allows retry', (tester) async {
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

      int attempts = 0;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          onGuardar: (lote) async {
            attempts++;
            if (attempts == 1) {
              throw Exception('Firestore unavailable');
            }
          },
        ),
      );

      // Fill required fields
      await tester.enterText(find.widgetWithText(TextField, 'Supermercado *'), 'Vea Centro');
      await tester.enterText(find.widgetWithText(TextField, 'Área / Sector *'), 'Carnicería');
      await tester.pump();

      // Attempt 1
      await tester.tap(find.text('Crear Lote'));
      await tester.pumpAndSettle();

      expect(attempts, equals(1));
      expect(find.textContaining('Error al guardar el lote: Exception: Firestore unavailable'), findsOneWidget);
      expect(find.byType(ModalLoteSheet), findsOneWidget);

      // Retry Attempt 2
      await tester.tap(find.text('Crear Lote'));
      await tester.pumpAndSettle();

      expect(attempts, equals(2));
      expect(find.byType(ModalLoteSheet), findsNothing);
    });
  });

  // =========================================================================
  // Group 4: R5 - Mutex Guards in TableroViewModel
  // =========================================================================
  group('R5: Mutex Guards in TableroViewModel', () {
    test('TEST-R5-VM-01: Concurrent guardarSesionFotos calls drop duplicates and do not inflate kpiHorasHoy', () async {
      final repo = FakeOtsRepository(useSeedData: true)..simulateDelay = const Duration(milliseconds: 30);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final now = DateTime.now();
      final inicio = DateTime(now.year, now.month, now.day, 10, 0);
      final fin = DateTime(now.year, now.month, now.day, 12, 0); // 2 hours = 120 minutes

      // Dispatch 2 concurrent calls
      await Future.wait([
        vm.guardarSesionFotos(
          loteId: 'lote_1',
          supermercado: 'Coto Central',
          area: 'Bebidas',
          cantidadProductos: 20,
          inicio: inicio,
          fin: fin,
        ),
        vm.guardarSesionFotos(
          loteId: 'lote_1',
          supermercado: 'Coto Central',
          area: 'Bebidas',
          cantidadProductos: 20,
          inicio: inicio,
          fin: fin,
        ),
      ]);

      // Exactly 1 save call was processed by repository
      expect(repo.guardarRegistroCallCount, equals(1));
      expect(vm.registros.length, equals(1));

      // kpiHorasHoy must show exactly '2h 0m', NOT '4h 0m'
      expect(vm.kpiHorasHoy, equals('2h 0m'));
      expect(vm.isSavingSesion, isFalse);
    });

    test('TEST-R5-VM-02: Burst invocations (N=10) drop all re-entrant calls', () async {
      final repo = FakeOtsRepository(useSeedData: true)..simulateDelay = const Duration(milliseconds: 20);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final now = DateTime.now();
      final inicio = DateTime(now.year, now.month, now.day, 8, 0);
      final fin = DateTime(now.year, now.month, now.day, 9, 30); // 1h 30m

      // Fire 10 concurrent requests
      await Future.wait(
        List.generate(
          10,
          (_) => vm.guardarSesionFotos(
            loteId: 'lote_1',
            supermercado: 'Carrefour Express',
            area: 'Lácteos',
            cantidadProductos: 15,
            inicio: inicio,
            fin: fin,
          ),
        ),
      );

      expect(repo.guardarRegistroCallCount, equals(1));
      expect(vm.registros.length, equals(1));
      expect(vm.kpiHorasHoy, equals('1h 30m'));
      expect(vm.isSavingSesion, isFalse);
    });

    test('TEST-R5-VM-03: Mutex releases on repository failure in guardarSesionFotos without deadlock', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      // Cause repository to fail
      repo.simulateFailOnGuardarRegistro = true;

      final now = DateTime.now();
      await expectLater(
        () => vm.guardarSesionFotos(
          loteId: 'lote_1',
          supermercado: 'Coto',
          area: 'Almacén',
          cantidadProductos: 10,
          inicio: now,
          fin: now.add(const Duration(hours: 1)),
        ),
        throwsA(isA<FirebaseException>()),
      );

      // Mutex MUST be released despite error
      expect(vm.isSavingSesion, isFalse);

      // Subsequent call with recovered repository succeeds
      repo.simulateFailOnGuardarRegistro = false;
      await vm.guardarSesionFotos(
        loteId: 'lote_1',
        supermercado: 'Coto',
        area: 'Almacén',
        cantidadProductos: 10,
        inicio: now,
        fin: now.add(const Duration(hours: 1)),
      );

      expect(repo.guardarRegistroCallCount, equals(2)); // 1 failed + 1 succeeded
      expect(vm.registros.length, equals(1));
      expect(vm.isSavingSesion, isFalse);
    });

    test('TEST-R5-VM-04: Concurrent guardarLote calls drop duplicate invocations', () async {
      final repo = FakeOtsRepository(useSeedData: true)..simulateDelay = const Duration(milliseconds: 30);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final nuevoLote = Lote.crear(
        supermercado: 'Carrefour Norte',
        area: 'Bazar',
        cantidadProductos: 40,
      );

      // Dispatch 2 concurrent guardarLote calls
      await Future.wait([
        vm.guardarLote(nuevoLote),
        vm.guardarLote(nuevoLote),
      ]);

      expect(repo.guardarLoteCallCount, equals(1));
      expect(vm.isSavingLote, isFalse);
    });

    test('TEST-R5-VM-05: Mutex releases on repository failure in guardarLote without deadlock', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      repo.simulateFailOnGuardarLote = true;

      final nuevoLote = Lote.crear(
        supermercado: 'Disco',
        area: 'Carnes',
      );

      await expectLater(
        () => vm.guardarLote(nuevoLote),
        throwsA(isA<FirebaseException>()),
      );

      expect(vm.isSavingLote, isFalse);

      // Succeeds after recovery
      repo.simulateFailOnGuardarLote = false;
      await vm.guardarLote(nuevoLote);

      expect(repo.guardarLoteCallCount, equals(2));
      expect(vm.isSavingLote, isFalse);
    });

    test('TEST-R5-VM-06: Independent mutex isolation - isSavingSesion does not block guardarLote', () async {
      final repo = FakeOtsRepository(useSeedData: true);

      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      // Launch a slow guardarSesionFotos
      final now = DateTime.now();
      // Use fake with simulateDelay
      repo.simulateDelay = const Duration(milliseconds: 100);

      final sesionFuture = vm.guardarSesionFotos(
        loteId: 'lote_1',
        supermercado: 'Coto',
        area: 'Panadería',
        cantidadProductos: 5,
        inicio: now,
        fin: now.add(const Duration(minutes: 30)),
      );

      // isSavingSesion is active
      expect(vm.isSavingSesion, isTrue);
      expect(vm.isSavingLote, isFalse);

      // guardarLote is not blocked and completes normally
      final nuevoLote = Lote.crear(supermercado: 'Día', area: 'Frescos');
      await vm.guardarLote(nuevoLote);

      expect(repo.guardarLoteCallCount, equals(1));

      // Await sesion to finish
      await sesionFuture;
      expect(vm.isSavingSesion, isFalse);
      expect(repo.guardarRegistroCallCount, equals(1));
    });
  });
}
