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

  group('Tier 2 - R2: Persistence Boundaries & Atomic Fault Tolerance', () {
    // TEST-R2-T2-01: Network drop mid-batch leaves zero partial state
    test('TEST-R2-T2-01: Network drop mid-batch leaves zero partial state in repository and ViewModel', () async {
      final fakeRepo = FakeOtsRepository(
        initialLotes: [
          LoteBuilder()
              .withId('lote_atomic_1')
              .withSupermercado('Carrefour Norte')
              .withArea('Almacén')
              .build(),
        ],
      );
      fakeRepo.simulateFailOnGuardarRegistro = true;

      final registro = RegistroTrabajoBuilder()
          .withId('reg_fail_1')
          .withLoteId('lote_atomic_1')
          .build();

      // 1. Direct repository write failure leaves zero partial state
      await expectLater(
        () => fakeRepo.guardarRegistro(registro),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );

      expect(fakeRepo.registros, isEmpty);
      expect(fakeRepo.atomicBatchesCommitted, equals(0));
      expect(fakeRepo.lotes.first.ultimoInicio, isNull);
      expect(fakeRepo.lotes.first.proximoDesbloqueo, isNull);

      // 2. ViewModel invocation failure preserves zero partial state
      final viewModel = TableroViewModel(repository: fakeRepo);
      addTearDown(viewModel.dispose);
      await viewModel.inicializar();

      await expectLater(
        () => viewModel.guardarSesionFotos(
          loteId: 'lote_atomic_1',
          supermercado: 'Carrefour Norte',
          area: 'Almacén',
          cantidadProductos: 50,
          inicio: DateTime(2026, 11, 12, 10, 0),
          fin: DateTime(2026, 11, 12, 10, 45),
        ),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );

      expect(viewModel.registros, isEmpty);
      expect(fakeRepo.registros, isEmpty);
      expect(fakeRepo.atomicBatchesCommitted, equals(0));
      expect(viewModel.lotes.first.ultimoInicio, isNull);
      expect(viewModel.lotes.first.proximoDesbloqueo, isNull);
    });

    // TEST-R2-T2-02: Non-existent lot ID handles batch insertion cleanly
    test('TEST-R2-T2-02: Non-existent lot ID handles batch insertion cleanly via upsert', () async {
      final repo = FakeOtsRepository(initialLotes: []);
      final registro = RegistroTrabajoBuilder()
          .withId('reg_unreg_1')
          .withLoteId('lote_unregistered_999')
          .withSupermercado('Super Desconocido')
          .withArea('Perfumería')
          .build();

      final saved = await repo.guardarRegistro(registro);

      expect(saved.id, equals('reg_unreg_1'));
      expect(repo.registros.length, equals(1));
      expect(repo.atomicBatchesCommitted, equals(1));
      expect(repo.lotes.length, equals(1));

      final createdLote = repo.lotes.firstWhere((l) => l.id == 'lote_unregistered_999');
      expect(createdLote.supermercado, equals('Super Desconocido'));
      expect(createdLote.area, equals('Perfumería'));
      expect(createdLote.ultimoInicio, equals(registro.inicio));
      expect(createdLote.proximoDesbloqueo, equals(registro.nuevoDesbloqueo));
    });

    // TEST-R2-T2-03: Zero-duration session (inicio == fin) commits atomically
    test('TEST-R2-T2-03: Zero-duration session (inicio == fin) commits atomically and reschedules', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      final targetLote = repo.lotes.first;
      final now = DateTime(2026, 11, 12, 14, 0);

      final regZero = RegistroTrabajoBuilder.zeroDuration(
        id: 'reg_zero_1',
        loteId: targetLote.id,
        timestamp: now,
      ).build();

      final saved = await repo.guardarRegistro(regZero);

      expect(saved.duracionMinutos, equals(0));
      expect(saved.horasDecimales, equals(0.0));
      expect(saved.duracionTexto, anyOf(equals('0m'), equals('0h 0m')));
      expect(repo.atomicBatchesCommitted, equals(1));

      final updatedLote = repo.lotes.firstWhere((l) => l.id == targetLote.id);
      expect(updatedLote.ultimoInicio, equals(now));
      expect(updatedLote.proximoDesbloqueo, equals(TimeCalculator.calcularProximoDesbloqueo(now)));
    });

    // TEST-R2-T2-04: Leap-year traversal across 120 days in atomic batch
    test('TEST-R2-T2-04: Leap-year traversal across 120 days preserves calendar accuracy in atomic batch', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      final targetLote = repo.lotes.first;
      final leapStart = DateTime(2028, 1, 15, 10, 30);
      final leapFin = leapStart.add(const Duration(minutes: 45));

      final regLeap = RegistroTrabajoBuilder()
          .withId('reg_leap_1')
          .withLoteId(targetLote.id)
          .withInicio(leapStart)
          .withFin(leapFin)
          .build();

      await repo.guardarRegistro(regLeap);

      final expectedUnlock = TimeCalculator.calcularProximoDesbloqueo(leapStart);
      expect(regLeap.nuevoDesbloqueo, equals(expectedUnlock));
      expect(regLeap.nuevoDesbloqueo, equals(DateTime(2028, 5, 14, 10, 30)));
      expect(regLeap.nuevoDesbloqueo.difference(leapStart).inDays, equals(120));

      final updatedLote = repo.lotes.firstWhere((l) => l.id == targetLote.id);
      expect(updatedLote.proximoDesbloqueo, equals(expectedUnlock));
    });

    // TEST-R2-T2-05: Redundancy elimination in ViewModel verified
    test('TEST-R2-T2-05: Redundancy elimination in ViewModel verified with exactly 1 atomic write', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      final lote = vm.lotes.first;
      await vm.guardarSesionFotos(
        loteId: lote.id,
        supermercado: lote.supermercado,
        area: lote.area,
        cantidadProductos: lote.cantidadProductos,
        inicio: DateTime(2026, 11, 12, 10, 0),
        fin: DateTime(2026, 11, 12, 11, 0),
      );

      expect(repo.guardarRegistroCallCount, equals(1));
      expect(repo.guardarLoteCallCount, equals(0));
      expect(repo.atomicBatchesCommitted, equals(1));
    });
  });
}
