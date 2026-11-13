import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/logic/time_calculator.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import '../harness/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockSharedPreferencesHelper.setEmpty();
  });

  group('Tier 1 - R2: Atomic Persistence and Lot Rescheduling', () {
    // TEST-R2-T1-01: Work record & lot reschedule commit atomically
    test('TEST-R2-T1-01: Work record & lot reschedule commit atomically in single batch', () async {
      final initialLote = LoteBuilder.habilitado(
        id: 'lote_target_01',
        supermercado: 'Carrefour San Martín',
        area: 'Galletitas',
        cantidadProductos: 60,
      ).build();

      final repo = FakeOtsRepository(initialLotes: [initialLote]);
      final start = DateTime(2026, 11, 12, 10, 0);

      final registro = RegistroTrabajoBuilder.standard(
        id: 'reg_atomic_01',
        loteId: 'lote_target_01',
        supermercado: 'Carrefour San Martín',
        area: 'Galletitas',
        cantidadProductos: 85,
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

      final updatedLote = repo.lotes.firstWhere((l) => l.id == 'lote_target_01');
      expect(updatedLote.ultimoInicio, equals(start));
      expect(updatedLote.proximoDesbloqueo, equals(registro.nuevoDesbloqueo));
      expect(updatedLote.cantidadProductos, equals(85));
    });

    // TEST-R2-T1-02: Unlock date advances exactly 120 calendar days
    test('TEST-R2-T1-02: Unlock date advances exactly 120 calendar days preserving hour and minute', () async {
      final repo = FakeOtsRepository(
        initialLotes: [
          LoteBuilder().withId('lote_120d').withSupermercado('Disco').withArea('Carnes').build(),
        ],
      );

      final inicio = DateTime(2026, 11, 12, 10, 30);
      final fin = DateTime(2026, 11, 12, 11, 15);
      final registro = RegistroTrabajoBuilder()
          .withId('reg_120d')
          .withLoteId('lote_120d')
          .withSupermercado('Disco')
          .withArea('Carnes')
          .withInicio(inicio)
          .withFin(fin)
          .build();

      await repo.guardarRegistro(registro);

      final updated = repo.lotes.firstWhere((l) => l.id == 'lote_120d');
      expect(updated.proximoDesbloqueo, isNotNull);
      expect(updated.proximoDesbloqueo!.year, equals(2027));
      expect(updated.proximoDesbloqueo!.month, equals(3));
      expect(updated.proximoDesbloqueo!.day, equals(12));
      expect(updated.proximoDesbloqueo!.hour, equals(10));
      expect(updated.proximoDesbloqueo!.minute, equals(30));
      expect(updated.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(inicio)));
    });

    // TEST-R2-T1-03: Active session cleared upon atomic save
    test('TEST-R2-T1-03: Active session is purged from storage upon atomic save completion', () async {
      final repo = FakeOtsRepository(
        initialLotes: [LoteBuilder.habilitado(id: 'lote_active').build()],
      );
      await repo.guardarSesionActiva({
        'loteId': 'lote_active',
        'inicio': '2026-11-12T10:00:00.000Z',
      });

      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();
      expect(vm.sesionActiva, isNotNull);

      await vm.guardarSesionFotos(
        loteId: 'lote_active',
        supermercado: 'Supermercado Test',
        area: 'Sector Test',
        cantidadProductos: 30,
        inicio: DateTime(2026, 11, 12, 10, 0),
        fin: DateTime(2026, 11, 12, 10, 45),
      );

      expect(vm.sesionActiva, isNull);
      expect(await repo.obtenerSesionActiva(), isNull);
      expect(vm.segundosTranscurridos, equals(0));
    });

    // TEST-R2-T1-04: ViewModel updates registros & lotes reactively
    test('TEST-R2-T1-04: ViewModel reactively updates registros and lotes collections', () async {
      final repo = FakeOtsRepository(
        initialLotes: [LoteBuilder.habilitado(id: 'lote_reactive').build()],
      );
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      final start = DateTime(2026, 11, 12, 8, 0);
      final end = DateTime(2026, 11, 12, 8, 30);
      await vm.guardarSesionFotos(
        loteId: 'lote_reactive',
        supermercado: 'Coto Abasto',
        area: 'Fiambrería',
        cantidadProductos: 40,
        inicio: start,
        fin: end,
      );

      expect(vm.registros.length, equals(1));
      expect(vm.registros.first.supermercado, equals('Coto Abasto'));
      expect(vm.registros.first.duracionMinutos, equals(30));
      expect(vm.lotes.first.ultimoInicio, equals(start));
      expect(notifyCount, greaterThan(0));
    });

    // TEST-R2-T1-05: Completed lot moves to lotesFuturos
    test('TEST-R2-T1-05: Completed lot transitions from lotesHabilitados to lotesFuturos', () async {
      final repo = FakeOtsRepository(
        initialLotes: [
          LoteBuilder.habilitado(
            id: 'lote_transition',
            supermercado: 'Jumbo Palermo',
            area: 'Bebidas',
          ).build(),
        ],
      );
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      expect(vm.lotesHabilitados.any((l) => l.id == 'lote_transition'), isTrue);
      expect(vm.lotesFuturos.any((l) => l.id == 'lote_transition'), isFalse);

      final start = DateTime.now().subtract(const Duration(minutes: 45));
      final end = DateTime.now();

      await vm.guardarSesionFotos(
        loteId: 'lote_transition',
        supermercado: 'Jumbo Palermo',
        area: 'Bebidas',
        cantidadProductos: 50,
        inicio: start,
        fin: end,
      );

      expect(vm.lotesHabilitados.any((l) => l.id == 'lote_transition'), isFalse);
      expect(vm.lotesFuturos.any((l) => l.id == 'lote_transition'), isTrue);

      final rescheduled = vm.lotesFuturos.firstWhere((l) => l.id == 'lote_transition');
      expect(rescheduled.proximoDesbloqueo!.isAfter(DateTime.now().add(const Duration(days: 100))), isTrue);
    });

    // TEST-R2-T1-06: Atomic rollback guarantees zero partial state on repository failure
    test('TEST-R2-T1-06: Failure during atomic batch aborts cleanly leaving zero partial state', () async {
      final initialLote = LoteBuilder.habilitado(
        id: 'lote_rollback_01',
        supermercado: 'Carrefour San Martín',
        area: 'Lácteos',
        cantidadProductos: 50,
      ).build();

      final repo = FakeOtsRepository(initialLotes: [initialLote]);
      repo.simulateFailOnGuardarRegistro = true;

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

      // 1. Direct repository verification: throws FirebaseException and commits ZERO partial state
      await expectLater(
        () => repo.guardarRegistro(registro),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );

      expect(repo.guardarRegistroCallCount, equals(1));
      expect(repo.atomicBatchesCommitted, equals(0));
      expect(repo.registros, isEmpty, reason: 'Work record must not be committed on aborted batch');
      expect(repo.batchLog.length, equals(1));
      expect(repo.batchLog.first.operation, equals('guardarRegistroAtomicBatch'));
      expect(repo.batchLog.first.succeeded, isFalse);

      final untouchedLote = repo.lotes.firstWhere((l) => l.id == 'lote_rollback_01');
      expect(untouchedLote.ultimoInicio, isNull, reason: 'Lot ultimoInicio must remain unmutated');
      expect(untouchedLote.proximoDesbloqueo, isNull, reason: 'Lot proximoDesbloqueo must remain unmutated');
      expect(untouchedLote.cantidadProductos, equals(50), reason: 'Lot product count must remain unchanged');

      // 2. ViewModel-level verification: exception surfaces and in-memory collections remain uncorrupted
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      expect(
        () async => await vm.guardarSesionFotos(
          loteId: 'lote_rollback_01',
          supermercado: 'Carrefour San Martín',
          area: 'Lácteos',
          cantidadProductos: 75,
          inicio: start,
          fin: start.add(const Duration(minutes: 45)),
        ),
        throwsA(isA<FirebaseException>()),
      );

      expect(vm.registros, isEmpty, reason: 'ViewModel registros must remain empty after failed save');
      final vmLote = vm.lotes.firstWhere((l) => l.id == 'lote_rollback_01');
      expect(vmLote.ultimoInicio, isNull);
      expect(vmLote.proximoDesbloqueo, isNull);
      expect(vm.lotesHabilitados.any((l) => l.id == 'lote_rollback_01'), isTrue);
      expect(vm.lotesFuturos.any((l) => l.id == 'lote_rollback_01'), isFalse);
    });
  });
}
