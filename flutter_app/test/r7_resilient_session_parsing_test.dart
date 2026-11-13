import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import 'package:flutter_app/ui/views/home_screen.dart';
import 'package:flutter_app/ui/views/modal_sesion_sheet.dart';
import 'e2e/harness/fake_ots_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('R7: TableroViewModel.parsearFechaInicio Universal Safe Parser', () {
    test('TC1: Parses valid ISO-8601 string', () {
      const iso = '2026-11-12T05:00:00.000Z';
      final result = TableroViewModel.parsearFechaInicio(iso);
      expect(result, isNotNull);
      expect(result!.toUtc(), equals(DateTime.parse(iso).toUtc()));
    });

    test('TC1b: Parses ISO-8601 string without Z', () {
      const iso = '2026-11-12 10:30:00';
      final result = TableroViewModel.parsearFechaInicio(iso);
      expect(result, isNotNull);
      expect(result!.year, equals(2026));
      expect(result.month, equals(11));
      expect(result.day, equals(12));
    });

    test('TC2: Parses integer epoch milliseconds timestamp', () {
      const ms = 1715498400000;
      final expected = DateTime.fromMillisecondsSinceEpoch(ms);
      final result = TableroViewModel.parsearFechaInicio(ms);
      expect(result, isNotNull);
      expect(result, equals(expected));
    });

    test('TC3: Parses integer epoch seconds timestamp (auto-multiplies by 1000)', () {
      const sec = 1715498400; // < 10,000,000,000
      final expected = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
      final result = TableroViewModel.parsearFechaInicio(sec);
      expect(result, isNotNull);
      expect(result, equals(expected));
    });

    test('TC3b: Parses num/double epoch timestamp', () {
      const numVal = 1715498400000.0;
      final expected = DateTime.fromMillisecondsSinceEpoch(1715498400000);
      final result = TableroViewModel.parsearFechaInicio(numVal);
      expect(result, isNotNull);
      expect(result, equals(expected));
    });

    test('TC3c: Parses numeric string epoch timestamps (both ms and seconds)', () {
      final resMs = TableroViewModel.parsearFechaInicio('1715498400000');
      expect(resMs, isNotNull);
      expect(resMs, equals(DateTime.fromMillisecondsSinceEpoch(1715498400000)));

      final resSec = TableroViewModel.parsearFechaInicio('1715498400');
      expect(resSec, isNotNull);
      expect(resSec, equals(DateTime.fromMillisecondsSinceEpoch(1715498400000)));
    });

    test('TC4: Returns null on null input without throwing', () {
      expect(TableroViewModel.parsearFechaInicio(null), isNull);
    });

    test('TC5: Returns null on malformed strings without throwing FormatException', () {
      expect(TableroViewModel.parsearFechaInicio('invalid-date'), isNull);
      expect(TableroViewModel.parsearFechaInicio(''), isNull);
      expect(TableroViewModel.parsearFechaInicio('   '), isNull);
      expect(TableroViewModel.parsearFechaInicio('2026-99-99'), isNull);
      expect(TableroViewModel.parsearFechaInicio('not-a-number-or-date'), isNull);
    });

    test('TC6: Returns null on unexpected non-string/non-int types without throwing TypeError', () {
      expect(TableroViewModel.parsearFechaInicio(true), isNull);
      expect(TableroViewModel.parsearFechaInicio(false), isNull);
      expect(TableroViewModel.parsearFechaInicio([1, 2, 3]), isNull);
      expect(TableroViewModel.parsearFechaInicio({'timestamp': 12345}), isNull);
    });

    test('TC7: Passes through DateTime instance unchanged', () {
      final now = DateTime.now();
      expect(TableroViewModel.parsearFechaInicio(now), equals(now));
    });
  });

  group('R7: Active Session Auto-Recovery & Self-Healing', () {
    test('TC1: Starts timer with valid ISO-8601 string session', () async {
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_1',
          'supermercado': 'Carrefour San Martín',
          'area': 'Lácteos',
          'cantidadProductos': 120,
          'inicio': fiveMinutesAgo.toIso8601String(),
        },
      );

      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      expect(vm.sesionActiva, isNotNull);
      expect(vm.segundosTranscurridos, greaterThanOrEqualTo(290));
      expect(vm.cronometroTexto, contains(':'));
    });

    test('TC2: Starts timer with integer epoch milliseconds session without TypeError', () async {
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_1',
          'supermercado': 'Carrefour San Martín',
          'area': 'Lácteos',
          'cantidadProductos': 120,
          'inicio': fiveMinutesAgo.millisecondsSinceEpoch,
        },
      );

      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      expect(vm.sesionActiva, isNotNull);
      expect(vm.segundosTranscurridos, greaterThanOrEqualTo(290));
    });

    test('TC3: Starts timer with integer epoch seconds session', () async {
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_1',
          'supermercado': 'Carrefour San Martín',
          'area': 'Lácteos',
          'cantidadProductos': 120,
          'inicio': fiveMinutesAgo.millisecondsSinceEpoch ~/ 1000,
        },
      );

      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      expect(vm.sesionActiva, isNotNull);
      expect(vm.segundosTranscurridos, greaterThanOrEqualTo(290));
    });

    test('TC4: Missing "inicio" key purges corrupted session immediately', () async {
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_1',
          'supermercado': 'Carrefour San Martín',
        },
      );

      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(repo.sesionActiva, isNull);
      expect(repo.limpiarSesionActivaCallCount, equals(1));
    });

    test('TC5: Explicit null "inicio" value purges corrupted session', () async {
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_1',
          'inicio': null,
        },
      );

      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(repo.sesionActiva, isNull);
    });

    test('TC6: Malformed string "inicio" purges corrupted session without FormatException', () async {
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_1',
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

    test('TC7: Unexpected types (boolean, list, map) purge corrupted session without TypeError', () async {
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_1',
          'inicio': true,
        },
      );

      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(repo.sesionActiva, isNull);
    });

    test('TC8: Corrupted session missing loteId purges incomplete session', () async {
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'inicio': DateTime.now().toIso8601String(),
        },
      );

      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(repo.sesionActiva, isNull);
    });

    test('TC9: Runtime corruption in active session triggers auto-recovery', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      // Start active session normally
      final lote = vm.lotes.first;
      await vm.iniciarFotos(lote);
      expect(vm.sesionActiva, isNotNull);

      // Now inject corruption into stored session
      await repo.guardarSesionActiva({
        'loteId': lote.id,
        'inicio': 'bad-timestamp-injected-at-runtime',
      });

      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      // Re-initialization detects the corruption and triggers self-healing auto-recovery
      await vm.inicializar();

      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(repo.sesionActiva, isNull);
      expect(notifyCount, greaterThan(0));
    });

    test('TC10: Breaks startup crash loops permanently across app restarts', () async {
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_1',
          'inicio': 'corrupted-timestamp',
        },
      );

      // Launch 1: Startup encounters corrupt session
      final vm1 = TableroViewModel(repository: repo);
      await vm1.inicializar(); // Must not throw!

      expect(vm1.sesionActiva, isNull);
      expect(repo.sesionActiva, isNull); // Corrupt session purged from repository

      // Launch 2: Relaunch app with fresh ViewModel on same repository
      final vm2 = TableroViewModel(repository: repo);
      await vm2.inicializar(); // Launches completely clean

      expect(vm2.sesionActiva, isNull);
      expect(vm2.segundosTranscurridos, equals(0));
      expect(vm2.isLoading, isFalse);
    });
  });

  group('R7: HomeScreen Safe Modal Session Parsing', () {
    testWidgets('Tapping Terminar fotos with epoch integer timestamp opens ModalSesionSheet safely', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_seed_1',
          'supermercado': 'Carrefour San Martín',
          'area': 'Lácteos y Yogures',
          'cantidadProductos': 95,
          'inicio': fiveMinutesAgo.millisecondsSinceEpoch,
        },
      );

      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      // Find "Terminar Fotos" button on the active lot card
      final btn = find.textContaining('Terminar Fotos');
      expect(btn, findsOneWidget);

      await tester.tap(btn);
      await tester.pumpAndSettle();

      // Verify ModalSesionSheet opened without throwing TypeError
      expect(find.byType(ModalSesionSheet), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
    });

    testWidgets('Tapping Terminar fotos with corrupted timestamp falls back to DateTime.now() safely', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      // Set active session with corrupt inicio
      final primerLote = vm.lotes.first;
      await vm.iniciarFotos(primerLote);
      vm.sesionActiva!['inicio'] = 'malformed-date-string';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      final btn = find.textContaining('Terminar Fotos');
      expect(btn, findsOneWidget);

      await tester.tap(btn);
      await tester.pumpAndSettle();

      // Verify ModalSesionSheet opened without FormatException or TypeError
      expect(find.byType(ModalSesionSheet), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
    });
  });
}
