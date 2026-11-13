import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/data/datasources/seed_data.dart';
import 'package:flutter_app/data/repositories/firestore_repository.dart';
import 'package:flutter_app/data/repositories/ots_repository.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/domain/models/registro_trabajo.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import 'package:flutter_app/ui/views/home_screen.dart';
import 'e2e/harness/fake_ots_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('R1: OtsApp Startup & Mount Resilience', () {
    testWidgets('OtsApp mounts immediately on frame 1 without remote I/O delay', (tester) async {
      final fakeRepo = FakeOtsRepository(useSeedData: true);
      final viewModel = TableroViewModel(repository: fakeRepo);

      // Mount widget tree immediately
      await tester.pumpWidget(OtsApp(viewModel: viewModel));

      // Confirm MaterialApp and HomeScreen are mounted
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('OTS 120 Días'), findsOneWidget);
    });

    testWidgets('OtsApp mounts and displays offline banner when launched in offline mode', (tester) async {
      final localRepo = LocalOtsRepository();
      final viewModel = TableroViewModel(repository: localRepo, isOffline: true);
      await viewModel.inicializar();

      await tester.pumpWidget(OtsApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Modo sin conexión: operando con datos locales.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('R1: FirestoreOtsRepository Resilience & 3-Tier Fallback', () {
    test('Fallback to SeedData on cold offline launch with empty cache', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final repo = FirestoreOtsRepository(prefs: prefs);
      expect(repo.isOffline, isFalse);

      // Firestore will throw [core/no-app] or network error without backend
      final lotes = await repo.obtenerLotes();

      expect(repo.isOffline, isTrue);
      expect(lotes.isNotEmpty, isTrue);
      expect(lotes.length, equals(5));
      expect(lotes.first.supermercado, equals('Carrefour San Martín'));

      // Confirm seed data was cached to SharedPreferences
      final cachedJson = prefs.getString(FirestoreOtsRepository.keyLotes);
      expect(cachedJson, isNotNull);
      final List<dynamic> decoded = jsonDecode(cachedJson!);
      expect(decoded.length, equals(5));
    });

    test('Fallback to SharedPreferences cache when Firestore is unavailable and cache exists', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final cachedLote = Lote(
        id: 'lote_cache_1',
        supermercado: 'Supermercado Offline Cache',
        area: 'Lácteos',
        cantidadProductos: 50,
        creadoEn: DateTime(2026, 1, 1),
      );
      await prefs.setString(
        FirestoreOtsRepository.keyLotes,
        jsonEncode([cachedLote.toJson()]),
      );

      final repo = FirestoreOtsRepository(prefs: prefs);
      final lotes = await repo.obtenerLotes();

      expect(repo.isOffline, isTrue);
      expect(lotes.length, equals(1));
      expect(lotes.first.id, equals('lote_cache_1'));
      expect(lotes.first.supermercado, equals('Supermercado Offline Cache'));
    });

    test('Fallback to cached Registros when Firestore is unavailable', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final cachedRegistro = RegistroTrabajo.crear(
        id: 'reg_cache_1',
        loteId: 'lote_1',
        supermercado: 'Coto Cache',
        area: 'Bebidas',
        cantidadProductos: 30,
        inicio: DateTime(2026, 11, 10, 10, 0),
        fin: DateTime(2026, 11, 10, 10, 30),
      );
      await prefs.setString(
        FirestoreOtsRepository.keyRegistros,
        jsonEncode([cachedRegistro.toJson()]),
      );

      final repo = FirestoreOtsRepository(prefs: prefs);
      final registros = await repo.obtenerRegistros();

      expect(repo.isOffline, isTrue);
      expect(registros.length, equals(1));
      expect(registros.first.id, equals('reg_cache_1'));
      expect(registros.first.supermercado, equals('Coto Cache'));
    });
  });

  group('R1: TableroViewModel Error Recovery & Reconnection', () {
    test('inicializar() catches repository exception, sets isOffline and errorMessage, falls back to SeedData', () async {
      final fakeRepo = FakeOtsRepository();
      fakeRepo.simulateFailOnObtenerLotes = true;

      final vm = TableroViewModel(repository: fakeRepo);
      expect(vm.isOffline, isFalse);
      expect(vm.errorMessage, isNull);

      await vm.inicializar();

      expect(vm.isLoading, isFalse);
      expect(vm.isOffline, isTrue);
      expect(vm.errorMessage, isNotNull);
      expect(vm.lotes.isNotEmpty, isTrue);
      expect(vm.lotes.length, equals(5));
    });

    test('reintentar() clears errorMessage and recovers isOffline when repository recovers', () async {
      final fakeRepo = FakeOtsRepository();
      fakeRepo.simulateFailOnObtenerLotes = true;

      final vm = TableroViewModel(repository: fakeRepo);
      await vm.inicializar();

      expect(vm.isOffline, isTrue);
      expect(vm.errorMessage, isNotNull);

      // Restore repository connectivity
      fakeRepo.simulateFailOnObtenerLotes = false;
      await vm.reintentar();

      expect(vm.isOffline, isFalse);
      expect(vm.errorMessage, isNull);
    });

    test('isOffline returns true if repository is LocalOtsRepository', () async {
      final localRepo = LocalOtsRepository();
      final vm = TableroViewModel(repository: localRepo);

      expect(vm.isOffline, isTrue);
    });
  });

  group('R1: HomeScreen UI Offline Banner & Responsive Loading', () {
    testWidgets('Renders offline banner with retry button when isOffline is true', (tester) async {
      final fakeRepo = FakeOtsRepository(useSeedData: true);
      fakeRepo.simulateFailOnObtenerLotes = true;
      final vm = TableroViewModel(repository: fakeRepo, isOffline: true);
      await vm.inicializar();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Modo sin conexión: operando con datos locales.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('Hides offline banner when isOffline is false', (tester) async {
      final fakeRepo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: fakeRepo, isOffline: false);
      await vm.inicializar();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off), findsNothing);
      expect(find.text('Modo sin conexión: operando con datos locales.'), findsNothing);
    });

    testWidgets('Tapping Reintentar in offline banner triggers reintentar() and recovers', (tester) async {
      final fakeRepo = FakeOtsRepository(useSeedData: true);
      fakeRepo.simulateFailOnObtenerLotes = true;
      final vm = TableroViewModel(repository: fakeRepo, isOffline: true);
      await vm.inicializar();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reintentar'), findsOneWidget);
      final initialCount = fakeRepo.obtenerLotesCallCount;

      fakeRepo.simulateFailOnObtenerLotes = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(fakeRepo.obtenerLotesCallCount, greaterThan(initialCount));
      expect(vm.isOffline, isFalse);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });

    testWidgets('Shows full-screen CircularProgressIndicator only when isLoading is true and lotes is empty', (tester) async {
      final compRepo = _CompleterOtsRepository();
      final vm = TableroViewModel(repository: compRepo);

      // Start initialization: enters loading state while lotes is empty
      final initFuture = vm.inicializar();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(viewModel: vm),
        ),
      );
      await tester.pump();

      // Full-screen spinner is shown when loading and empty
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete fetch
      compRepo.lotesCompleter.complete([]);
      compRepo.regCompleter.complete([]);
      await initFuture;
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Does not show full-screen spinner if lotes already loaded during subsequent reload', (tester) async {
      final compRepo = _CompleterOtsRepository();
      compRepo.lotesCompleter.complete(SeedData.obtenerLotesIniciales());
      compRepo.regCompleter.complete([]);

      final vm = TableroViewModel(repository: compRepo);
      await vm.inicializar(); // Populates lotes: now vm.lotes has 5 items

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OTS 120 Días'), findsOneWidget);

      // Now prepare a second fetch (reintentar) with a pending completer
      compRepo.lotesCompleter = Completer<List<Lote>>();
      compRepo.regCompleter = Completer<List<RegistroTrabajo>>();
      final reloadFuture = vm.reintentar();

      await tester.pump(); // Frame while isLoading is true but lotes is NOT empty

      // Spinner should NOT take over the full screen!
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('OTS 120 Días'), findsOneWidget);

      compRepo.lotesCompleter.complete(SeedData.obtenerLotesIniciales());
      compRepo.regCompleter.complete([]);
      await reloadFuture;
      await tester.pumpAndSettle();
    });
  });
}

class _CompleterOtsRepository implements OtsRepository {
  Completer<List<Lote>> lotesCompleter = Completer<List<Lote>>();
  Completer<List<RegistroTrabajo>> regCompleter = Completer<List<RegistroTrabajo>>();

  @override
  Future<List<Lote>> obtenerLotes() => lotesCompleter.future;

  @override
  Future<List<RegistroTrabajo>> obtenerRegistros() => regCompleter.future;

  @override
  Future<Map<String, dynamic>?> obtenerSesionActiva() async => null;

  @override
  Future<Lote> guardarLote(Lote lote) async => lote;

  @override
  Future<void> eliminarLote(String id) async {}

  @override
  Future<RegistroTrabajo> guardarRegistro(RegistroTrabajo registro) async => registro;

  @override
  Future<void> guardarSesionActiva(Map<String, dynamic> sesion) async {}

  @override
  Future<void> limpiarSesionActiva() async {}
}
