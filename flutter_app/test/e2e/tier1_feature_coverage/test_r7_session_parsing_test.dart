import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/repositories/ots_repository.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import '../harness/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockSharedPreferencesHelper.setEmpty();
  });

  group('R7: Tier 1 - Resilient SharedPreferences Session Parsing & Auto-Purge', () {
    test('TEST-R7-T1-01: Valid ISO timestamp parses correctly', () async {
      final startTime = DateTime.now().subtract(const Duration(minutes: 5));
      MockSharedPreferencesHelper.setValidSession(
        loteId: 'lote_seed_1',
        inicio: startTime,
      );

      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_seed_1',
          'supermercado': 'Carrefour San Martín',
          'area': 'Lácteos',
          'cantidadProductos': 50,
          'inicio': startTime.toIso8601String(),
        },
      );
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      expect(vm.sesionActiva, isNotNull);
      expect(vm.segundosTranscurridos, greaterThanOrEqualTo(290));
      expect(vm.cronometroTexto, matches(RegExp(r'^\d{2}:\d{2}$')));
    });

    test('TEST-R7-T1-02: Missing inicio key defaults safely to 0 and auto-purges', () async {
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_missing_inicio',
        },
      );
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(repo.sesionActiva, isNull);
    });

    test('TEST-R7-T1-03: Malformed date string handled without exception', () async {
      expect(TableroViewModel.parsearFechaInicio('not-a-valid-date'), isNull);
      expect(TableroViewModel.parsearFechaInicio('2026-99-99'), isNull);

      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_bad_date',
          'inicio': 'corrupted-timestamp-string',
        },
      );
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(repo.sesionActiva, isNull);
    });

    test('TEST-R7-T1-04: Non-string type for inicio handled without TypeError', () {
      const ms = 1731388800000;
      final parsedMs = TableroViewModel.parsearFechaInicio(ms);
      expect(parsedMs, equals(DateTime.fromMillisecondsSinceEpoch(ms)));

      expect(TableroViewModel.parsearFechaInicio(true), isNull);
      expect(TableroViewModel.parsearFechaInicio([1, 2, 3]), isNull);
      expect(TableroViewModel.parsearFechaInicio({'inicio': 123}), isNull);
    });

    test('TEST-R7-T1-05: Corrupted session in SharedPreferences auto-purged', () async {
      // 1. Arrange: Seed SharedPreferences with a corrupted session containing an unparseable timestamp
      MockSharedPreferencesHelper.setSessionWithMalformedDate(
        loteId: 'lote_seed_1',
        malformedDate: 'corrupted-timestamp-string-{{invalid_iso}}',
      );

      // Verify corrupted payload is physically present in SharedPreferences prior to initialization
      expect(await MockSharedPreferencesHelper.isSessionPurged(), isFalse);
      expect(await MockSharedPreferencesHelper.getRawSession(), isNotNull);

      // 2. Act: Initialize TableroViewModel with real LocalOtsRepository backed by SharedPreferences
      final repo = LocalOtsRepository();
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      // 3. Assert: In-memory ViewModel state safely recovered
      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(vm.isLoading, isFalse);
      expect(vm.lotes, isNotEmpty);

      // 4. Assert: Storage key was genuinely purged from SharedPreferences
      expect(await MockSharedPreferencesHelper.isSessionPurged(), isTrue);
      expect(await MockSharedPreferencesHelper.getRawSession(), isNull);
    });
  });
}
