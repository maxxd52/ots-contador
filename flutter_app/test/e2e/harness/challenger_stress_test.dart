import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/data/datasources/seed_data.dart';
import 'fake_ots_repository.dart';
import 'mock_shared_preferences.dart';
import 'test_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenge 1: FakeOtsRepository reset and resetState', () {
    test('Empirical check: does reset() exist on FakeOtsRepository?', () {
      final repo = FakeOtsRepository(useSeedData: true);
      expect(() => repo.reset(), returnsNormally);
      expect(repo.lotes, isEmpty);
      expect(repo.registros, isEmpty);
      expect(repo.sesionActiva, isNull);
    });

    test('Empirical check: resetState() thoroughly clears all state, logs, toggles, and counters', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      final lote = LoteBuilder().withId('lote_test').build();
      await repo.guardarLote(lote);

      final reg = RegistroTrabajoBuilder.standard(loteId: 'lote_test').build();
      await repo.guardarRegistro(reg);

      await repo.guardarSesionActiva({'loteId': 'lote_test', 'inicio': DateTime.now().toIso8601String()});

      // Set all failure toggles
      repo.simulateNetworkError = true;
      repo.simulateQuotaExceeded = true;
      repo.simulatePermissionDenied = true;
      repo.simulateDelay = const Duration(seconds: 1);
      repo.simulateFailOnObtenerLotes = true;
      repo.simulateFailOnGuardarLote = true;
      repo.simulateFailOnEliminarLote = true;
      repo.simulateFailOnObtenerRegistros = true;
      repo.simulateFailOnGuardarRegistro = true;
      repo.simulateFailOnSesionActiva = true;
      repo.failMidBatch = true;

      expect(repo.lotes.isNotEmpty, isTrue);
      expect(repo.registros.isNotEmpty, isTrue);
      expect(repo.sesionActiva, isNotNull);
      expect(repo.batchLog.isNotEmpty, isTrue);
      expect(repo.atomicBatchesCommitted, equals(1));
      expect(repo.guardarLoteCallCount, equals(1));
      expect(repo.guardarRegistroCallCount, equals(1));
      expect(repo.guardarSesionActivaCallCount, equals(1));

      // Call resetState()
      repo.resetState();

      // Verify state
      expect(repo.lotes, isEmpty);
      expect(repo.registros, isEmpty);
      expect(repo.sesionActiva, isNull);
      expect(repo.batchLog, isEmpty);
      expect(repo.atomicBatchesCommitted, equals(0));

      // Verify toggles
      expect(repo.simulateNetworkError, isFalse);
      expect(repo.simulateQuotaExceeded, isFalse);
      expect(repo.simulatePermissionDenied, isFalse);
      expect(repo.simulateDelay, isNull);
      expect(repo.simulateFailOnObtenerLotes, isFalse);
      expect(repo.simulateFailOnGuardarLote, isFalse);
      expect(repo.simulateFailOnEliminarLote, isFalse);
      expect(repo.simulateFailOnObtenerRegistros, isFalse);
      expect(repo.simulateFailOnGuardarRegistro, isFalse);
      expect(repo.simulateFailOnSesionActiva, isFalse);
      expect(repo.failMidBatch, isFalse);

      // Verify counters
      expect(repo.obtenerLotesCallCount, equals(0));
      expect(repo.guardarLoteCallCount, equals(0));
      expect(repo.eliminarLoteCallCount, equals(0));
      expect(repo.obtenerRegistrosCallCount, equals(0));
      expect(repo.guardarRegistroCallCount, equals(0));
      expect(repo.guardarSesionActivaCallCount, equals(0));
      expect(repo.obtenerSesionActivaCallCount, equals(0));
      expect(repo.limpiarSesionActivaCallCount, equals(0));
    });

    test('Empirical check: resetState(useSeedData: true) restores pristine seed data', () async {
      final repo = FakeOtsRepository();
      repo.resetState(useSeedData: true);

      expect(repo.lotes.length, equals(SeedData.obtenerLotesIniciales().length));
      expect(repo.registros, isEmpty);
      expect(repo.sesionActiva, isNull);
    });
  });

  group('Challenge 2: Failure toggles genuine FirebaseException verification', () {
    test('simulateNetworkError throws genuine FirebaseException across all operations', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      repo.simulateNetworkError = true;

      // Check obtenerLotes
      await expectLater(
        () => repo.obtenerLotes(),
        throwsA(isA<FirebaseException>()
            .having((e) => e.plugin, 'plugin', 'cloud_firestore')
            .having((e) => e.code, 'code', 'unavailable')),
      );

      // Check guardarLote
      await expectLater(
        () => repo.guardarLote(LoteBuilder().build()),
        throwsA(isA<FirebaseException>()
            .having((e) => e.plugin, 'plugin', 'cloud_firestore')
            .having((e) => e.code, 'code', 'unavailable')),
      );

      // Check eliminarLote
      await expectLater(
        () => repo.eliminarLote('lote_1'),
        throwsA(isA<FirebaseException>()
            .having((e) => e.plugin, 'plugin', 'cloud_firestore')
            .having((e) => e.code, 'code', 'unavailable')),
      );

      // Check obtenerRegistros
      await expectLater(
        () => repo.obtenerRegistros(),
        throwsA(isA<FirebaseException>()
            .having((e) => e.plugin, 'plugin', 'cloud_firestore')
            .having((e) => e.code, 'code', 'unavailable')),
      );

      // Check guardarRegistro
      await expectLater(
        () => repo.guardarRegistro(RegistroTrabajoBuilder.standard().build()),
        throwsA(isA<FirebaseException>()
            .having((e) => e.plugin, 'plugin', 'cloud_firestore')
            .having((e) => e.code, 'code', 'unavailable')),
      );
    });

    test('simulateQuotaExceeded throws genuine FirebaseException with resource-exhausted code', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      repo.simulateQuotaExceeded = true;

      await expectLater(
        () => repo.obtenerLotes(),
        throwsA(isA<FirebaseException>()
            .having((e) => e.plugin, 'plugin', 'cloud_firestore')
            .having((e) => e.code, 'code', 'resource-exhausted')),
      );

      await expectLater(
        () => repo.guardarLote(LoteBuilder().build()),
        throwsA(isA<FirebaseException>()
            .having((e) => e.plugin, 'plugin', 'cloud_firestore')
            .having((e) => e.code, 'code', 'resource-exhausted')),
      );
    });

    test('simulatePermissionDenied throws genuine FirebaseException with permission-denied code', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      repo.simulatePermissionDenied = true;

      await expectLater(
        () => repo.eliminarLote('lote_1'),
        throwsA(isA<FirebaseException>()
            .having((e) => e.plugin, 'plugin', 'cloud_firestore')
            .having((e) => e.code, 'code', 'permission-denied')),
      );
    });

    test('Behavioral analysis: active session methods do NOT throw on Firestore network outage', () async {
      final repo = FakeOtsRepository();
      repo.simulateNetworkError = true;

      await expectLater(
        repo.guardarSesionActiva({'loteId': 'test'}),
        completes,
      );
      expect(await repo.obtenerSesionActiva(), isNotNull);
      await expectLater(
        repo.limpiarSesionActiva(),
        completes,
      );

      // Dedicated toggle simulateFailOnSesionActiva throws
      repo.simulateFailOnSesionActiva = true;
      await expectLater(
        () => repo.guardarSesionActiva({'loteId': 'test'}),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        () => repo.obtenerSesionActiva(),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        () => repo.limpiarSesionActiva(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Challenge 3: Atomicity and failMidBatch semantics', () {
    test('failMidBatch simulates legacy non-atomic partial write (commits registro, aborts lote)', () async {
      final initialLote = LoteBuilder.habilitado(id: 'target_lote').build();
      final repo = FakeOtsRepository(initialLotes: [initialLote]);
      repo.failMidBatch = true;

      final reg = RegistroTrabajoBuilder.standard(loteId: 'target_lote').build();

      await expectLater(
        () => repo.guardarRegistro(reg),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );

      // In failMidBatch, work record is committed, but lot unlock date is NOT updated.
      expect(repo.registros.length, equals(1));
      expect(repo.lotes.first.proximoDesbloqueo, isNull);
      expect(repo.atomicBatchesCommitted, equals(0));
      expect(repo.batchLog.last.operation, equals('partial_write_aborted_mid_batch'));
      expect(repo.batchLog.last.succeeded, isFalse);
    });

    test('Atomic abort simulation (simulateFailOnGuardarRegistro) guarantees ZERO partial state', () async {
      final initialLote = LoteBuilder.habilitado(id: 'target_lote').build();
      final repo = FakeOtsRepository(initialLotes: [initialLote]);
      repo.simulateFailOnGuardarRegistro = true;

      final reg = RegistroTrabajoBuilder.standard(loteId: 'target_lote').build();

      await expectLater(
        () => repo.guardarRegistro(reg),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );

      // In genuine atomic abort, zero partial state is left
      expect(repo.registros, isEmpty, reason: 'Atomic rollback must NOT insert partial work record');
      expect(repo.lotes.first.proximoDesbloqueo, isNull);
      expect(repo.atomicBatchesCommitted, equals(0));
      expect(repo.batchLog.last.succeeded, isFalse);
    });
  });

  group('Challenge 4: MockSharedPreferencesHelper isolation and cross-test leakage', () {
    test('Test A: setValidSession populates session and mutates shared state', () async {
      final start = DateTime(2026, 11, 12, 9, 30);
      MockSharedPreferencesHelper.setValidSession(loteId: 'lote_test_a', inicio: start);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MockSharedPreferencesHelper.keySesionActiva), contains('lote_test_a'));

      // Mutate preferences directly (dirty state)
      await prefs.setString('uncleaned_key', 'uncleaned_value');
    });

    test('Test B: Cross-test leakage when setEmpty is NOT called in a subsequent test', () async {
      // Intentionally NOT calling MockSharedPreferencesHelper.setEmpty()
      final prefs = await SharedPreferences.getInstance();
      final leakedKey = prefs.getString('uncleaned_key');

      // Demonstrates that SharedPreferences singleton in memory retains dirty keys across tests
      // UNLESS setMockInitialValues / setEmpty() is explicitly called in setUp/tearDown
      expect(
        leakedKey,
        equals('uncleaned_value'),
        reason: 'Without calling setEmpty() in setUp(), SharedPreferences leaks state across test cases.',
      );
    });

    test('Test C: Does MockSharedPreferencesHelper.setEmpty() cleanly purge leaked keys?', () async {
      MockSharedPreferencesHelper.setEmpty();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('uncleaned_key'), isNull);
      expect(prefs.getString(MockSharedPreferencesHelper.keySesionActiva), isNull);
    });

    test('Test D: Calling setValidSession after setLotes completely overwrites and erases keyLotes', () async {
      final lotes = [LoteBuilder().withId('lote_persist').build()];
      MockSharedPreferencesHelper.setLotes(lotes);

      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MockSharedPreferencesHelper.keyLotes), isNotNull);

      // Now set session using setValidSession with default merge: false
      MockSharedPreferencesHelper.setValidSession(loteId: 'lote_persist', inicio: DateTime.now());
      prefs = await SharedPreferences.getInstance();

      final lotesRawAfter = prefs.getString(MockSharedPreferencesHelper.keyLotes);
      final sessionRawAfter = prefs.getString(MockSharedPreferencesHelper.keySesionActiva);

      expect(sessionRawAfter, isNotNull);
      expect(
        lotesRawAfter,
        isNull,
        reason: 'MockSharedPreferencesHelper convenience methods default to merge: false for single-fixture isolation.',
      );
    });

    test('Test E: Calling setMockState sets lotes and session simultaneously without key-clobbering', () async {
      final lotes = [LoteBuilder().withId('lote_persist').build()];
      MockSharedPreferencesHelper.setMockState(
        lotes: lotes,
        sesionActiva: {'loteId': 'lote_persist', 'inicio': DateTime.now().toIso8601String()},
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MockSharedPreferencesHelper.keyLotes), isNotNull);
      expect(prefs.getString(MockSharedPreferencesHelper.keySesionActiva), isNotNull);
    });

    test('Test F: Calling updateMockValues incrementally merges values without erasing existing keys', () async {
      MockSharedPreferencesHelper.setMockState(
        additionalValues: {'initial_key': 'initial_val'},
      );

      MockSharedPreferencesHelper.updateMockValues({'merged_key': 'merged_val'});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('initial_key'), equals('initial_val'));
      expect(prefs.getString('merged_key'), equals('merged_val'));
    });

    test('Test G: Calling setValidSession with merge: true preserves pre-existing keys', () async {
      final lotes = [LoteBuilder().withId('lote_persist_merge').build()];
      MockSharedPreferencesHelper.setLotes(lotes);

      MockSharedPreferencesHelper.setValidSession(
        loteId: 'lote_persist_merge',
        inicio: DateTime.now(),
        merge: true,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MockSharedPreferencesHelper.keyLotes), isNotNull);
      expect(prefs.getString(MockSharedPreferencesHelper.keySesionActiva), isNotNull);
    });
  });
}
