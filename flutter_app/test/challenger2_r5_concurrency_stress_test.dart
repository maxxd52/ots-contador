import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/models/lote.dart';
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
  // Group 1: TableroViewModel Mutex Under High-Volume Bursts (50-100 parallel calls)
  // =========================================================================
  group('Adversarial Group 1: TableroViewModel High-Volume Bursts (N=50-100)', () {
    test('STRESS-R5-VM-01: 100 parallel calls to guardarSesionFotos via Future.wait', () async {
      final repo = FakeOtsRepository(useSeedData: true)
        ..simulateDelay = const Duration(milliseconds: 30);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final now = DateTime.now();
      final inicio = DateTime(now.year, now.month, now.day, 10, 0);
      final fin = DateTime(now.year, now.month, now.day, 12, 0); // 2 hours = 120 minutes

      // Fire burst of 100 simultaneous calls
      final burstFutures = List.generate(
        100,
        (i) => vm.guardarSesionFotos(
          loteId: 'lote_1',
          supermercado: 'Super Coto Burst $i',
          area: 'Sector $i',
          cantidadProductos: 10 + i,
          inicio: inicio,
          fin: fin,
        ),
      );

      await Future.wait(burstFutures);

      // Exactly 1 save operation executed in repository
      expect(repo.guardarRegistroCallCount, equals(1),
          reason: 'Only the very first call should be processed; the remaining 99 must be dropped by mutex');
      expect(vm.registros.length, equals(1));

      // Hours must NOT be duplicated or inflated: 1 session of 2 hours = '2h 0m', NOT '200h 0m'
      expect(vm.kpiHorasHoy, equals('2h 0m'));

      // Mutex state must be cleanly released
      expect(vm.isSavingSesion, isFalse);

      // Verify system liveness: a subsequent normal call must execute cleanly
      final fin2 = DateTime(now.year, now.month, now.day, 13, 0); // 1 extra hour
      await vm.guardarSesionFotos(
        loteId: 'lote_2',
        supermercado: 'Carrefour Sequitur',
        area: 'Bebidas',
        cantidadProductos: 25,
        inicio: fin,
        fin: fin2,
      );

      expect(repo.guardarRegistroCallCount, equals(2));
      expect(vm.registros.length, equals(2));
      expect(vm.kpiHorasHoy, equals('3h 0m'));
      expect(vm.isSavingSesion, isFalse);
    });

    test('STRESS-R5-VM-02: 100 parallel calls to guardarLote via Future.wait', () async {
      final repo = FakeOtsRepository(useSeedData: true)
        ..simulateDelay = const Duration(milliseconds: 30);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final initialLotesCount = vm.lotes.length;

      // Fire 100 concurrent guardarLote requests
      final burstFutures = List.generate(
        100,
        (i) => vm.guardarLote(
          Lote.crear(
            supermercado: 'Jumbo Burst $i',
            area: 'Góndola $i',
            cantidadProductos: 50,
          ),
        ),
      );

      await Future.wait(burstFutures);

      // Repository must have processed only 1 call
      expect(repo.guardarLoteCallCount, equals(1));
      expect(vm.lotes.length, equals(initialLotesCount + 1));
      expect(vm.isSavingLote, isFalse);

      // Subsequent call after burst succeeds immediately
      await vm.guardarLote(
        Lote.crear(supermercado: 'Día Post-Burst', area: 'Perfumería'),
      );
      expect(repo.guardarLoteCallCount, equals(2));
      expect(vm.lotes.length, equals(initialLotesCount + 2));
      expect(vm.isSavingLote, isFalse);
    });

    test('STRESS-R5-VM-03: Bi-directional concurrent storm (50 sesion + 50 lote simultaneous calls)', () async {
      final repo = FakeOtsRepository(useSeedData: true)
        ..simulateDelay = const Duration(milliseconds: 25);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final now = DateTime.now();
      final inicio = DateTime(now.year, now.month, now.day, 14, 0);
      final fin = DateTime(now.year, now.month, now.day, 15, 30); // 1h 30m

      final List<Future<void>> mixedCalls = [];

      // Interleave 50 sesion calls and 50 lote calls = 100 total concurrent calls
      for (int i = 0; i < 50; i++) {
        mixedCalls.add(
          vm.guardarSesionFotos(
            loteId: 'lote_1',
            supermercado: 'Super Interleaved $i',
            area: 'Lácteos',
            cantidadProductos: 10,
            inicio: inicio,
            fin: fin,
          ),
        );
        mixedCalls.add(
          vm.guardarLote(
            Lote.crear(
              supermercado: 'Lote Interleaved $i',
              area: 'Limpieza',
            ),
          ),
        );
      }

      await Future.wait(mixedCalls);

      // Exactly 1 sesion save and exactly 1 lote save
      expect(repo.guardarRegistroCallCount, equals(1),
          reason: 'Sesion mutex must isolate sesion writes to exactly 1');
      expect(repo.guardarLoteCallCount, equals(1),
          reason: 'Lote mutex must isolate lote writes to exactly 1');

      // Both mutex flags are cleanly released
      expect(vm.isSavingSesion, isFalse);
      expect(vm.isSavingLote, isFalse);

      // KPI check: exactly 1h 30m
      expect(vm.kpiHorasHoy, equals('1h 30m'));
    });

    test('STRESS-R5-VM-04: Asynchronous packet jitter (100 staggered microsecond calls) drops duplicates', () async {
      final repo = FakeOtsRepository(useSeedData: true)
        ..simulateDelay = const Duration(milliseconds: 40);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final now = DateTime.now();
      final inicio = DateTime(now.year, now.month, now.day, 9, 0);
      final fin = DateTime(now.year, now.month, now.day, 10, 0);

      // Stagger 100 calls across microsecond intervals (0ms, 1ms, 2ms, etc. up to 15ms)
      // All occur while call 0 is awaiting the 40ms repository save
      final jitterFutures = List.generate(100, (i) async {
        if (i > 0) {
          await Future.delayed(Duration(milliseconds: i % 15));
        }
        return vm.guardarSesionFotos(
          loteId: 'lote_1',
          supermercado: 'Jitter Super $i',
          area: 'Sector $i',
          cantidadProductos: 5,
          inicio: inicio,
          fin: fin,
        );
      });

      await Future.wait(jitterFutures);

      expect(repo.guardarRegistroCallCount, equals(1),
          reason: 'Jittered in-flight calls must all be intercepted by the active mutex');
      expect(vm.registros.length, equals(1));
      expect(vm.kpiHorasHoy, equals('1h 0m'));
      expect(vm.isSavingSesion, isFalse);
    });
  });

  // =========================================================================
  // Group 2: Deadlock Immunity & Fault Tolerance Under Injected Exceptions
  // =========================================================================
  group('Adversarial Group 2: Deadlock Immunity & Exception Recovery', () {
    test('STRESS-R5-FAULT-01: 50 concurrent calls during repository crash must release lock with zero deadlock', () async {
      final repo = FakeOtsRepository(useSeedData: true)
        ..simulateDelay = const Duration(milliseconds: 20);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      // Trigger repository failure
      repo.simulateFailOnGuardarRegistro = true;

      final now = DateTime.now();
      final inicio = DateTime(now.year, now.month, now.day, 8, 0);
      final fin = DateTime(now.year, now.month, now.day, 9, 0);

      int exceptionCount = 0;
      int completedNormallyCount = 0;

      // Dispatch 50 concurrent calls
      await Future.wait(
        List.generate(50, (i) async {
          try {
            await vm.guardarSesionFotos(
              loteId: 'lote_1',
              supermercado: 'Fail Super $i',
              area: 'Sector $i',
              cantidadProductos: 10,
              inicio: inicio,
              fin: fin,
            );
            completedNormallyCount++;
          } catch (e) {
            if (e is FirebaseException) {
              exceptionCount++;
            } else {
              rethrow;
            }
          }
        }),
      );

      // The executing call failed, while the other 49 were dropped by the mutex guard
      expect(exceptionCount, equals(1),
          reason: 'The single active call received the FirebaseException');
      expect(completedNormallyCount, equals(49),
          reason: 'The 49 dropped calls completed without entering the failing repository');

      // Crucial: Mutex must NOT deadlock
      expect(vm.isSavingSesion, isFalse,
          reason: 'Mutex must be released in finally block even after uncaught exception');
      expect(vm.registros.isEmpty, isTrue);

      // Recovery verification: with repo back online, launch another 50 concurrent calls
      repo.simulateFailOnGuardarRegistro = false;

      await Future.wait(
        List.generate(50, (i) => vm.guardarSesionFotos(
          loteId: 'lote_1',
          supermercado: 'Recovered Super $i',
          area: 'Sector $i',
          cantidadProductos: 10,
          inicio: inicio,
          fin: fin,
        )),
      );

      expect(repo.guardarRegistroCallCount, equals(2)); // 1 failed + 1 succeeded
      expect(vm.registros.length, equals(1));
      expect(vm.kpiHorasHoy, equals('1h 0m'));
      expect(vm.isSavingSesion, isFalse);
    });

    test('STRESS-R5-FAULT-02: 50 concurrent guardarLote calls during repository crash release lock without deadlock', () async {
      final repo = FakeOtsRepository(useSeedData: true)
        ..simulateDelay = const Duration(milliseconds: 20);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      repo.simulateFailOnGuardarLote = true;

      int exceptionCount = 0;
      int completedNormallyCount = 0;

      await Future.wait(
        List.generate(50, (i) async {
          try {
            await vm.guardarLote(
              Lote.crear(supermercado: 'Fail Lote $i', area: 'Sector $i'),
            );
            completedNormallyCount++;
          } catch (e) {
            if (e is FirebaseException) {
              exceptionCount++;
            } else {
              rethrow;
            }
          }
        }),
      );

      expect(exceptionCount, equals(1));
      expect(completedNormallyCount, equals(49));
      expect(vm.isSavingLote, isFalse, reason: 'Mutex must be released after exception');

      // Recover repository and run another 50 concurrent calls
      repo.simulateFailOnGuardarLote = false;
      await Future.wait(
        List.generate(50, (i) => vm.guardarLote(
          Lote.crear(supermercado: 'Recovered Lote $i', area: 'Sector $i'),
        )),
      );

      expect(repo.guardarLoteCallCount, equals(2)); // 1 failed + 1 succeeded
      expect(vm.isSavingLote, isFalse);
    });

    test('STRESS-R5-FAULT-03: Multi-wave alternating storm (Success -> Fail -> Success -> Fail -> Success)', () async {
      final repo = FakeOtsRepository(useSeedData: true)
        ..simulateDelay = const Duration(milliseconds: 15);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final now = DateTime.now();

      for (int wave = 0; wave < 5; wave++) {
        final shouldFail = wave % 2 == 1; // Waves 1 and 3 fail
        repo.simulateFailOnGuardarRegistro = shouldFail;

        final inicio = DateTime(now.year, now.month, now.day, 10 + wave, 0);
        final fin = inicio.add(const Duration(minutes: 30));

        await Future.wait(
          List.generate(20, (i) async {
            try {
              await vm.guardarSesionFotos(
                loteId: 'lote_1',
                supermercado: 'Wave $wave Super $i',
                area: 'Sector',
                cantidadProductos: 5,
                inicio: inicio,
                fin: fin,
              );
            } catch (_) {
              // Expected on failing waves
            }
          }),
        );

        expect(vm.isSavingSesion, isFalse,
            reason: 'Lock must always be released at the conclusion of wave $wave');
      }

      // 3 successful waves * 1 save per wave = 3 records
      expect(vm.registros.length, equals(3));
      // 3 sessions of 30 min = 90 min = '1h 30m'
      expect(vm.kpiHorasHoy, equals('1h 30m'));
    });

    test('STRESS-R5-FAULT-04: Synchronous ArgumentError inside guardarSesionFotos releases mutex immediately', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final now = DateTime.now();
      // fin is before inicio -> triggers synchronous ArgumentError inside RegistroTrabajo.crear
      final inicio = DateTime(now.year, now.month, now.day, 10, 0);
      final finInvalido = DateTime(now.year, now.month, now.day, 9, 0);

      expect(
        () => vm.guardarSesionFotos(
          loteId: 'lote_1',
          supermercado: 'Coto',
          area: 'Bebidas',
          cantidadProductos: 10,
          inicio: inicio,
          fin: finInvalido,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Mutex must NOT be left hanging at true
      expect(vm.isSavingSesion, isFalse,
          reason: 'Synchronous ArgumentError must still trigger finally and reset _isSavingSesion');

      // Subsequent valid call succeeds without issue
      await vm.guardarSesionFotos(
        loteId: 'lote_1',
        supermercado: 'Coto',
        area: 'Bebidas',
        cantidadProductos: 10,
        inicio: inicio,
        fin: inicio.add(const Duration(hours: 1)),
      );

      expect(repo.guardarRegistroCallCount, equals(1));
      expect(vm.registros.length, equals(1));
    });

    test('STRESS-R5-FAULT-05: Race condition between cancelarSesionActiva and guardarSesionFotos', () async {
      final repo = FakeOtsRepository(useSeedData: true)
        ..simulateDelay = const Duration(milliseconds: 30);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final now = DateTime.now();
      final lote = vm.lotes.first;
      await vm.iniciarFotos(lote);

      // Concurrently call guardarSesionFotos and cancelarSesionActiva
      await Future.wait([
        vm.guardarSesionFotos(
          loteId: lote.id,
          supermercado: lote.supermercado,
          area: lote.area,
          cantidadProductos: lote.cantidadProductos,
          inicio: now.subtract(const Duration(minutes: 45)),
          fin: now,
        ),
        vm.cancelarSesionActiva(),
      ]);

      // System remains healthy, sesionActiva is cleaned up, no deadlock
      expect(vm.isSavingSesion, isFalse);
      expect(vm.sesionActiva, isNull);
    });
  });

  // =========================================================================
  // Group 3: Widget Multi-Tap Stress Testing (ModalSesionSheet & ModalLoteSheet)
  // =========================================================================
  group('Adversarial Group 3: Widget Multi-Tap Stress Testing', () {
    testWidgets('STRESS-R5-UI-01: 50 rapid sequential taps on submit button in ModalSesionSheet', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_stress_01').build();
      final completer = Completer<void>();
      int onGuardarCallCount = 0;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: DateTime(2026, 11, 12, 10, 0),
          fin: DateTime(2026, 11, 12, 11, 0),
          onGuardar: ({
            required loteId,
            required supermercado,
            required area,
            required cantidadProductos,
            required inicio,
            required fin,
            observaciones,
          }) {
            onGuardarCallCount++;
            return completer.future;
          },
        ),
      );

      // Initial tap triggers submit
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump(); // Deliver event and enter _isSubmitting = true

      expect(onGuardarCallCount, equals(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Spam 50 taps rapidly on the loading submit button (warnIfMissed: false because button is disabled)
      for (int i = 0; i < 50; i++) {
        await tester.tap(find.byType(CircularProgressIndicator), warnIfMissed: false);
        await tester.pump();
      }

      // Assert zero duplicate invocations
      expect(onGuardarCallCount, equals(1),
          reason: 'All 50 multi-taps must be strictly dropped while submission is pending');

      // Complete async save
      completer.complete();
      await tester.pumpAndSettle();

      // Modal closed, total invocations strictly 1
      expect(onGuardarCallCount, equals(1));
      expect(find.byType(ModalSesionSheet), findsNothing);
    });

    testWidgets('STRESS-R5-UI-02: Multi-tap on peripheral controls during submission in ModalSesionSheet', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_stress_02').build();
      final completer = Completer<void>();
      int onGuardarCallCount = 0;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: DateTime(2026, 11, 12, 10, 0),
          fin: DateTime(2026, 11, 12, 11, 0),
          onGuardar: ({
            required loteId,
            required supermercado,
            required area,
            required cantidadProductos,
            required inicio,
            required fin,
            observaciones,
          }) {
            onGuardarCallCount++;
            return completer.future;
          },
        ),
      );

      // Submit
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      // Tapping Cancelar while submitting must be ignored (button disabled)
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'), warnIfMissed: false);
      await tester.pump();

      // Tapping Close icon while submitting must be ignored
      await tester.tap(find.widgetWithIcon(IconButton, Icons.close), warnIfMissed: false);
      await tester.pump();

      // Tapping quick chip (+30 min) while submitting must be ignored
      await tester.tap(find.widgetWithText(OutlinedButton, '+30 min'), warnIfMissed: false);
      await tester.pump();

      // Modal still mounted, single onGuardar call
      expect(find.byType(ModalSesionSheet), findsOneWidget);
      expect(onGuardarCallCount, equals(1));

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ModalSesionSheet), findsNothing);
    });

    testWidgets('STRESS-R5-UI-03: 50 rapid sequential taps on submit button in ModalLoteSheet', (tester) async {
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

      await tester.enterText(find.widgetWithText(TextField, 'Supermercado *'), 'Carrefour Stress');
      await tester.enterText(find.widgetWithText(TextField, 'Área / Sector *'), 'Bebidas');
      await tester.pump();

      // First tap
      await tester.tap(find.text('Crear Lote'));
      await tester.pump();

      expect(callCount, equals(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 50 rapid taps on spinner
      for (int i = 0; i < 50; i++) {
        await tester.tap(find.byType(CircularProgressIndicator), warnIfMissed: false);
        await tester.pump();
      }

      expect(callCount, equals(1), reason: 'Multi-taps must be dropped completely in ModalLoteSheet');

      completer.complete();
      await tester.pumpAndSettle();

      expect(callCount, equals(1));
      expect(find.byType(ModalLoteSheet), findsNothing);
    });

    testWidgets('STRESS-R5-UI-04: Multi-tap across error-recovery cycles in ModalSesionSheet', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_stress_03').build();
      int callAttempts = 0;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: DateTime(2026, 11, 12, 10, 0),
          fin: DateTime(2026, 11, 12, 11, 0),
          onGuardar: ({
            required loteId,
            required supermercado,
            required area,
            required cantidadProductos,
            required inicio,
            required fin,
            observaciones,
          }) async {
            callAttempts++;
            if (callAttempts == 1) {
              await Future.delayed(const Duration(milliseconds: 20));
              throw Exception('Simulated network timeout');
            }
            await Future.delayed(const Duration(milliseconds: 20));
          },
        ),
      );

      // Wave 1: First tap starts failing attempt
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      // Rapidly tap 20 times while wave 1 is processing
      for (int i = 0; i < 20; i++) {
        if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
          await tester.tap(find.byType(CircularProgressIndicator), warnIfMissed: false);
        }
        await tester.pump(const Duration(milliseconds: 2));
      }

      await tester.pumpAndSettle();

      // Only attempt 1 occurred and failed
      expect(callAttempts, equals(1));
      expect(find.textContaining('Error al guardar la sesión'), findsOneWidget);
      expect(find.byType(ModalSesionSheet), findsOneWidget); // Modal preserved

      // Wave 2: Tap to retry (should succeed)
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();

      // Rapidly tap 20 times while wave 2 is processing
      for (int i = 0; i < 20; i++) {
        if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
          await tester.tap(find.byType(CircularProgressIndicator), warnIfMissed: false);
        }
        await tester.pump(const Duration(milliseconds: 2));
      }

      await tester.pumpAndSettle();

      // Total attempts must be exactly 2 (1 failed + 1 succeeded)
      expect(callAttempts, equals(2));
      expect(find.byType(ModalSesionSheet), findsNothing); // Successfully dismissed
    });

    testWidgets('STRESS-R5-UI-05: Multi-tap across error-recovery cycles in ModalLoteSheet', (tester) async {
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

      int callAttempts = 0;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          onGuardar: (lote) async {
            callAttempts++;
            if (callAttempts == 1) {
              await Future.delayed(const Duration(milliseconds: 20));
              throw Exception('Firestore write aborted');
            }
            await Future.delayed(const Duration(milliseconds: 20));
          },
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Supermercado *'), 'Vea MultiTap');
      await tester.enterText(find.widgetWithText(TextField, 'Área / Sector *'), 'Panadería');
      await tester.pump();

      // Wave 1: First tap
      await tester.tap(find.text('Crear Lote'));
      await tester.pump();

      for (int i = 0; i < 20; i++) {
        if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
          await tester.tap(find.byType(CircularProgressIndicator), warnIfMissed: false);
        }
        await tester.pump(const Duration(milliseconds: 2));
      }

      await tester.pumpAndSettle();

      expect(callAttempts, equals(1));
      expect(find.textContaining('Error al guardar el lote'), findsOneWidget);
      expect(find.byType(ModalLoteSheet), findsOneWidget);

      // Wave 2: Retry
      await tester.tap(find.text('Crear Lote'));
      await tester.pump();

      for (int i = 0; i < 20; i++) {
        if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
          await tester.tap(find.byType(CircularProgressIndicator), warnIfMissed: false);
        }
        await tester.pump(const Duration(milliseconds: 2));
      }

      await tester.pumpAndSettle();

      expect(callAttempts, equals(2));
      expect(find.byType(ModalLoteSheet), findsNothing);
    });
  });

  // =========================================================================
  // Group 4: KPI Horas Invariant Under High Concurrency
  // =========================================================================
  group('Adversarial Group 4: KPI Horas Invariant Under High Concurrency', () {
    test('STRESS-R5-KPI-01: High-concurrency storm (100 parallel calls) never inflates kpiHorasHoy', () async {
      final repo = FakeOtsRepository(useSeedData: true)
        ..simulateDelay = const Duration(milliseconds: 25);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final now = DateTime.now();
      // Exactly 1 hour session: 11:00 to 12:00
      final inicio = DateTime(now.year, now.month, now.day, 11, 0);
      final fin = DateTime(now.year, now.month, now.day, 12, 0);

      // Launch 100 concurrent requests with the same session duration
      await Future.wait(
        List.generate(
          100,
          (i) => vm.guardarSesionFotos(
            loteId: 'lote_1',
            supermercado: 'Super Coto',
            area: 'Lácteos',
            cantidadProductos: 30,
            inicio: inicio,
            fin: fin,
          ),
        ),
      );

      // Under bugged behavior, 100 calls would sum 100 hours ('100h 0m')
      // Under idempotent mutex, only 1 record is created: exactly '1h 0m'
      expect(vm.kpiHorasHoy, equals('1h 0m'));
      expect(vm.registros.length, equals(1));

      // Launch another 100 concurrent requests for an additional 45 min session
      final inicio2 = DateTime(now.year, now.month, now.day, 14, 0);
      final fin2 = DateTime(now.year, now.month, now.day, 14, 45); // 45 min

      await Future.wait(
        List.generate(
          100,
          (i) => vm.guardarSesionFotos(
            loteId: 'lote_2',
            supermercado: 'Carrefour Express',
            area: 'Almacén',
            cantidadProductos: 15,
            inicio: inicio2,
            fin: fin2,
          ),
        ),
      );

      // 1h 0m + 45m = '1h 45m', NOT '76h 0m'
      expect(vm.kpiHorasHoy, equals('1h 45m'));
      expect(vm.registros.length, equals(2));
      expect(repo.guardarRegistroCallCount, equals(2));
    });

    test('STRESS-R5-KPI-02: Date isolation - sessions from prior days do not contaminate kpiHorasHoy under burst', () async {
      final repo = FakeOtsRepository(useSeedData: true)
        ..simulateDelay = const Duration(milliseconds: 20);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final inicioYesterday = DateTime(yesterday.year, yesterday.month, yesterday.day, 10, 0);
      final finYesterday = DateTime(yesterday.year, yesterday.month, yesterday.day, 13, 0); // 3 hours

      // Burst 50 calls for yesterday's session
      await Future.wait(
        List.generate(
          50,
          (i) => vm.guardarSesionFotos(
            loteId: 'lote_1',
            supermercado: 'Ayer Super',
            area: 'Sector',
            cantidadProductos: 20,
            inicio: inicioYesterday,
            fin: finYesterday,
          ),
        ),
      );

      // Yesterday's session should NOT appear in kpiHorasHoy
      expect(vm.kpiHorasHoy, equals('0h 0m'));
      expect(vm.registros.length, equals(1));

      // Burst 50 calls for today's session (1h 15m)
      final inicioToday = DateTime(now.year, now.month, now.day, 9, 0);
      final finToday = DateTime(now.year, now.month, now.day, 10, 15);

      await Future.wait(
        List.generate(
          50,
          (i) => vm.guardarSesionFotos(
            loteId: 'lote_2',
            supermercado: 'Hoy Super',
            area: 'Sector',
            cantidadProductos: 20,
            inicio: inicioToday,
            fin: finToday,
          ),
        ),
      );

      // kpiHorasHoy must strictly report today's session ('1h 15m')
      expect(vm.kpiHorasHoy, equals('1h 15m'));
      expect(vm.registros.length, equals(2));
    });
  });
}
