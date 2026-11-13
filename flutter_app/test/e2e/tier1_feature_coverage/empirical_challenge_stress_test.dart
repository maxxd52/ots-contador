import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter_app/data/datasources/seed_data.dart';
import 'package:flutter_app/data/repositories/ots_repository.dart';
import 'package:flutter_app/domain/logic/time_calculator.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/domain/models/registro_trabajo.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import 'package:flutter_app/ui/views/modal_lote_sheet.dart';
import 'package:flutter_app/ui/views/modal_sesion_sheet.dart';
import '../harness/harness.dart';

/// Empirical Challenger Adversarial & Stress Harness for Tier 1 Feature Coverage
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockSharedPreferencesHelper.setEmpty();
  });

  group('Adversarial Oracle Probes: Verifying Oracles Fail on Inverted/Broken Logic', () {
    // ------------------------------------------------------------------------
    // R1 Adversarial Probes
    // ------------------------------------------------------------------------
    test('PROBE-R1-01: Oracle rejects missing isLoading reset on error', () async {
      final fakeRepo = FakeOtsRepository();
      fakeRepo.simulateFailOnObtenerLotes = true;
      final vm = TableroViewModel(repository: fakeRepo);
      addTearDown(vm.dispose);

      await vm.inicializar();

      // Mutation test: if someone asserts isLoading is true, it MUST fail
      expect(() => expect(vm.isLoading, isTrue), throwsA(isA<TestFailure>()));
      // Real oracle MUST pass
      expect(vm.isLoading, isFalse);
    });

    test('PROBE-R1-02: Oracle rejects online status when repository throws network error', () async {
      final fakeRepo = FakeOtsRepository();
      fakeRepo.simulateNetworkError = true;
      final vm = TableroViewModel(repository: fakeRepo);
      addTearDown(vm.dispose);

      await vm.inicializar();

      // Mutation test: if someone asserts isOffline is false, it MUST fail
      expect(() => expect(vm.isOffline, isFalse), throwsA(isA<TestFailure>()));
      expect(vm.isOffline, isTrue);
      expect(vm.lotes.length, equals(SeedData.obtenerLotesIniciales().length));
    });

    // ------------------------------------------------------------------------
    // R2 Adversarial Probes
    // ------------------------------------------------------------------------
    test('PROBE-R2-01: Oracle rejects non-+120 days unlock date calculation', () async {
      final repo = FakeOtsRepository(
        initialLotes: [
          LoteBuilder().withId('lote_probe_r2').withSupermercado('Coto').withArea('Fiambrería').build(),
        ],
      );

      final inicio = DateTime(2026, 11, 12, 10, 0);
      final fin = DateTime(2026, 11, 12, 11, 0);
      final registro = RegistroTrabajoBuilder()
          .withId('reg_probe_r2')
          .withLoteId('lote_probe_r2')
          .withSupermercado('Coto')
          .withArea('Fiambrería')
          .withInicio(inicio)
          .withFin(fin)
          .build();

      await repo.guardarRegistro(registro);
      final updated = repo.lotes.firstWhere((l) => l.id == 'lote_probe_r2');

      // Mutant 1: +119 days must fail
      final wrongUnlock119 = inicio.add(const Duration(days: 119));
      expect(() => expect(updated.proximoDesbloqueo, equals(wrongUnlock119)), throwsA(isA<TestFailure>()));

      // Mutant 2: +121 days must fail
      final wrongUnlock121 = inicio.add(const Duration(days: 121));
      expect(() => expect(updated.proximoDesbloqueo, equals(wrongUnlock121)), throwsA(isA<TestFailure>()));

      // Truth oracle: exact +120 calendar days
      expect(updated.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(inicio)));
      expect(repo.atomicBatchesCommitted, equals(1));
    });

    test('PROBE-R2-02: Active session purge oracle rejects lingering preferences', () async {
      final repo = FakeOtsRepository(
        initialLotes: [LoteBuilder.habilitado(id: 'lote_purge_probe').build()],
      );
      await repo.guardarSesionActiva({
        'loteId': 'lote_purge_probe',
        'inicio': '2026-11-12T10:00:00.000Z',
      });

      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();
      expect(vm.sesionActiva, isNotNull);

      await vm.guardarSesionFotos(
        loteId: 'lote_purge_probe',
        supermercado: 'Super',
        area: 'Area',
        cantidadProductos: 10,
        inicio: DateTime(2026, 11, 12, 10, 0),
        fin: DateTime(2026, 11, 12, 10, 30),
      );

      // Mutant: assert session is NOT null must fail
      expect(() => expect(vm.sesionActiva, isNotNull), throwsA(isA<TestFailure>()));
      expect(vm.sesionActiva, isNull);
      expect(await repo.obtenerSesionActiva(), isNull);
    });

    // ------------------------------------------------------------------------
    // R3 Adversarial Probes
    // ------------------------------------------------------------------------
    test('PROBE-R3-01: Domain model strictly rejects fin.isBefore(inicio) with ArgumentError', () {
      final inicio = DateTime(2026, 11, 12, 10, 0);
      final invalidFin = DateTime(2026, 11, 12, 9, 59, 59);

      // Verify domain invariant
      expect(
        () => RegistroTrabajo.crear(
          loteId: 'lote_inv',
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

      // Mutant: assert it does NOT throw must fail
      expect(
        () => expect(
          () => RegistroTrabajo.crear(
            loteId: 'lote_inv',
            supermercado: 'Super',
            area: 'Area',
            inicio: inicio,
            fin: invalidFin,
          ),
          returnsNormally,
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    testWidgets('PROBE-R3-02: ModalSesionSheet initState sanitizes inverted fin', (tester) async {
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

      final lote = LoteBuilder.habilitado(id: 'lote_san').build();
      final inicio = DateTime(2026, 11, 12, 10, 0);
      final invertedFin = DateTime(2026, 11, 12, 8, 0);
      DateTime? receivedFin;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          fin: invertedFin,
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            receivedFin = fin;
          },
        ),
      );

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      // Inverted date 08:00 MUST NOT be submitted
      expect(() => expect(receivedFin, equals(invertedFin)), throwsA(isA<TestFailure>()));
      // Sanitized date (10:45) must be submitted
      expect(receivedFin, equals(inicio.add(const Duration(minutes: 45))));
    });

    // ------------------------------------------------------------------------
    // R4 Adversarial Probes
    // ------------------------------------------------------------------------
    test('PROBE-R4-01: Lote.copyWith recalculates proximoDesbloqueo whenever ultimoInicio is updated', () {
      final initialDate = DateTime(2026, 1, 1, 10, 0);
      final lote = LoteBuilder().withUltimoInicio(initialDate, autoCalculateDesbloqueo: true).build();

      final newDate = DateTime(2026, 5, 1, 10, 0);
      final updated = lote.copyWith(ultimoInicio: newDate);

      // Mutant: assert unlock date stayed at initial must fail
      expect(() => expect(updated.proximoDesbloqueo, equals(lote.proximoDesbloqueo)), throwsA(isA<TestFailure>()));
      // Truth: unlock date must equal newDate + 120 days
      expect(updated.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(newDate)));
    });

    testWidgets('PROBE-R4-02: ModalLoteSheet clear button sets both dates to null', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Lote? saved;
      final initial = LoteBuilder().withUltimoInicio(DateTime(2026, 6, 1), autoCalculateDesbloqueo: true).build();

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          loteParaEditar: initial,
          onGuardar: (l) => saved = l,
        ),
      );

      // Tap clear icon
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.ultimoInicio, isNull);
      expect(saved!.proximoDesbloqueo, isNull);
      // Mutant: assert proximoDesbloqueo is not null must fail
      expect(() => expect(saved!.proximoDesbloqueo, isNotNull), throwsA(isA<TestFailure>()));
    });

    // ------------------------------------------------------------------------
    // R5 Adversarial Probes
    // ------------------------------------------------------------------------
    test('PROBE-R5-01: Upsert idempotency rejects duplicate entry creation', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      final initialCount = vm.lotes.length;
      final target = vm.lotes.first;

      // Repeat same save 3 times
      for (int i = 0; i < 3; i++) {
        await vm.guardarLote(target.copyWith(cantidadProductos: 100 + i));
      }

      // Mutant: assert lot count grew must fail
      expect(() => expect(vm.lotes.length, greaterThan(initialCount)), throwsA(isA<TestFailure>()));
      // Truth: exactly initialCount
      expect(vm.lotes.length, equals(initialCount));
      expect(vm.lotes.firstWhere((l) => l.id == target.id).cantidadProductos, equals(102));
    });

    // ------------------------------------------------------------------------
    // R6 Adversarial Probes
    // ------------------------------------------------------------------------
    test('PROBE-R6-01: Static CEL security rules reject open delete on registros', () {
      final rulesFile = File('firestore.rules').existsSync() ? File('firestore.rules') : File('../firestore.rules');
      final content = rulesFile.readAsStringSync();

      // Truth: allow delete: if false;
      expect(content, matches(RegExp(r'match /registros_trabajo/\{registroId\}\s*\{[^}]*allow delete:\s*if false;')));

      // Mutant: allow delete: if true or if isAuthenticated must fail
      expect(() => expect(content, matches(RegExp(r'match /registros_trabajo/\{registroId\}\s*\{[^}]*allow delete:\s*if true;'))), throwsA(isA<TestFailure>()));
      expect(() => expect(content, matches(RegExp(r'match /registros_trabajo/\{registroId\}\s*\{[^}]*allow delete:\s*if isAuthenticated\(\);'))), throwsA(isA<TestFailure>()));
    });

    test('PROBE-R6-02: PermissionDenied simulation triggers expected FirebaseException', () async {
      final repo = FakeOtsRepository();
      repo.simulatePermissionDenied = true;

      // Truth: throws permission-denied
      await expectLater(
        () => repo.obtenerLotes(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', equals('permission-denied'))),
      );

      // Mutant: assert returns normally must fail
      expect(
        () => expectLater(() => repo.obtenerLotes(), completes),
        throwsA(isA<TestFailure>()),
      );
    });

    // ------------------------------------------------------------------------
    // R7 Adversarial Probes
    // ------------------------------------------------------------------------
    test('PROBE-R7-01: Malformed and unexpected date types are rejected safely', () {
      expect(TableroViewModel.parsearFechaInicio('corrupted_string'), isNull);
      expect(TableroViewModel.parsearFechaInicio(null), isNull);
      expect(TableroViewModel.parsearFechaInicio(false), isNull);
      expect(TableroViewModel.parsearFechaInicio(<int>[1, 2]), isNull);

      // Mutant: assert corrupted string parses as valid DateTime must fail
      expect(() => expect(TableroViewModel.parsearFechaInicio('corrupted_string'), isNotNull), throwsA(isA<TestFailure>()));
    });

    test('PROBE-R7-02: Corrupted session in SharedPreferences recovers memory state (storage purge gap probed)', () async {
      MockSharedPreferencesHelper.setSessionWithNonJsonString(corruptedPayload: '{{INVALID_JSON:::');

      final repo = LocalOtsRepository();
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      // Memory state safely recovered
      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));

      // Empirical challenger finding:
      // LocalOtsRepository.obtenerSesionActiva() catches FormatException and returns null,
      // but does NOT remove the key from SharedPreferences. Thus, isSessionPurged() is false.
      final isStoragePurged = await MockSharedPreferencesHelper.isSessionPurged();
      expect(isStoragePurged, isFalse, reason: 'LocalOtsRepository swallows FormatException without prefs.remove()');

      // However, when sesion is a Map with corrupted/missing inicio (TEST-R7-T1-02/03),
      // TableroViewModel explicitly triggers repository.limpiarSesionActiva().
      final fakeRepo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {'loteId': 'lote_bad', 'inicio': 'not-a-date'},
      );
      final vm2 = TableroViewModel(repository: fakeRepo);
      addTearDown(vm2.dispose);
      await vm2.inicializar();
      expect(fakeRepo.sesionActiva, isNull, reason: 'TableroViewModel purges corrupted Map session');
    });
  });

  group('Empirical Stress & Boundary Probes: Edge Conditions & Isolation', () {
    test('STRESS-01: Zero-duration session (inicio == fin) is accepted and valid', () {
      final now = DateTime(2026, 11, 12, 14, 0);
      final reg = RegistroTrabajo.crear(
        loteId: 'lote_zero',
        supermercado: 'Super Zero',
        area: 'Check',
        inicio: now,
        fin: now,
      );
      expect(reg.duracionMinutos, equals(0));
      expect(reg.horasDecimales, equals(0.0));
      expect(reg.nuevoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(now)));
    });

    test('STRESS-02: Leap day traversal across 120 days preserves calendar calculation', () {
      // Leap year 2028: February has 29 days
      final leapStart = DateTime(2028, 2, 20, 10, 30);
      final leapUnlock = TimeCalculator.calcularProximoDesbloqueo(leapStart);
      expect(leapUnlock, equals(leapStart.add(const Duration(days: 120))));
      expect(leapUnlock.hour, equals(10));
      expect(leapUnlock.minute, equals(30));
    });

    test('STRESS-03: Future timestamp in active session clamps elapsed seconds to 0', () async {
      final futureStart = DateTime.now().add(const Duration(hours: 2));
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_future',
          'inicio': futureStart.toIso8601String(),
        },
      );
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      expect(vm.segundosTranscurridos, equals(0));
      expect(vm.cronometroTexto, equals('00:00'));
    });

    test('STRESS-04: Hermetic state isolation across rapid dirty-state injections', () async {
      for (int i = 0; i < 5; i++) {
        MockSharedPreferencesHelper.setMockState(
          sesionActiva: {'loteId': 'dirty_$i', 'inicio': 'invalid'},
          rawLotes: 'corrupted_lotes_payload',
        );
        expect(await MockSharedPreferencesHelper.isSessionPurged(), isFalse);

        // Reset must restore pristine hermetic baseline
        MockSharedPreferencesHelper.setEmpty();
        expect(await MockSharedPreferencesHelper.isSessionPurged(), isTrue);
        expect(await MockSharedPreferencesHelper.getRawLotes(), isNull);
      }
    });

    test('STRESS-05: High-frequency sequential batch submissions maintain repo consistency', () async {
      final repo = FakeOtsRepository(
        initialLotes: [
          LoteBuilder().withId('lote_seq').withSupermercado('Carrefour').withArea('Góndola').build(),
        ],
      );

      for (int i = 0; i < 10; i++) {
        final start = DateTime(2026, 11, 12, 8 + i, 0);
        final reg = RegistroTrabajoBuilder()
            .withId('reg_seq_$i')
            .withLoteId('lote_seq')
            .withSupermercado('Carrefour')
            .withArea('Góndola')
            .withInicio(start)
            .withFin(start.add(const Duration(minutes: 30)))
            .build();
        await repo.guardarRegistro(reg);
      }

      expect(repo.guardarRegistroCallCount, equals(10));
      expect(repo.atomicBatchesCommitted, equals(10));
      expect(repo.registros.length, equals(10));
      final updatedLote = repo.lotes.firstWhere((l) => l.id == 'lote_seq');
      expect(updatedLote.ultimoInicio, equals(DateTime(2026, 11, 12, 17, 0)));
    });
  });
}
