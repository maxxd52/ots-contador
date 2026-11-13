import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/datasources/seed_data.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import 'package:flutter_app/ui/views/home_screen.dart';
import '../harness/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockSharedPreferencesHelper.setEmpty();
  });

  group('Tier 2 - R1: Startup Boundaries & Cold Start Limits', () {
    // TEST-R1-T2-01: Quota exceeded exception handled during launch
    testWidgets('TEST-R1-T2-01: Quota exceeded exception handled during launch and falls back to seed data', (tester) async {
      final fakeRepo = FakeOtsRepository(useSeedData: false);
      fakeRepo.simulateQuotaExceeded = true;
      final viewModel = TableroViewModel(repository: fakeRepo, isOffline: false);
      addTearDown(viewModel.dispose);

      await viewModel.inicializar();
      await tester.pumpWidget(OtsApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isOffline, isTrue);
      expect(viewModel.errorMessage, contains('resource-exhausted'));
      expect(viewModel.lotes.length, equals(SeedData.obtenerLotesIniciales().length));
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Modo sin conexión: operando con datos locales.'), findsOneWidget);
    });

    // TEST-R1-T2-02: Slow remote fetch (>5s) does not freeze UI
    testWidgets('TEST-R1-T2-02: Slow remote fetch does not freeze UI and renders progress spinner', (tester) async {
      final fakeRepo = FakeOtsRepository(
        initialLotes: [
          LoteBuilder().withId('lote_slow').withSupermercado('Carrefour Slow').build(),
        ],
      );
      fakeRepo.simulateDelay = const Duration(milliseconds: 300);
      final viewModel = TableroViewModel(repository: fakeRepo);
      addTearDown(viewModel.dispose);

      unawaited(viewModel.inicializar());
      await tester.pumpWidget(OtsApp(viewModel: viewModel));
      await tester.pump(const Duration(milliseconds: 50));

      expect(viewModel.isLoading, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.lotes.length, equals(1));
      expect(find.text('Carrefour Slow'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // TEST-R1-T2-03: Permission denied during startup handled
    testWidgets('TEST-R1-T2-03: Permission denied during startup handled safely into offline mode', (tester) async {
      final fakeRepo = FakeOtsRepository(useSeedData: false);
      fakeRepo.simulatePermissionDenied = true;
      final viewModel = TableroViewModel(repository: fakeRepo, isOffline: false);
      addTearDown(viewModel.dispose);

      await viewModel.inicializar();
      await tester.pumpWidget(OtsApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isOffline, isTrue);
      expect(viewModel.errorMessage, contains('permission-denied'));
      expect(viewModel.lotes.length, equals(SeedData.obtenerLotesIniciales().length));
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Modo sin conexión: operando con datos locales.'), findsOneWidget);
    });

    // TEST-R1-T2-04: Cold start with empty cache and no network
    test('TEST-R1-T2-04: Cold start with empty cache and no network generates seed lotes', () async {
      MockSharedPreferencesHelper.setEmpty();
      final repo = FakeOtsRepository(initialLotes: []);
      repo.simulateNetworkError = true;
      final viewModel = TableroViewModel(repository: repo);
      addTearDown(viewModel.dispose);

      await viewModel.inicializar();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isOffline, isTrue);
      expect(viewModel.lotes.length, equals(SeedData.obtenerLotesIniciales().length));
      expect(viewModel.lotes.first.supermercado, equals('Carrefour San Martín'));
    });

    // TEST-R1-T2-05: Rapid repeated calls to inicializar() re-entry
    test('TEST-R1-T2-05: Rapid repeated calls to inicializar() re-entry produce no duplicate entities', () async {
      final fakeRepo = FakeOtsRepository(useSeedData: true);
      fakeRepo.simulateDelay = const Duration(milliseconds: 30);
      final viewModel = TableroViewModel(repository: fakeRepo);
      addTearDown(viewModel.dispose);

      await Future.wait([
        viewModel.inicializar(),
        viewModel.inicializar(),
        viewModel.inicializar(),
      ]);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.lotes.length, equals(SeedData.obtenerLotesIniciales().length));
      final uniqueIds = viewModel.lotes.map((l) => l.id).toSet();
      expect(uniqueIds.length, equals(SeedData.obtenerLotesIniciales().length));
    });
  });
}
