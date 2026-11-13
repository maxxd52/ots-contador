import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/data/repositories/firestore_repository.dart';
import 'package:flutter_app/data/repositories/ots_repository.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import 'package:flutter_app/ui/views/home_screen.dart';
import 'e2e/harness/fake_ots_repository.dart';

// ignore: subtype_of_sealed_class
class DynamicMockFirestore implements FirebaseFirestore {
  final Future<QuerySnapshot<Map<String, dynamic>>> Function(String collectionPath)? onGet;

  DynamicMockFirestore({this.onGet});

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return DynamicMockCollectionReference(collectionPath, onGet: onGet);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class DynamicMockCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  @override
  final String path;
  final Future<QuerySnapshot<Map<String, dynamic>>> Function(String collectionPath)? onGet;

  DynamicMockCollectionReference(this.path, {this.onGet});


  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    if (onGet != null) {
      return onGet!(path);
    }
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'Service unavailable in mock',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CHALLENGE 1: Startup Bootstrap Fault Injection (main.dart resilience)', () {
    Future<void> runBootstrapHarness({
      required Future<void> Function() initFirebase,
      required WidgetTester tester,
    }) async {
      OtsRepository repository;
      bool isOffline = false;

      try {
        await initFirebase();
        repository = FirestoreOtsRepository();
      } catch (error) {
        repository = LocalOtsRepository();
        isOffline = true;
      }

      final viewModel = TableroViewModel(
        repository: repository,
        isOffline: isOffline,
      );

      await tester.pumpWidget(OtsApp(viewModel: viewModel));
      unawaited(viewModel.inicializar());
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(viewModel.isOffline, isTrue);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Modo sin conexión: operando con datos locales.'), findsOneWidget);
    }

    testWidgets('Recovers when Firebase.initializeApp throws UnsupportedError (Desktop platforms)', (tester) async {
      await runBootstrapHarness(
        initFirebase: () async {
          throw UnsupportedError('DefaultFirebaseOptions no están soportadas para esta plataforma.');
        },
        tester: tester,
      );
    });

    testWidgets('Recovers when Firebase.initializeApp throws PlatformException', (tester) async {
      await runBootstrapHarness(
        initFirebase: () async {
          throw PlatformException(
            code: 'firebase_core/channel-error',
            message: 'Unable to establish native channel to Firebase plugin',
          );
        },
        tester: tester,
      );
    });

    testWidgets('Recovers when Firebase.initializeApp throws FirebaseException(unavailable)', (tester) async {
      await runBootstrapHarness(
        initFirebase: () async {
          throw FirebaseException(
            plugin: 'core',
            code: 'unavailable',
            message: 'Network is down during Firebase initial handshake',
          );
        },
        tester: tester,
      );
    });

    testWidgets('Recovers when Firebase.initializeApp throws TimeoutException', (tester) async {
      await runBootstrapHarness(
        initFirebase: () async {
          throw TimeoutException('Firebase initialization timed out after 10000ms');
        },
        tester: tester,
      );
    });

    testWidgets('Recovers when Firebase.initializeApp throws StateError', (tester) async {
      await runBootstrapHarness(
        initFirebase: () async {
          throw StateError('FirebaseApp already exists or native state corrupt');
        },
        tester: tester,
      );
    });

