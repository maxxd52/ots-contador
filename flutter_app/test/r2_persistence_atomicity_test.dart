import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/data/repositories/firestore_repository.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/domain/models/registro_trabajo.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import 'e2e/harness/fake_ots_repository.dart';

// ignore: subtype_of_sealed_class
class MockBatchFirestore implements FirebaseFirestore {
  final MockWriteBatch recordedBatch = MockWriteBatch();
  final Map<String, dynamic> documents = {};
  bool failOnGet = false;

  @override
  WriteBatch batch() => recordedBatch;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return MockCollectionReference(collectionPath, this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class MockCollectionReference implements CollectionReference<Map<String, dynamic>> {
  @override
  final String path;
  @override
  final MockBatchFirestore firestore;

  MockCollectionReference(this.path, this.firestore);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final docPath = '${this.path}/${path ?? "autoid"}';
    return MockDocumentReference(docPath, firestore);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class MockDocumentReference implements DocumentReference<Map<String, dynamic>> {
  @override
  final String path;
  @override
  final MockBatchFirestore firestore;

  MockDocumentReference(this.path, this.firestore);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    if (firestore.failOnGet) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Network offline during get()',
      );
    }
    final data = firestore.documents[path];
    return MockDocumentSnapshot(path, data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class MockDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;

  MockDocumentSnapshot(this.id, this._data);

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class MockWriteBatch implements WriteBatch {
  final List<Map<String, dynamic>> operations = [];
  bool committed = false;
  bool shouldThrowOnCommit = false;

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    operations.add({
      'action': 'set',
      'path': document.path,
      'data': data,
      'merge': options?.merge ?? false,
    });
  }

  @override
  Future<void> commit() async {
    if (shouldThrowOnCommit) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Network disconnected during batch commit',
      );
    }
    committed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('R2: FirestoreOtsRepository.guardarRegistro - Atomic Persistence with WriteBatch', () {
    test('Persists work record and reschedules lot atomically via WriteBatch in a single commit', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final mockFirestore = MockBatchFirestore();
      final loteInicial = Lote.crear(
        id: 'lote_101',
        supermercado: 'Carrefour Vicente López',
        area: 'Bebidas',
        cantidadProductos: 50,
      );
      mockFirestore.documents['lotes/lote_101'] = loteInicial.toJson();

      final repo = FirestoreOtsRepository(firestore: mockFirestore, prefs: prefs);

      final inicio = DateTime(2026, 11, 12, 10, 0);
      final fin = DateTime(2026, 11, 12, 11, 30);
      final registro = RegistroTrabajo.crear(
        id: 'reg_201',
        loteId: 'lote_101',
        supermercado: 'Carrefour Vicente López',
        area: 'Bebidas',
        cantidadProductos: 75,
        inicio: inicio,
        fin: fin,
      );

      final saved = await repo.guardarRegistro(registro);
      expect(saved.id, equals('reg_201'));

      final batch = mockFirestore.recordedBatch;
      expect(batch.committed, isTrue, reason: 'Batch commit must be executed');
      expect(batch.operations.length, equals(2), reason: 'Must contain exactly 2 operations');

      // Operation 1: registros_trabajo set with merge: true
      final op1 = batch.operations[0];
      expect(op1['action'], equals('set'));
      expect(op1['path'], equals('registros_trabajo/reg_201'));
      expect(op1['merge'], isTrue);
      expect((op1['data'] as Map<String, dynamic>)['id'], equals('reg_201'));

      // Operation 2: lotes set with merge: true and updated unlock date
      final op2 = batch.operations[1];
      expect(op2['action'], equals('set'));
      expect(op2['path'], equals('lotes/lote_101'));
      expect(op2['merge'], isTrue);
      final loteData = op2['data'] as Map<String, dynamic>;
      expect(loteData['id'], equals('lote_101'));
      expect(loteData['cantidadProductos'], equals(75));
      expect(loteData['ultimoInicio'], equals(inicio.toIso8601String()));
      expect(loteData['proximoDesbloqueo'], equals(registro.nuevoDesbloqueo.toIso8601String()));

      // Post-commit cache verification
      final cachedLotesJson = prefs.getString(FirestoreOtsRepository.keyLotes);
      expect(cachedLotesJson, isNotNull);
      final List<dynamic> cachedLotes = jsonDecode(cachedLotesJson!) as List<dynamic>;
      expect(cachedLotes.any((l) => l['id'] == 'lote_101' && l['proximoDesbloqueo'] == registro.nuevoDesbloqueo.toIso8601String()), isTrue);
    });

    test('Throws FirebaseException on batch commit failure leaving zero partial state in cache', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final mockFirestore = MockBatchFirestore();
      mockFirestore.recordedBatch.shouldThrowOnCommit = true;

      final loteInicial = Lote.crear(
        id: 'lote_fail_test',
        supermercado: 'Jumbo Quilmes',
        area: 'Lácteos',
        cantidadProductos: 30,
      );
      mockFirestore.documents['lotes/lote_fail_test'] = loteInicial.toJson();

      final repo = FirestoreOtsRepository(firestore: mockFirestore, prefs: prefs);

      final registro = RegistroTrabajo.crear(
        id: 'reg_fail',
        loteId: 'lote_fail_test',
        supermercado: 'Jumbo Quilmes',
        area: 'Lácteos',
        cantidadProductos: 40,
        inicio: DateTime(2026, 11, 12, 9, 0),
        fin: DateTime(2026, 11, 12, 10, 0),
      );

      expect(
        () async => await repo.guardarRegistro(registro),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );

      expect(mockFirestore.recordedBatch.committed, isFalse);

      // Verify no cache pollution occurred
      expect(prefs.getString(FirestoreOtsRepository.keyRegistros), isNull);
      expect(prefs.getString(FirestoreOtsRepository.keyLotes), isNull);
    });

    test('Pre-batch fallback to local cache when remote lote read fails offline', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final cachedLote = Lote.crear(
        id: 'lote_offline_1',
        supermercado: 'Coto Lanús',
        area: 'Limpieza',
        cantidadProductos: 90,
      );
      await prefs.setString(
        FirestoreOtsRepository.keyLotes,
        jsonEncode([cachedLote.toJson()]),
      );

      final mockFirestore = MockBatchFirestore();
      mockFirestore.failOnGet = true; // Emulate offline network error on loteRef.get()

      final repo = FirestoreOtsRepository(firestore: mockFirestore, prefs: prefs);

      final inicio = DateTime(2026, 11, 12, 14, 0);
      final fin = DateTime(2026, 11, 12, 15, 0);
      final registro = RegistroTrabajo.crear(
        id: 'reg_offline_1',
        loteId: 'lote_offline_1',
        supermercado: 'Coto Lanús',
        area: 'Limpieza',
        cantidadProductos: 110,
        inicio: inicio,
        fin: fin,
      );

      final saved = await repo.guardarRegistro(registro);
      expect(saved.id, equals('reg_offline_1'));

      final batch = mockFirestore.recordedBatch;
      expect(batch.committed, isTrue);
      expect(batch.operations.length, equals(2));

      final loteOp = batch.operations[1];
      expect(loteOp['path'], equals('lotes/lote_offline_1'));
      final data = loteOp['data'] as Map<String, dynamic>;
      expect(data['cantidadProductos'], equals(110));
      expect(data['ultimoInicio'], equals(inicio.toIso8601String()));
      expect(data['proximoDesbloqueo'], equals(registro.nuevoDesbloqueo.toIso8601String()));
    });
  });

  group('R2: TableroViewModel - Redundant guardarLote Elimination', () {
    test('TableroViewModel.guardarSesionFotos calls guardarRegistro once and guardarLote zero times', () async {
      final fakeRepo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: fakeRepo);
      await vm.inicializar();

      final loteInicial = vm.lotes.first;
      expect(vm.lotesHabilitados.any((l) => l.id == loteInicial.id), isTrue);

      final inicio = DateTime(2026, 11, 12, 11, 0);
      final fin = DateTime(2026, 11, 12, 12, 0);

      await vm.guardarSesionFotos(
        loteId: loteInicial.id,
        supermercado: loteInicial.supermercado,
        area: loteInicial.area,
        cantidadProductos: 150,
        inicio: inicio,
        fin: fin,
        observaciones: 'Test atomic and non-redundant write',
      );

      // Verify call counts: exactly 1 guardarRegistro and 0 guardarLote
      expect(fakeRepo.guardarRegistroCallCount, equals(1));
      expect(fakeRepo.guardarLoteCallCount, equals(0), reason: 'guardarSesionFotos must eliminate redundant guardarLote');

      // Verify that the lot moved to lotesFuturos (+120 days)
      expect(vm.registros.length, equals(1));
      expect(vm.lotesHabilitados.any((l) => l.id == loteInicial.id), isFalse);
      expect(vm.lotesFuturos.any((l) => l.id == loteInicial.id), isTrue);

      final loteMovido = vm.lotesFuturos.firstWhere((l) => l.id == loteInicial.id);
      expect(loteMovido.cantidadProductos, equals(150));
      expect(loteMovido.ultimoInicio, equals(inicio));
      expect(loteMovido.proximoDesbloqueo, isNotNull);
    });

    test('FakeOtsRepository failure in atomic batch aborts whole operation cleanly', () async {
      final fakeRepo = FakeOtsRepository(useSeedData: true);
      fakeRepo.simulateFailOnGuardarRegistro = true;

      final vm = TableroViewModel(repository: fakeRepo);
      await vm.inicializar();

      final loteInicial = vm.lotes.first;
      final inicio = DateTime(2026, 11, 12, 11, 0);

      expect(
        () async => await vm.guardarSesionFotos(
          loteId: loteInicial.id,
          supermercado: loteInicial.supermercado,
          area: loteInicial.area,
          cantidadProductos: 100,
          inicio: inicio,
          fin: inicio.add(const Duration(hours: 1)),
        ),
        throwsA(isA<FirebaseException>()),
      );

      // Verify zero partial mutations occurred
      expect(fakeRepo.registros, isEmpty);
      expect(fakeRepo.atomicBatchesCommitted, equals(0));
    });
  });
}
