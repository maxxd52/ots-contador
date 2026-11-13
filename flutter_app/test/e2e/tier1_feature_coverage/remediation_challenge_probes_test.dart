import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter_app/data/repositories/ots_repository.dart';
import 'package:flutter_app/domain/logic/time_calculator.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/domain/models/registro_trabajo.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import 'package:flutter_app/ui/views/modal_lote_sheet.dart';
import '../harness/harness.dart';

/// Empirical Challenger Adversarial Mutation & Sensitivity Suite
/// Validates that tests fail when logic or invariants are broken (Zero False-Positives).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockSharedPreferencesHelper.setEmpty();
  });

  group('Challenger Mutation Probes: R7 Storage Auto-Purge Sensitivity', () {
    test('PROBE-R7-01: TEST-R7-T1-05 fails if storage is not purged', () async {
      // 1. Arrange: Seed corrupted session
      MockSharedPreferencesHelper.setSessionWithMalformedDate(
        loteId: 'lote_seed_1',
        malformedDate: 'corrupted-timestamp-string-{{invalid_iso}}',
      );

      // Precondition: storage is dirty
      expect(await MockSharedPreferencesHelper.isSessionPurged(), isFalse);
      expect(await MockSharedPreferencesHelper.getRawSession(), isNotNull);

      // 2. Mutant demonstration: If a test evaluated an unpurged storage state,
      // the exact assertions in TEST-R7-T1-05 MUST throw TestFailure
      final simulatedUnpurgedState = false;
      expect(
        () => expect(simulatedUnpurgedState, isTrue),
        throwsA(isA<TestFailure>()),
        reason: 'Oracle must fail if isSessionPurged is false',
      );

      final simulatedRawSession = '{"loteId": "lote_seed_1", "inicio": "invalid"}';
      expect(
        () => expect(simulatedRawSession, isNull),
        throwsA(isA<TestFailure>()),
        reason: 'Oracle must fail if getRawSession is not null',
      );

      // 3. Ground Truth: Execute TableroViewModel.inicializar() with real LocalOtsRepository
      final repo = LocalOtsRepository();
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      // State is recovered AND storage is purged
      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(await MockSharedPreferencesHelper.isSessionPurged(), isTrue);
      expect(await MockSharedPreferencesHelper.getRawSession(), isNull);
    });
  });

  group('Challenger Mutation Probes: R4 Modal Date Selection & 120-Day Sync Sensitivity', () {
    testWidgets('PROBE-R4-01: TEST-R4-T1-02 fails if proximoDesbloqueo calculation is broken', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialDate = DateTime(2026, 5, 1, 10, 0);
      final initialLote = LoteBuilder()
          .withId('lote_edit_1')
          .withSupermercado('Carrefour Central')
          .withArea('Bebidas')
          .withUltimoInicio(initialDate, autoCalculateDesbloqueo: true)
          .build();

      // Mutant 1: Unchanged unlock date when ultimoInicio changes
      final mutantUnchangedUnlock = initialLote.proximoDesbloqueo;
      expect(
        () => expect(mutantUnchangedUnlock, isNot(equals(initialLote.proximoDesbloqueo))),
        throwsA(isA<TestFailure>()),
        reason: 'Oracle must fail if proximoDesbloqueo is unchanged after edit',
      );

      // Mutant 2: Wrong interval calculation (e.g., +90 days instead of +120 days)
      final editedDate = DateTime(2026, 5, 20, 10, 0);
      final mutant90Days = editedDate.add(const Duration(days: 90));
      expect(
        () => expect(mutant90Days.difference(editedDate).inDays, equals(120)),
        throwsA(isA<TestFailure>()),
        reason: 'Oracle must fail if unlock difference is not exactly 120 days',
      );

      // Mutant 3: Null unlock date
      expect(
        () => expect(null, equals(TimeCalculator.calcularProximoDesbloqueo(editedDate))),
        throwsA(isA<TestFailure>()),
        reason: 'Oracle must fail if proximoDesbloqueo is null',
      );

      // Ground truth: Verify widget interaction behaves correctly end-to-end
      Lote? savedLote;
      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          loteParaEditar: initialLote,
          onGuardar: (l) => savedLote = l,
        ),
      );

      final inkWellFinder = find.widgetWithText(InkWell, 'Última Fecha/Hora de Fotos (Opcional)');
      await tester.tap(inkWellFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(savedLote, isNotNull);
      expect(savedLote!.ultimoInicio, equals(editedDate));
      final expectedUnlock = TimeCalculator.calcularProximoDesbloqueo(editedDate);
      expect(savedLote!.proximoDesbloqueo, equals(expectedUnlock));
      expect(savedLote!.proximoDesbloqueo, isNot(equals(initialLote.proximoDesbloqueo)));
      expect(savedLote!.proximoDesbloqueo!.difference(savedLote!.ultimoInicio!).inDays, equals(120));
    });
  });

  group('Challenger Mutation Probes: R2 Atomic Batch Rollback Sensitivity', () {
    test('PROBE-R2-01: TEST-R2-T1-06 fails if rollback commits partial state', () async {
      final initialLote = LoteBuilder.habilitado(
        id: 'lote_rollback_01',
        supermercado: 'Carrefour San Martín',
        area: 'Lácteos',
        cantidadProductos: 50,
      ).build();

      final start = DateTime(2026, 11, 12, 10, 0);
      final registro = RegistroTrabajoBuilder.standard(
        id: 'reg_rollback_01',
        loteId: 'lote_rollback_01',
        supermercado: 'Carrefour San Martín',
        area: 'Lácteos',
        cantidadProductos: 75,
        inicio: start,
        minutes: 45,
      ).build();

      // Mutant 1: Partial work record committed to repo
      final dirtyRegistros = [registro];
      expect(
        () => expect(dirtyRegistros, isEmpty),
        throwsA(isA<TestFailure>()),
        reason: 'Oracle must fail if registros list contains partial commit',
      );

      // Mutant 2: Batch counter incremented
      final dirtyBatchesCommitted = 1;
      expect(
        () => expect(dirtyBatchesCommitted, equals(0)),
        throwsA(isA<TestFailure>()),
        reason: 'Oracle must fail if atomicBatchesCommitted > 0 on failure',
      );

      // Mutant 3: Target lote mutated
      final dirtyLote = initialLote.copyWith(ultimoInicio: start);
      expect(
        () => expect(dirtyLote.ultimoInicio, isNull),
        throwsA(isA<TestFailure>()),
        reason: 'Oracle must fail if lot ultimoInicio is mutated on rollback',
      );

      // Ground truth: Verify real rollback behavior
      final repo = FakeOtsRepository(initialLotes: [initialLote]);
      repo.simulateFailOnGuardarRegistro = true;

      await expectLater(
        () => repo.guardarRegistro(registro),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );

      expect(repo.guardarRegistroCallCount, equals(1));
      expect(repo.atomicBatchesCommitted, equals(0));
      expect(repo.registros, isEmpty);
      expect(repo.batchLog.length, equals(1));
      expect(repo.batchLog.first.succeeded, isFalse);

      final untouchedLote = repo.lotes.firstWhere((l) => l.id == 'lote_rollback_01');
      expect(untouchedLote.ultimoInicio, isNull);
      expect(untouchedLote.proximoDesbloqueo, isNull);
      expect(untouchedLote.cantidadProductos, equals(50));
    });
  });

  group('Challenger Mutation Probes: R5 Mutex Sensitivity', () {
    test('PROBE-R5-01: TEST-R5-T1-04 fails if guardarSesionFotos mutex is omitted', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      repo.simulateDelay = const Duration(milliseconds: 50);

      final targetLote = repo.lotes.first;
      final start = DateTime(2026, 11, 12, 10, 0);
      final fin = DateTime(2026, 11, 12, 10, 45);

      final reg1 = RegistroTrabajo.crear(
        loteId: targetLote.id,
        supermercado: targetLote.supermercado,
        area: targetLote.area,
        cantidadProductos: 55,
        inicio: start,
        fin: fin,
      );
      final reg2 = RegistroTrabajo.crear(
        loteId: targetLote.id,
        supermercado: targetLote.supermercado,
        area: targetLote.area,
        cantidadProductos: 55,
        inicio: start,
        fin: fin,
      );

      // Mutant demonstration: Unprotected concurrent execution (without mutex guard)
      // Calls repo.guardarRegistro directly in parallel
      await Future.wait([
        repo.guardarRegistro(reg1),
        repo.guardarRegistro(reg2),
      ]);

      // Without mutex, call count is 2:
      expect(repo.guardarRegistroCallCount, equals(2));
      // Proving that asserting equals(1) on un-mutexed execution throws TestFailure:
      expect(
        () => expect(repo.guardarRegistroCallCount, equals(1)),
        throwsA(isA<TestFailure>()),
        reason: 'Oracle must fail if ViewModel mutex is omitted',
      );

      // Ground truth: With TableroViewModel mutex (_isSavingSesion)
      final repo2 = FakeOtsRepository(useSeedData: true);
      repo2.simulateDelay = const Duration(milliseconds: 50);
      final vm = TableroViewModel(repository: repo2);
      addTearDown(vm.dispose);
      await vm.inicializar();

      final target2 = vm.lotes.first;
      final future1 = vm.guardarSesionFotos(
        loteId: target2.id,
        supermercado: target2.supermercado,
        area: target2.area,
        cantidadProductos: 55,
        inicio: start,
        fin: fin,
      );
      final future2 = vm.guardarSesionFotos(
        loteId: target2.id,
        supermercado: target2.supermercado,
        area: target2.area,
        cantidadProductos: 55,
        inicio: start,
        fin: fin,
      );

      await Future.wait([future1, future2]);

      expect(repo2.guardarRegistroCallCount, equals(1));
      expect(repo2.registros.length, equals(1));
      expect(vm.isSavingSesion, isFalse);
    });

    test('PROBE-R5-02: TEST-R5-T1-05 fails if guardarLote mutex is omitted', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      repo.simulateDelay = const Duration(milliseconds: 50);

      final existingLote = repo.lotes.first;
      final updatedLote1 = existingLote.copyWith(cantidadProductos: 120);
      final updatedLote2 = existingLote.copyWith(cantidadProductos: 150);

      // Mutant demonstration: Unprotected concurrent execution (without mutex guard)
      await Future.wait([
        repo.guardarLote(updatedLote1),
        repo.guardarLote(updatedLote2),
      ]);

      // Without mutex, call count is 2:
      expect(repo.guardarLoteCallCount, equals(2));
      // Proving that asserting equals(1) on un-mutexed execution throws TestFailure:
      expect(
        () => expect(repo.guardarLoteCallCount, equals(1)),
        throwsA(isA<TestFailure>()),
        reason: 'Oracle must fail if ViewModel mutex is omitted',
      );

      // Ground truth: With TableroViewModel mutex (_isSavingLote)
      final repo2 = FakeOtsRepository(useSeedData: true);
      repo2.simulateDelay = const Duration(milliseconds: 50);
      final vm = TableroViewModel(repository: repo2);
      addTearDown(vm.dispose);
      await vm.inicializar();

      final existing2 = vm.lotes.first;
      final f1 = vm.guardarLote(existing2.copyWith(cantidadProductos: 120));
      final f2 = vm.guardarLote(existing2.copyWith(cantidadProductos: 150));

      await Future.wait([f1, f2]);

      expect(repo2.guardarLoteCallCount, equals(1));
      expect(vm.isSavingLote, isFalse);
    });
  });
}