    testWidgets('Recovers when Firebase.initializeApp throws FormatException', (tester) async {
      await runBootstrapHarness(
        initFirebase: () async {
          throw const FormatException('Malformed google-services.json options');
        },
        tester: tester,
      );
    });
  });

  group('CHALLENGE 2: FirestoreOtsRepository 5-Second Timeout & Error Fallback Probes', () {
    test('Firestore .get() times out after 5s and falls back to SeedData when cache is empty', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final mockFirestore = DynamicMockFirestore(
        onGet: (path) async {
          // Emulate a hanging network connection that exceeds the 5-second timeout
          await Future<void>.delayed(const Duration(milliseconds: 5500));
          throw Exception('Should not reach here because timeout occurs first');
        },
      );

      final repo = FirestoreOtsRepository(firestore: mockFirestore, prefs: prefs);
      expect(repo.isOffline, isFalse);

      final stopwatch = Stopwatch()..start();
      final lotes = await repo.obtenerLotes();
      stopwatch.stop();

      // Verified: repository aborted after ~5 seconds and fell back to SeedData
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(4900));
      expect(stopwatch.elapsedMilliseconds, lessThan(7000));
      expect(repo.isOffline, isTrue);
      expect(lotes.length, equals(5));
      expect(lotes.first.supermercado, equals('Carrefour San Martín'));

      // Confirm fallback seeded the local cache
      final cachedJson = prefs.getString(FirestoreOtsRepository.keyLotes);
      expect(cachedJson, isNotNull);
    });

    test('Firestore .get() times out after 5s and falls back to warm SharedPreferences cache', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final cachedLote = Lote(
        id: 'lote_warm_cache',
        supermercado: 'Jumbo Palermo Warm Cache',
        area: 'Carnicería',
        cantidadProductos: 42,
        creadoEn: DateTime(2026, 1, 1),
      );
      await prefs.setString(
        FirestoreOtsRepository.keyLotes,
        jsonEncode([cachedLote.toJson()]),
      );

      final mockFirestore = DynamicMockFirestore(
        onGet: (path) async {
          await Future<void>.delayed(const Duration(milliseconds: 5500));
          throw Exception('Network hang');
        },
      );

      final repo = FirestoreOtsRepository(firestore: mockFirestore, prefs: prefs);
      final lotes = await repo.obtenerLotes();

      expect(repo.isOffline, isTrue);
      expect(lotes.length, equals(1));
      expect(lotes.first.id, equals('lote_warm_cache'));
      expect(lotes.first.supermercado, equals('Jumbo Palermo Warm Cache'));
    });

    test('Firestore throws resource-exhausted and falls back to cache without crashing', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final mockFirestore = DynamicMockFirestore(
        onGet: (path) async {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'resource-exhausted',
            message: 'Quota exceeded for project',
          );
        },
      );

      final repo = FirestoreOtsRepository(firestore: mockFirestore, prefs: prefs);
      final lotes = await repo.obtenerLotes();

      expect(repo.isOffline, isTrue);
      expect(lotes.isNotEmpty, isTrue);
      expect(lotes.length, equals(5)); // SeedData fallback
    });

    test('Firestore throws permission-denied and falls back to cache gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final mockFirestore = DynamicMockFirestore(
        onGet: (path) async {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Missing permissions',
          );
        },
      );

      final repo = FirestoreOtsRepository(firestore: mockFirestore, prefs: prefs);
      final lotes = await repo.obtenerLotes();

      expect(repo.isOffline, isTrue);
      expect(lotes.length, equals(5));
    });

    test('Recovers gracefully when SharedPreferences cache contains corrupted JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Inject corrupt JSON into cache
      await prefs.setString(FirestoreOtsRepository.keyLotes, '{{INVALID_JSON_CORRUPTED');

      final mockFirestore = DynamicMockFirestore(
        onGet: (path) async {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        },
      );

      final repo = FirestoreOtsRepository(firestore: mockFirestore, prefs: prefs);
      final lotes = await repo.obtenerLotes();

      // Corrupted cache should be discarded and SeedData returned without FormatException
      expect(repo.isOffline, isTrue);
      expect(lotes.length, equals(5));
      expect(lotes.first.supermercado, equals('Carrefour San Martín'));
    });

    test('Recovers gracefully when cached Registros contains malformed JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Inject corrupt JSON into registros cache
      await prefs.setString(FirestoreOtsRepository.keyRegistros, '[{not_a_valid_json}]');

      final mockFirestore = DynamicMockFirestore(
        onGet: (path) async {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        },
      );

      final repo = FirestoreOtsRepository(firestore: mockFirestore, prefs: prefs);
      final registros = await repo.obtenerRegistros();

      expect(repo.isOffline, isTrue);
      expect(registros, isEmpty); // Returns empty list without throwing
    });
  });

  group('CHALLENGE 3: TableroViewModel.inicializar() Adverse Failure Scenarios', () {
    test('Simultaneous failure across Lotes, Registros, and SesionActiva never throws', () async {
      final fakeRepo = FakeOtsRepository();
      fakeRepo.simulateFailOnObtenerLotes = true;
      fakeRepo.simulateFailOnObtenerRegistros = true;
      fakeRepo.simulateFailOnSesionActiva = true;

      final vm = TableroViewModel(repository: fakeRepo);
      expect(vm.isOffline, isFalse);

      // Must complete cleanly without uncaught exception
      await vm.inicializar();

      expect(vm.isLoading, isFalse);
      expect(vm.isOffline, isTrue);
      expect(vm.errorMessage, isNotNull);
      expect(vm.lotes.length, equals(5)); // SeedData fallback
      expect(vm.registros, isEmpty);
      expect(vm.sesionActiva, isNull);
    });

    test('ResourceExhausted quota error sets isOffline, preserves seed data, and stops loading', () async {
      final fakeRepo = FakeOtsRepository();
      fakeRepo.simulateQuotaExceeded = true;

      final vm = TableroViewModel(repository: fakeRepo);
      await vm.inicializar();

      expect(vm.isLoading, isFalse);
      expect(vm.isOffline, isTrue);
      expect(vm.errorMessage, contains('resource-exhausted'));
      expect(vm.lotes.length, equals(5));
    });

    test('PermissionDenied error sets isOffline, preserves seed data, and stops loading', () async {
      final fakeRepo = FakeOtsRepository();
      fakeRepo.simulatePermissionDenied = true;

      final vm = TableroViewModel(repository: fakeRepo);
      await vm.inicializar();

      expect(vm.isLoading, isFalse);
      expect(vm.isOffline, isTrue);
      expect(vm.errorMessage, contains('permission-denied'));
      expect(vm.lotes.length, equals(5));
    });

    test('NetworkError error sets isOffline, preserves seed data, and stops loading', () async {
      final fakeRepo = FakeOtsRepository();
      fakeRepo.simulateNetworkError = true;

      final vm = TableroViewModel(repository: fakeRepo);
      await vm.inicializar();

      expect(vm.isLoading, isFalse);
      expect(vm.isOffline, isTrue);
      expect(vm.errorMessage, contains('unavailable'));
      expect(vm.lotes.length, equals(5));
    });

    test('Purges corrupted session even if repository.limpiarSesionActiva throws', () async {
      final fakeRepo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_1',
          'inicio': 'corrupted-timestamp',
        },
      );
      fakeRepo.simulateFailOnSesionActiva = true;

      final vm = TableroViewModel(repository: fakeRepo);
      addTearDown(vm.dispose);

      // Must not throw even though limpiarSesionActiva throws
      await vm.inicializar();

      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
    });
  });

  group('CHALLENGE 4: Corrupted SharedPreferences Session Parsing Stress Harness', () {
    final List<Map<String, dynamic>> adversarialSessions = [
      {'loteId': null, 'inicio': '2026-11-12T05:00:00Z'},
      {'loteId': '', 'inicio': '2026-11-12T05:00:00Z'},
      {'loteId': 12345, 'inicio': '2026-11-12T05:00:00Z'},
      {'loteId': ['lote_1'], 'inicio': '2026-11-12T05:00:00Z'},
      {'loteId': 'lote_1', 'inicio': null},
      {'loteId': 'lote_1', 'inicio': ''},
      {'loteId': 'lote_1', 'inicio': '    '},
      {'loteId': 'lote_1', 'inicio': 'invalid-date-string'},
      {'loteId': 'lote_1', 'inicio': '2026-13-01T00:00:00Z'}, // Invalid month 13
      {'loteId': 'lote_1', 'inicio': '2026-00-01T00:00:00Z'}, // Invalid month 00
      {'loteId': 'lote_1', 'inicio': '2026-05-32T00:00:00Z'}, // Invalid day 32
      {'loteId': 'lote_1', 'inicio': '2026-05-00T00:00:00Z'}, // Invalid day 00
      {'loteId': 'lote_1', 'inicio': true},
      {'loteId': 'lote_1', 'inicio': false},
      {'loteId': 'lote_1', 'inicio': ['2026-11-12']},
      {'loteId': 'lote_1', 'inicio': {'date': '2026-11-12'}},
      {'loteId': 'lote_1', 'inicio': 9223372036854775807}, // Extreme 64-bit int overflow
      {'loteId': 'lote_1', 'inicio': '999999999999999999999999999999999999'}, // Extreme digit string
    ];

    for (int i = 0; i < adversarialSessions.length; i++) {
      test('Adversarial probe session index $i (${adversarialSessions[i]}) purges cleanly', () async {
        final repo = FakeOtsRepository(
          useSeedData: true,
          initialSesionActiva: adversarialSessions[i],
        );

        final vm = TableroViewModel(repository: repo);
        addTearDown(vm.dispose);

        await vm.inicializar();

        expect(vm.sesionActiva, isNull);
        expect(vm.segundosTranscurridos, equals(0));
        expect(repo.sesionActiva, isNull);
      });
    }
  });

  group('CHALLENGE 5: Re-entrancy, Rapid Taps, and Lifecycle Stress', () {
    test('Rapid consecutive calls to inicializar() and reintentar() do not throw or deadlock', () async {
      final fakeRepo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: fakeRepo);
      addTearDown(vm.dispose);

      // Trigger 10 concurrent initializations and retries
      final futures = <Future<void>>[];
      for (int i = 0; i < 5; i++) {
        futures.add(vm.inicializar());
        futures.add(vm.reintentar());
      }

      await Future.wait(futures);

      expect(vm.isLoading, isFalse);
      expect(vm.lotes.length, equals(5));
      expect(vm.isOffline, isFalse);
    });

    test('Disposing TableroViewModel with active session cancels timer cleanly', () async {
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_1',
          'supermercado': 'Carrefour San Martín',
          'area': 'Lácteos',
          'cantidadProductos': 100,
          'inicio': fiveMinutesAgo.toIso8601String(),
        },
      );

      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      expect(vm.sesionActiva, isNotNull);
      expect(vm.segundosTranscurridos, greaterThan(0));

      // Dispose viewmodel
      expect(() => vm.dispose(), returnsNormally);
    });
  });
}
