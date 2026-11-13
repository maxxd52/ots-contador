import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/repositories/ots_repository.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import 'package:flutter_app/ui/views/home_screen.dart';
import '../harness/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockSharedPreferencesHelper.setEmpty();
  });

  group('Tier 2 - R7: Corruption Bounds & Session Recovery Resilience', () {
    // TEST-R7-T2-01: Periodic timer ticks 5 seconds with bad data without crash
    testWidgets('TEST-R7-T2-01: Periodic timer ticks 5 seconds with bad data without crash loop', (tester) async {
      MockSharedPreferencesHelper.setSessionWithMalformedDate(
        loteId: 'lote_corrupt_tick',
        malformedDate: 'corrupted-datetime-string',
      );

      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_corrupt_tick',
          'inicio': 'corrupted-datetime-string',
        },
      );
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);

      await vm.inicializar();

      // Tick 5 consecutive seconds with bounded pumps
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(tester.takeException(), isNull);
      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(vm.cronometroTexto, equals('00:00'));
    });

    // TEST-R7-T2-02: Future timestamp (clock skew) clamps elapsed seconds to 0
    test('TEST-R7-T2-02: Future timestamp due to clock skew clamps elapsed seconds to 0 and formats 00:00', () async {
      final futureStart = DateTime.now().add(const Duration(hours: 2));
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_future_1',
          'supermercado': 'Carrefour San Martín',
          'area': 'Lácteos',
          'cantidadProductos': 50,
          'inicio': futureStart.toIso8601String(),
        },
      );
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);

      await vm.inicializar();

      expect(vm.sesionActiva, isNotNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(vm.cronometroTexto, equals('00:00'));
    });

    // TEST-R7-T2-03: HomeScreen completion modal handles corrupt session
    testWidgets('TEST-R7-T2-03: HomeScreen mounts cleanly without red screen when active session is corrupted', (tester) async {
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

      MockSharedPreferencesHelper.setSessionWithMalformedDate(
        loteId: 'lote_seed_1',
        malformedDate: 'corrupted-timestamp',
      );

      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_seed_1',
          'supermercado': 'Carrefour San Martín',
          'area': 'Lácteos',
          'cantidadProductos': 50,
          'inicio': 'corrupted-timestamp',
        },
      );
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      await tester.pumpWidget(OtsApp(viewModel: vm));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(vm.sesionActiva, isNull);
    });

    // TEST-R7-T2-04: Concurrent read and purge of corrupted session
    test('TEST-R7-T2-04: Concurrent read and purge of corrupted session resolves without race condition', () async {
      MockSharedPreferencesHelper.setSessionWithMalformedDate(
        loteId: 'lote_seed_1',
        malformedDate: 'corrupt-date-concurrent',
      );
      final repo = LocalOtsRepository();

      // Execute concurrent read and purge operations
      final f1 = repo.obtenerSesionActiva();
      final f2 = repo.limpiarSesionActiva();
      final f3 = repo.obtenerSesionActiva();

      final results = await Future.wait([f1, f2, f3]);
      expect(results, isNotNull);
      expect(await MockSharedPreferencesHelper.isSessionPurged(), isTrue);
    });

    // TEST-R7-T2-05: Extremely large corrupt string (1MB) in storage handled
    test('TEST-R7-T2-05: Extremely large corrupt string (1MB) in storage is parsed safely without memory crash', () async {
      MockSharedPreferencesHelper.setLargeGarbageSession(1024 * 1024);
      expect(await MockSharedPreferencesHelper.isSessionPurged(), isFalse);

      final repo = LocalOtsRepository();
      // 1. Direct repository read of 1MB non-JSON string safely returns null without crash
      final sesion = await repo.obtenerSesionActiva();
      expect(sesion, isNull);

      // 2. ViewModel initialization succeeds cleanly without OutOfMemoryError
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);

      await vm.inicializar();

      expect(vm.sesionActiva, isNull);
      expect(vm.isLoading, isFalse);
      expect(vm.segundosTranscurridos, equals(0));

      // 3. Purging oversized garbage clears storage cleanly
      await repo.limpiarSesionActiva();
      expect(await MockSharedPreferencesHelper.isSessionPurged(), isTrue);
    });
  });
}
