import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter_app/data/datasources/seed_data.dart';
import 'fake_ots_repository.dart';
import 'mock_shared_preferences.dart';
import 'test_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger M1-IT2 Empirical Stress: Item 1 - FakeOtsRepository.reset()', () {
    test('reset() method exists, takes useSeedData, and can be invoked without error', () {
      final repo = FakeOtsRepository();
      expect(() => repo.reset(), returnsNormally);
      expect(() => repo.reset(useSeedData: false), returnsNormally);
      expect(() => repo.reset(useSeedData: true), returnsNormally);
    });

    test('reset() thoroughly clears all state, collections, active session, logs, failure toggles, and counters', () async {
      final repo = FakeOtsRepository(useSeedData: true);

      // Dirty state
      final lote = LoteBuilder().withId('lote_dirty').build();
      await repo.guardarLote(lote);
      final reg = RegistroTrabajoBuilder.standard(loteId: 'lote_dirty').build();
      await repo.guardarRegistro(reg);
      await repo.guardarSesionActiva({'loteId': 'lote_dirty', 'inicio': DateTime.now().toIso8601String()});
      await repo.obtenerLotes();
      await repo.obtenerRegistros();
      await repo.obtenerSesionActiva();
      await repo.limpiarSesionActiva();
      await repo.eliminarLote('lote_dirty');

      // Dirty failure toggles
      repo.simulateNetworkError = true;
      repo.simulateQuotaExceeded = true;
      repo.simulatePermissionDenied = true;
      repo.simulateDelay = const Duration(milliseconds: 500);
      repo.simulateFailOnObtenerLotes = true;
      repo.simulateFailOnGuardarLote = true;
      repo.simulateFailOnEliminarLote = true;
      repo.simulateFailOnObtenerRegistros = true;
      repo.simulateFailOnGuardarRegistro = true;
      repo.simulateFailOnSesionActiva = true;
      repo.failMidBatch = true;

      // Verify dirty state before reset
      expect(repo.batchLog.isNotEmpty, isTrue);
      expect(repo.guardarLoteCallCount, greaterThan(0));
      expect(repo.guardarRegistroCallCount, greaterThan(0));
      expect(repo.guardarSesionActivaCallCount, greaterThan(0));
      expect(repo.obtenerLotesCallCount, greaterThan(0));
      expect(repo.obtenerRegistrosCallCount, greaterThan(0));
      expect(repo.obtenerSesionActivaCallCount, greaterThan(0));
      expect(repo.limpiarSesionActivaCallCount, greaterThan(0));
      expect(repo.eliminarLoteCallCount, greaterThan(0));

      // Invoke reset()
      repo.reset();

      // Assertions on state
      expect(repo.lotes, isEmpty);
      expect(repo.registros, isEmpty);
      expect(repo.sesionActiva, isNull);
      expect(repo.batchLog, isEmpty);
      expect(repo.atomicBatchesCommitted, equals(0));

      // Assertions on toggles
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

      // Assertions on call counters
      expect(repo.obtenerLotesCallCount, equals(0));
      expect(repo.guardarLoteCallCount, equals(0));
      expect(repo.eliminarLoteCallCount, equals(0));
      expect(repo.obtenerRegistrosCallCount, equals(0));
      expect(repo.guardarRegistroCallCount, equals(0));
      expect(repo.guardarSesionActivaCallCount, equals(0));
      expect(repo.obtenerSesionActivaCallCount, equals(0));
      expect(repo.limpiarSesionActivaCallCount, equals(0));
    });

    test('reset(useSeedData: true) restores pristine seed lotes while resetting everything else', () async {
      final repo = FakeOtsRepository();
      repo.simulateNetworkError = true;
      repo.simulateFailOnSesionActiva = true;

      repo.reset(useSeedData: true);

      expect(repo.lotes.length, equals(SeedData.obtenerLotesIniciales().length));
      expect(repo.registros, isEmpty);
      expect(repo.sesionActiva, isNull);
      expect(repo.batchLog, isEmpty);
      expect(repo.atomicBatchesCommitted, equals(0));
      expect(repo.simulateNetworkError, isFalse);
      expect(repo.simulateFailOnSesionActiva, isFalse);
      expect(repo.obtenerLotesCallCount, equals(0));
    });

    test('reset() is idempotent under rapid consecutive invocations', () {
      final repo = FakeOtsRepository(useSeedData: true);
      for (int i = 0; i < 50; i++) {
        repo.reset();
        expect(repo.lotes, isEmpty);
        expect(repo.registros, isEmpty);
        expect(repo.sesionActiva, isNull);
      }
    });
  });

  group('Challenger M1-IT2 Empirical Stress: Item 2 - MockSharedPreferencesHelper Multi-State', () {
    setUp(() {
      MockSharedPreferencesHelper.setEmpty();
    });

    test('setMockState seeds lotes, registros, sesionActiva, and custom primitives without clobbering', () async {
      final lotes = [
        LoteBuilder().withId('lote_multi_1').withSupermercado('Coto').build(),
        LoteBuilder().withId('lote_multi_2').withSupermercado('Disco').build(),
      ];
      final registros = [
        RegistroTrabajoBuilder.standard(id: 'reg_multi_1', loteId: 'lote_multi_1').build(),
      ];
      final session = {
        'loteId': 'lote_multi_1',
        'inicio': '2026-11-12T14:30:00.000Z',
      };
      final additional = <String, Object>{
        'app_theme': 'dark',
        'sync_interval_ms': 5000,
        'feature_flag_active': true,
      };

      MockSharedPreferencesHelper.setMockState(
        lotes: lotes,
        registros: registros,
        sesionActiva: session,
        additionalValues: additional,
      );

      // Verify all 4 categories exist concurrently
      final decodedLotes = await MockSharedPreferencesHelper.getDecodedLotes();
      final decodedRegistros = await MockSharedPreferencesHelper.getDecodedRegistros();
      final decodedSession = await MockSharedPreferencesHelper.getDecodedSession();
      final theme = await MockSharedPreferencesHelper.getStoredValue<String>('app_theme');
      final interval = await MockSharedPreferencesHelper.getStoredValue<int>('sync_interval_ms');
      final flag = await MockSharedPreferencesHelper.getStoredValue<bool>('feature_flag_active');
      final allKeys = await MockSharedPreferencesHelper.getStoredKeys();

      expect(decodedLotes?.length, equals(2));
      expect(decodedLotes?.first['supermercado'], equals('Coto'));
      expect(decodedRegistros?.length, equals(1));
      expect(decodedRegistros?.first['id'], equals('reg_multi_1'));
      expect(decodedSession?['loteId'], equals('lote_multi_1'));
      expect(decodedSession?['inicio'], equals('2026-11-12T14:30:00.000Z'));
      expect(theme, equals('dark'));
      expect(interval, equals(5000));
      expect(flag, isTrue);
      expect(allKeys, containsAll([
        MockSharedPreferencesHelper.keyLotes,
        MockSharedPreferencesHelper.keyRegistros,
        MockSharedPreferencesHelper.keySesionActiva,
        'app_theme',
        'sync_interval_ms',
        'feature_flag_active',
      ]));
    });

    test('raw payloads for lotes and sesionActiva can be set simultaneously', () async {
      MockSharedPreferencesHelper.setMockState(
        rawLotes: 'RAW_UNPARSEABLE_LOTES_DATA',
        rawSesionActiva: 'RAW_CORRUPT_SESSION_TIMESTAMP',
      );

      final rawLotes = await MockSharedPreferencesHelper.getRawLotes();
      final rawSession = await MockSharedPreferencesHelper.getRawSession();

      expect(rawLotes, equals('RAW_UNPARSEABLE_LOTES_DATA'));
      expect(rawSession, equals('RAW_CORRUPT_SESSION_TIMESTAMP'));
    });

    test('updateMockValues incrementally adds keys preserving pre-existing state', () async {
      MockSharedPreferencesHelper.setMockState(
        sesionActiva: {'loteId': 'lote_base'},
      );

      MockSharedPreferencesHelper.updateMockValues({'incremental_key': 'incremental_value'});

      final session = await MockSharedPreferencesHelper.getDecodedSession();
      final inc = await MockSharedPreferencesHelper.getStoredValue<String>('incremental_key');

      expect(session?['loteId'], equals('lote_base'));
      expect(inc, equals('incremental_value'));
    });

    test('removeKeys selectively removes specified keys while preserving others', () async {
      MockSharedPreferencesHelper.setMockState(
        lotes: [LoteBuilder().withId('lote_keep').build()],
        sesionActiva: {'loteId': 'lote_remove'},
        additionalValues: {'keep_me': 123},
      );

      MockSharedPreferencesHelper.setMockState(
        removeKeys: [MockSharedPreferencesHelper.keySesionActiva],
        merge: true,
      );

      expect(await MockSharedPreferencesHelper.isSessionPurged(), isTrue);
      expect(await MockSharedPreferencesHelper.getDecodedLotes(), isNotNull);
      expect(await MockSharedPreferencesHelper.getStoredValue<int>('keep_me'), equals(123));
    });

    test('merge: false cleanly resets previous mock state', () async {
      MockSharedPreferencesHelper.setMockState(
        additionalValues: {'old_key': 'old_value'},
      );

      MockSharedPreferencesHelper.setMockState(
        additionalValues: {'new_key': 'new_value'},
        merge: false,
      );

      expect(await MockSharedPreferencesHelper.getStoredValue<String>('old_key'), isNull);
      expect(await MockSharedPreferencesHelper.getStoredValue<String>('new_key'), equals('new_value'));
    });

    test('setMockState throws ArgumentError on conflicting structured and raw arguments', () {
      expect(
        () => MockSharedPreferencesHelper.setMockState(
          lotes: [LoteBuilder().build()],
          rawLotes: 'raw_string',
        ),
        throwsArgumentError,
      );

      expect(
        () => MockSharedPreferencesHelper.setMockState(
          registros: [RegistroTrabajoBuilder.standard().build()],
          rawRegistros: 'raw_string',
        ),
        throwsArgumentError,
      );

      expect(
        () => MockSharedPreferencesHelper.setMockState(
          sesionActiva: {'loteId': '1'},
          rawSesionActiva: 'raw_string',
        ),
        throwsArgumentError,
      );
    });
  });

  group('Challenger M1-IT2 Empirical Stress: Item 3 - Active Session Decoupled from Remote Firestore Outages', () {
    test('active session operations succeed cleanly during remote network outages (simulateNetworkError = true)', () async {
      final repo = FakeOtsRepository();
      repo.simulateNetworkError = true;

      // Remote operations must fail
      await expectLater(
        () => repo.obtenerLotes(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );
      await expectLater(
        () => repo.guardarLote(LoteBuilder().build()),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );
      await expectLater(
        () => repo.obtenerRegistros(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );
      await expectLater(
        () => repo.guardarRegistro(RegistroTrabajoBuilder.standard().build()),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );
      await expectLater(
        () => repo.eliminarLote('lote_id'),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );

      // Local active session operations MUST succeed without throwing FirebaseException
      final sessionMap = {'loteId': 'offline_lote_1', 'inicio': '2026-11-12T15:00:00.000Z'};
      await expectLater(repo.guardarSesionActiva(sessionMap), completes);
      expect(repo.guardarSesionActivaCallCount, equals(1));
      expect(repo.sesionActiva?['loteId'], equals('offline_lote_1'));

      final retrieved = await repo.obtenerSesionActiva();
      expect(repo.obtenerSesionActivaCallCount, equals(1));
      expect(retrieved?['loteId'], equals('offline_lote_1'));

      await expectLater(repo.limpiarSesionActiva(), completes);
      expect(repo.limpiarSesionActivaCallCount, equals(1));
      expect(repo.sesionActiva, isNull);
    });

    test('active session operations succeed cleanly during quota exceeded or permission denied outages', () async {
      final repo = FakeOtsRepository();
      repo.simulateQuotaExceeded = true;
      repo.simulatePermissionDenied = true;

      // Remote operations fail
      await expectLater(() => repo.obtenerLotes(), throwsA(isA<FirebaseException>()));

      // Active session operations succeed
      await expectLater(repo.guardarSesionActiva({'loteId': 'local_lot'}), completes);
      expect((await repo.obtenerSesionActiva())?['loteId'], equals('local_lot'));
      await expectLater(repo.limpiarSesionActiva(), completes);
      expect(await repo.obtenerSesionActiva(), isNull);
    });

    test('active session operations fail ONLY when simulateFailOnSesionActiva = true', () async {
      final repo = FakeOtsRepository();
      repo.simulateFailOnSesionActiva = true;

      // Remote operations are NOT failing
      expect(() => repo.lotes, returnsNormally);

      // Active session operations throw Exception
      await expectLater(
        () => repo.guardarSesionActiva({'loteId': 'fail_lot'}),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('Failed to persist active session'))),
      );
      await expectLater(
        () => repo.obtenerSesionActiva(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('Failed to read active session'))),
      );
      await expectLater(
        () => repo.limpiarSesionActiva(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('Failed to clear active session'))),
      );
    });
  });

  group('Challenger M1-IT2 Empirical Stress: Item 4 - failMidBatch vs Atomic Rollback Semantics', () {
    test('simulateFailOnGuardarRegistro produces genuine zero partial state (atomic rollback oracle)', () async {
      final targetLote = LoteBuilder.habilitado(
        id: 'atomic_lote',
        supermercado: 'Super Atomic',
        area: 'Carnicería',
      ).build();
      final repo = FakeOtsRepository(initialLotes: [targetLote]);
      repo.simulateFailOnGuardarRegistro = true;

      final reg = RegistroTrabajoBuilder.standard(
        id: 'reg_atomic_probe',
        loteId: 'atomic_lote',
      ).build();

      await expectLater(
        () => repo.guardarRegistro(reg),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );

      // Oracle verification: ZERO partial records written, lot unlock untouched
      expect(repo.registros, isEmpty, reason: 'Atomic rollback must not commit any partial work record');
      expect(repo.lotes.first.proximoDesbloqueo, isNull, reason: 'Lot proximoDesbloqueo must remain unmutated');
      expect(repo.atomicBatchesCommitted, equals(0));
      expect(repo.batchLog.last.succeeded, isFalse);
      expect(repo.batchLog.last.operation, equals('guardarRegistroAtomicBatch'));
    });

    test('failMidBatch injects legacy defect partial state (work record committed, lot unrescheduled)', () async {
      final targetLote = LoteBuilder.habilitado(
        id: 'legacy_lote',
        supermercado: 'Super Legacy',
        area: 'Panadería',
      ).build();
      final repo = FakeOtsRepository(initialLotes: [targetLote]);
      repo.failMidBatch = true;

      final reg = RegistroTrabajoBuilder.standard(
        id: 'reg_legacy_probe',
        loteId: 'legacy_lote',
      ).build();

      await expectLater(
        () => repo.guardarRegistro(reg),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );

      // Oracle verification: In legacy defect, work record is inserted, but lot is NOT rescheduled
      expect(repo.registros.length, equals(1), reason: 'Legacy defect inserts work record');
      expect(repo.registros.first.id, equals('reg_legacy_probe'));
      expect(repo.lotes.first.proximoDesbloqueo, isNull, reason: 'Lot was not rescheduled');
      expect(repo.atomicBatchesCommitted, equals(0));
      expect(repo.batchLog.last.succeeded, isFalse);
      expect(repo.batchLog.last.operation, equals('partial_write_aborted_mid_batch'));
    });
  });
}
