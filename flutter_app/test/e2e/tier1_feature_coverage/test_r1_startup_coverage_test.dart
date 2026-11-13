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

  group('Tier 1 - R1: Startup Resilience & Crash Prevention', () {
    // TEST-R1-T1-01: Nominal online launch loads remote lotes
    test('TEST-R1-T1-01: Nominal online launch loads remote lotes and clears loading state', () async {
      final fakeRepo = FakeOtsRepository(
        initialLotes: [
          LoteBuilder().withId('lote_1').withSupermercado('Carrefour Norte').build(),
          LoteBuilder().withId('lote_2').withSupermercado('Coto Once').build(),
          LoteBuilder().withId('lote_3').withSupermercado('Dia Palermo').build(),
        ],
      );
      final viewModel = TableroViewModel(repository: fakeRepo, isOffline: false);
      addTearDown(viewModel.dispose);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.lotes.isEmpty, isTrue);

      await viewModel.inicializar();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isOffline, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.lotes.length, equals(3));
      expect(fakeRepo.obtenerLotesCallCount, equals(1));
    });

    // TEST-R1-T1-02: Offline network error caught gracefully
    test('TEST-R1-T1-02: Offline network error caught gracefully with fallback to SeedData', () async {
      final fakeRepo = FakeOtsRepository();
      fakeRepo.simulateNetworkError = true;
      final viewModel = TableroViewModel(repository: fakeRepo);
      addTearDown(viewModel.dispose);

      // Must complete without throwing unhandled FirebaseException
      await viewModel.inicializar();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isOffline, isTrue);
      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.lotes.isNotEmpty, isTrue);
      expect(viewModel.lotes.length, equals(SeedData.obtenerLotesIniciales().length));
      expect(viewModel.lotes.first.supermercado, equals('Carrefour San Martín'));
    });

    // TEST-R1-T1-03: UI mounts cleanly on Firestore failure
    testWidgets('TEST-R1-T1-03: UI mounts cleanly without red screen on Firestore failure', (tester) async {
      final fakeRepo = FakeOtsRepository();
      fakeRepo.simulateNetworkError = true;
      final viewModel = TableroViewModel(repository: fakeRepo, isOffline: true);
      addTearDown(viewModel.dispose);
      await viewModel.inicializar();

      await tester.pumpWidget(OtsApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('OTS 120 Días'), findsOneWidget);
    });

    // TEST-R1-T1-04: ViewModel isLoading resets to false on failure
    test('TEST-R1-T1-04: ViewModel isLoading is guaranteed to reset to false on failure', () async {
      final fakeRepo = FakeOtsRepository();
      fakeRepo.simulateFailOnObtenerLotes = true;
      final viewModel = TableroViewModel(repository: fakeRepo);
      addTearDown(viewModel.dispose);

      expect(viewModel.isLoading, isFalse);

      await viewModel.inicializar();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.isOffline, isTrue);
    });

    // TEST-R1-T1-05: Offline indicator banner is visible when launched offline
    testWidgets('TEST-R1-T1-05: Offline indicator banner is visible when launched offline', (tester) async {
      final fakeRepo = FakeOtsRepository();
      fakeRepo.simulateNetworkError = true;
      final viewModel = TableroViewModel(repository: fakeRepo, isOffline: true);
      addTearDown(viewModel.dispose);
      await viewModel.inicializar();

      await tester.pumpWidget(OtsApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Modo sin conexión: operando con datos locales.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
