import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/data/datasources/seed_data.dart';
import 'fake_ots_repository.dart';
import 'mock_shared_preferences.dart';
import 'test_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FakeOtsRepository Harness Verification', () {
    test('initializes with seed data when requested', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      final lotes = await repo.obtenerLotes();

      expect(lotes.length, equals(SeedData.obtenerLotesIniciales().length));
      expect(repo.obtenerLotesCallCount, equals(1));
    });

    test('maintains genuine in-memory state and call counters for Lote CRUD', () async {
      final repo = FakeOtsRepository();
      final lote = LoteBuilder()
          .withId('lote_1')
          .withSupermercado('Carrefour Norte')
          .withArea('Lácteos')
          .withCantidadProductos(45)
          .build();

      await repo.guardarLote(lote);
      expect(repo.guardarLoteCallCount, equals(1));
      expect(repo.lotes.length, equals(1));
      expect(repo.lotes.first.id, equals('lote_1'));

      final fetched = await repo.obtenerLotes();
      expect(repo.obtenerLotesCallCount, equals(1));
      expect(fetched.first.supermercado, equals('Carrefour Norte'));

      await repo.eliminarLote('lote_1');
      expect(repo.eliminarLoteCallCount, equals(1));
      expect(repo.lotes.isEmpty, isTrue);
    });

    test('executes atomic batch on guardarRegistro: records work and updates lot unlock date', () async {
      final initialLote = LoteBuilder.habilitado(
        id: 'lote_target',
        supermercado: 'Coto Central',
        area: 'Bebidas',
      ).build();

      final repo = FakeOtsRepository(initialLotes: [initialLote]);
      final start = DateTime(2026, 11, 12, 10, 0);

      final registro = RegistroTrabajoBuilder.standard(
        id: 'reg_1',
        loteId: 'lote_target',
        inicio: start,
        minutes: 45,
      ).build();

      await repo.guardarRegistro(registro);

      expect(repo.guardarRegistroCallCount, equals(1));
      expect(repo.atomicBatchesCommitted, equals(1));
      expect(repo.registros.length, equals(1));
      expect(repo.batchLog.length, equals(1));
      expect(repo.batchLog.first.operation, equals('guardarRegistroAtomicBatch'));
      expect(repo.batchLog.first.succeeded, isTrue);

      final updatedLote = repo.lotes.firstWhere((l) => l.id == 'lote_target');
      expect(updatedLote.ultimoInicio, equals(start));
      expect(updatedLote.proximoDesbloqueo, equals(registro.nuevoDesbloqueo));
    });

    test('simulates network failure toggle throwing FirebaseException', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      repo.simulateNetworkError = true;

      await expectLater(
        () => repo.obtenerLotes(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );
    });

    test('simulates quota exceeded toggle throwing FirebaseException', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      repo.simulateQuotaExceeded = true;

      await expectLater(
        () => repo.guardarLote(LoteBuilder().build()),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'resource-exhausted')),
      );
    });

    test('simulates permission denied toggle throwing FirebaseException', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      repo.simulatePermissionDenied = true;

      await expectLater(
        () => repo.eliminarLote('lote_1'),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );
    });

    test('simulates mid-batch failure injecting partial state for fault testing', () async {
      final repo = FakeOtsRepository(
        initialLotes: [LoteBuilder().withId('lote_partial').build()],
      );
      repo.failMidBatch = true;

      final reg = RegistroTrabajoBuilder.standard(loteId: 'lote_partial').build();

      await expectLater(
        () => repo.guardarRegistro(reg),
        throwsA(isA<FirebaseException>()),
      );

      // In partial failure simulation, registro is written but lot is not rescheduled
      expect(repo.registros.length, equals(1));
      expect(repo.batchLog.last.succeeded, isFalse);
    });

    test('manages active session state and call counters', () async {
      final repo = FakeOtsRepository();
      expect(await repo.obtenerSesionActiva(), isNull);

      await repo.guardarSesionActiva({'loteId': 'lote_abc', 'inicio': '2026-11-12T10:00:00.000Z'});
      expect(repo.guardarSesionActivaCallCount, equals(1));
      expect(repo.sesionActiva?['loteId'], equals('lote_abc'));

      final retrieved = await repo.obtenerSesionActiva();
      expect(repo.obtenerSesionActivaCallCount, equals(2));
      expect(retrieved?['loteId'], equals('lote_abc'));

      await repo.limpiarSesionActiva();
      expect(repo.limpiarSesionActivaCallCount, equals(1));
      expect(repo.sesionActiva, isNull);
    });

    test('reset() clears state, logs, failure toggles, and resets call counters', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      await repo.guardarLote(LoteBuilder().withId('lote_reset').build());
      await repo.guardarRegistro(RegistroTrabajoBuilder.standard().build());
      await repo.guardarSesionActiva({'loteId': 'lote_reset', 'inicio': DateTime.now().toIso8601String()});
      repo.simulateNetworkError = true;
      repo.failMidBatch = true;

      expect(repo.lotes.isNotEmpty, isTrue);
      expect(repo.registros.isNotEmpty, isTrue);
      expect(repo.sesionActiva, isNotNull);
      expect(repo.obtenerLotesCallCount, equals(0));
      expect(repo.guardarLoteCallCount, equals(1));

      // Call reset() alias
      repo.reset();

      expect(repo.lotes, isEmpty);
      expect(repo.registros, isEmpty);
      expect(repo.sesionActiva, isNull);
      expect(repo.batchLog, isEmpty);
      expect(repo.atomicBatchesCommitted, equals(0));
      expect(repo.simulateNetworkError, isFalse);
      expect(repo.failMidBatch, isFalse);
      expect(repo.guardarLoteCallCount, equals(0));
      expect(repo.guardarRegistroCallCount, equals(0));
      expect(repo.guardarSesionActivaCallCount, equals(0));
    });

    test('reset(useSeedData: true) restores pristine seed lotes', () {
      final repo = FakeOtsRepository();
      repo.reset(useSeedData: true);

      expect(repo.lotes.length, equals(SeedData.obtenerLotesIniciales().length));
      expect(repo.registros, isEmpty);
      expect(repo.sesionActiva, isNull);
    });

    test('active session methods succeed when simulateNetworkError is true (offline local persistence)', () async {
      final repo = FakeOtsRepository();
      repo.simulateNetworkError = true;

      // Session methods must complete without throwing FirebaseException
      await repo.guardarSesionActiva({'loteId': 'offline_lote', 'inicio': DateTime.now().toIso8601String()});
      expect(repo.sesionActiva?['loteId'], equals('offline_lote'));

      final session = await repo.obtenerSesionActiva();
      expect(session?['loteId'], equals('offline_lote'));

      await repo.limpiarSesionActiva();
      expect(repo.sesionActiva, isNull);
    });

    test('active session methods throw Exception when simulateFailOnSesionActiva is true', () async {
      final repo = FakeOtsRepository();
      repo.simulateFailOnSesionActiva = true;

      await expectLater(
        () => repo.guardarSesionActiva({'loteId': 'err'}),
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

    test('simulateFailOnGuardarRegistro causes zero partial state while failMidBatch mutates registros', () async {
      final initialLote = LoteBuilder.habilitado(id: 'atomic_test_lote').build();
      final repo = FakeOtsRepository(initialLotes: [initialLote]);

      // 1. Atomic rollback (TEST-R2-T2-01 requirement): zero partial state
      repo.simulateFailOnGuardarRegistro = true;
      final reg1 = RegistroTrabajoBuilder.standard(id: 'reg_atomic', loteId: 'atomic_test_lote').build();

      await expectLater(
        () => repo.guardarRegistro(reg1),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );
      expect(repo.registros, isEmpty, reason: 'Atomic commit abort leaves zero partial records');
      expect(repo.lotes.first.proximoDesbloqueo, isNull);
      expect(repo.atomicBatchesCommitted, equals(0));

      // Reset failure toggle
      repo.simulateFailOnGuardarRegistro = false;

      // 2. Legacy defect simulation: inserts work record but aborts lot reschedule
      repo.failMidBatch = true;
      final reg2 = RegistroTrabajoBuilder.standard(id: 'reg_legacy', loteId: 'atomic_test_lote').build();

      await expectLater(
        () => repo.guardarRegistro(reg2),
        throwsA(isA<FirebaseException>()),
      );
      expect(repo.registros.length, equals(1), reason: 'Legacy defect inserted partial work record');
      expect(repo.lotes.first.proximoDesbloqueo, isNull);
    });
  });

  group('MockSharedPreferencesHelper Harness Verification', () {
    test('setValidSession populates valid session fixture', () async {
      final now = DateTime(2026, 11, 12, 10, 0);
      MockSharedPreferencesHelper.setValidSession(loteId: 'lote_10', inicio: now);

      final raw = await MockSharedPreferencesHelper.getRawSession();
      expect(raw, contains('lote_10'));
      expect(raw, contains(now.toIso8601String()));

      final decoded = await MockSharedPreferencesHelper.getDecodedSession();
      expect(decoded?['loteId'], equals('lote_10'));
      expect(decoded?['inicio'], equals(now.toIso8601String()));
      expect(await MockSharedPreferencesHelper.isSessionPurged(), isFalse);
    });

    test('setSessionWithMalformedDate populates corrupted date string fixture', () async {
      MockSharedPreferencesHelper.setSessionWithMalformedDate(
        loteId: 'lote_bad',
        malformedDate: 'corrupted-timestamp',
      );

      final decoded = await MockSharedPreferencesHelper.getDecodedSession();
      expect(decoded?['loteId'], equals('lote_bad'));
      expect(decoded?['inicio'], equals('corrupted-timestamp'));
    });

    test('setSessionWithNonJsonString populates raw garbage', () async {
      MockSharedPreferencesHelper.setSessionWithNonJsonString();

      final raw = await MockSharedPreferencesHelper.getRawSession();
      expect(raw, contains('CORRUPTED_RAW'));
      expect(await MockSharedPreferencesHelper.getDecodedSession(), isNull);
    });

    test('setLargeGarbageSession populates oversized payload', () async {
      MockSharedPreferencesHelper.setLargeGarbageSession(5000);

      final raw = await MockSharedPreferencesHelper.getRawSession();
      expect(raw?.length, equals(5000));
    });

    test('setMockState sets composite lotes, registros, and session without key-clobbering', () async {
      MockSharedPreferencesHelper.setEmpty();

      final lotes = [LoteBuilder().withId('lote_composite').build()];
      final registros = [RegistroTrabajoBuilder.standard(id: 'reg_composite').build()];
      final session = {'loteId': 'lote_composite', 'inicio': '2026-11-12T12:00:00.000Z'};

      MockSharedPreferencesHelper.setMockState(
        lotes: lotes,
        registros: registros,
        sesionActiva: session,
        additionalValues: {'test_flag': 42},
      );

      final rawLotes = await MockSharedPreferencesHelper.getRawLotes();
      final decodedLotes = await MockSharedPreferencesHelper.getDecodedLotes();
      final rawRegistros = await MockSharedPreferencesHelper.getRawRegistros();
      final decodedRegistros = await MockSharedPreferencesHelper.getDecodedRegistros();
      final rawSession = await MockSharedPreferencesHelper.getRawSession();
      final decodedSession = await MockSharedPreferencesHelper.getDecodedSession();
      final flag = await MockSharedPreferencesHelper.getStoredValue<int>('test_flag');
      final storedKeys = await MockSharedPreferencesHelper.getStoredKeys();

      expect(rawLotes, contains('lote_composite'));
      expect(decodedLotes?.length, equals(1));
      expect(rawRegistros, contains('reg_composite'));
      expect(decodedRegistros?.length, equals(1));
      expect(rawSession, contains('2026-11-12T12:00:00.000Z'));
      expect(decodedSession?['loteId'], equals('lote_composite'));
      expect(flag, equals(42));
      expect(storedKeys, containsAll([
        MockSharedPreferencesHelper.keyLotes,
        MockSharedPreferencesHelper.keyRegistros,
        MockSharedPreferencesHelper.keySesionActiva,
        'test_flag',
      ]));
      expect(MockSharedPreferencesHelper.currentMockState.containsKey('test_flag'), isTrue);
    });

    test('setMockState with merge: false purges prior state', () async {
      MockSharedPreferencesHelper.setMockState(
        additionalValues: {'prior_key': 'prior_val'},
      );
      expect(await MockSharedPreferencesHelper.getStoredValue<String>('prior_key'), equals('prior_val'));

      MockSharedPreferencesHelper.setMockState(
        rawSesionActiva: 'new_session_only',
        merge: false,
      );

      expect(await MockSharedPreferencesHelper.getStoredValue<String>('prior_key'), isNull);
      expect(await MockSharedPreferencesHelper.getRawSession(), equals('new_session_only'));
    });

    test('setMockState with removeKeys selectively removes specified keys', () async {
      MockSharedPreferencesHelper.setMockState(
        rawLotes: 'lotes_data',
        rawSesionActiva: 'session_data',
      );

      MockSharedPreferencesHelper.setMockState(
        removeKeys: [MockSharedPreferencesHelper.keySesionActiva],
      );

      expect(await MockSharedPreferencesHelper.isSessionPurged(), isTrue);
      expect(await MockSharedPreferencesHelper.getRawLotes(), equals('lotes_data'));
    });

    test('updateMockValues incrementally adds keys without clobbering', () async {
      MockSharedPreferencesHelper.setEmpty();
      MockSharedPreferencesHelper.setMockState(
        additionalValues: {'key_1': 'val_1'},
      );

      MockSharedPreferencesHelper.updateMockValues({'key_2': 99});

      expect(await MockSharedPreferencesHelper.getStoredValue<String>('key_1'), equals('val_1'));
      expect(await MockSharedPreferencesHelper.getStoredValue<int>('key_2'), equals(99));
    });

    test('mergeLiveState captures runtime app writes and merges new fixtures', () async {
      MockSharedPreferencesHelper.setEmpty();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('runtime_app_key', 'runtime_app_value');

      await MockSharedPreferencesHelper.mergeLiveState(
        rawLotes: 'fixture_lotes_merged',
      );

      expect(await MockSharedPreferencesHelper.getStoredValue<String>('runtime_app_key'), equals('runtime_app_value'));
      expect(await MockSharedPreferencesHelper.getRawLotes(), equals('fixture_lotes_merged'));
    });

    test('setMockState throws ArgumentError if both structured and raw payloads are supplied', () {
      expect(
        () => MockSharedPreferencesHelper.setMockState(
          lotes: [LoteBuilder().build()],
          rawLotes: 'raw_lotes_string',
        ),
        throwsArgumentError,
      );

      expect(
        () => MockSharedPreferencesHelper.setMockState(
          registros: [RegistroTrabajoBuilder.standard().build()],
          rawRegistros: 'raw_reg_string',
        ),
        throwsArgumentError,
      );

      expect(
        () => MockSharedPreferencesHelper.setMockState(
          sesionActiva: {'loteId': '1'},
          rawSesionActiva: 'raw_session_string',
        ),
        throwsArgumentError,
      );
    });
  });

  group('Test Builders Verification', () {
    test('LoteBuilder creates valid Lote with custom or preset properties', () {
      final habilitado = LoteBuilder.habilitado(supermercado: 'Super Uno').build();
      expect(habilitado.supermercado, equals('Super Uno'));
      expect(habilitado.proximoDesbloqueo, isNull);

      final futuro = LoteBuilder.futuro(daysAhead: 30).build();
      expect(futuro.proximoDesbloqueo, isNotNull);
      expect(futuro.proximoDesbloqueo!.isAfter(DateTime.now()), isTrue);
    });

    test('RegistroTrabajoBuilder creates valid RegistroTrabajo with calculated metrics', () {
      final start = DateTime(2026, 11, 12, 8, 0);
      final reg = RegistroTrabajoBuilder.standard(
        inicio: start,
        minutes: 90,
      ).build();

      expect(reg.duracionMinutos, equals(90));
      expect(reg.horasDecimales, equals(1.5));
      expect(reg.duracionTexto, equals('1h 30m'));
      expect(reg.nuevoDesbloqueo, isNotNull);
    });
  });
}
