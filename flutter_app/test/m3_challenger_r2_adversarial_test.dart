import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/data/repositories/firestore_repository.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/domain/models/registro_trabajo.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import 'e2e/harness/fake_ots_repository.dart';

/// Adversarial Mock Firestore allowing dynamic batch inspection, failure simulation,
/// and recording of atomic commit attempts.
// ignore: subtype_of_sealed_class
class AdversarialBatchFirestore implements FirebaseFirestore {
  final List<AdversarialMockBatch> createdBatches = [];
  final Map<String, dynamic> documents = {};
  bool failOnGet = false;
  FirebaseException? customGetException;
  FirebaseException? commitException;

  @override
  WriteBatch batch() {
    final b = AdversarialMockBatch(this, commitException: commitException);
    createdBatches.add(b);
    return b;
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return AdversarialMockCollectionReference(collectionPath, this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class AdversarialMockCollectionReference implements CollectionReference<Map<String, dynamic>> {
  @override
  final String path;
  @override
  final AdversarialBatchFirestore firestore;

  AdversarialMockCollectionReference(this.path, this.firestore);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final docPath = '${this.path}/${path ?? "auto_${DateTime.now().microsecondsSinceEpoch}"}';
    return AdversarialMockDocumentReference(docPath, firestore);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class AdversarialMockDocumentReference implements DocumentReference<Map<String, dynamic>> {
  @override
  final String path;
  @override
  final AdversarialBatchFirestore firestore;

  AdversarialMockDocumentReference(this.path, this.firestore);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    if (firestore.failOnGet) {
      throw firestore.customGetException ??
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Simulated network disconnect on get()',
          );
    }
    final data = firestore.documents[path];
    return AdversarialMockDocumentSnapshot(path, data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class AdversarialMockDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;

  AdversarialMockDocumentSnapshot(this.id, this._data);

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class AdversarialMockBatch implements WriteBatch {
  final AdversarialBatchFirestore firestore;
  final FirebaseException? commitException;
  final List<Map<String, dynamic>> recordedOperations = [];
  bool isCommitted = false;

  AdversarialMockBatch(this.firestore, {this.commitException});

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    recordedOperations.add({
      'action': 'set',
      'path': document.path,
      'data': data,
      'merge': options?.merge ?? false,
    });
  }

  @override
  Future<void> commit() async {
    if (commitException != null) {
      throw commitException!;
    }
    // Apply operations atomically to firestore documents map
    for (final op in recordedOperations) {
      final path = op['path'] as String;
      final data = op['data'] as Map<String, dynamic>;
      if (op['merge'] == true && firestore.documents.containsKey(path)) {
        final existing = firestore.documents[path] as Map<String, dynamic>;
        firestore.documents[path] = {...existing, ...data};
      } else {
        firestore.documents[path] = Map<String, dynamic>.from(data);
      }
    }
    isCommitted = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  group('CHALLENGE 1: Empirical Verification of WriteBatch Atomicity in FirestoreOtsRepository', () {
    test('Both registros_trabajo and lotes are submitted atomically in a single batch.commit()', () async {
      final firestore = AdversarialBatchFirestore();
      final initialLote = Lote.crear(
        id: 'lote_atomic_alpha',
        supermercado: 'Coto Caballito',
        area: 'Fiambrería',
        cantidadProductos: 42,
      );
      firestore.documents['lotes/lote_atomic_alpha'] = initialLote.toJson();

      final repo = FirestoreOtsRepository(firestore: firestore, prefs: prefs);

      final inicio = DateTime(2026, 11, 12, 8, 30);
      final fin = DateTime(2026, 11, 12, 10, 0);
      final registro = RegistroTrabajo.crear(
        id: 'reg_alpha_01',
        loteId: 'lote_atomic_alpha',
        supermercado: 'Coto Caballito',
        area: 'Fiambrería',
        cantidadProductos: 55,
        inicio: inicio,
        fin: fin,
        observaciones: 'Adversarial atomicity check',
      );

      final result = await repo.guardarRegistro(registro);
      expect(result.id, equals('reg_alpha_01'));

      // Check batch creation
      expect(firestore.createdBatches.length, equals(1), reason: 'Must create exactly 1 WriteBatch instance');
      final batch = firestore.createdBatches.first;
      expect(batch.isCommitted, isTrue);
      expect(batch.recordedOperations.length, equals(2), reason: 'Batch must contain exactly 2 atomic operations');

      // Verify Operation 1: registros_trabajo
      final regOp = batch.recordedOperations[0];
      expect(regOp['action'], equals('set'));
      expect(regOp['path'], equals('registros_trabajo/reg_alpha_01'));
      expect(regOp['merge'], isTrue);
      final regData = regOp['data'] as Map<String, dynamic>;
      expect(regData['id'], equals('reg_alpha_01'));
      expect(regData['loteId'], equals('lote_atomic_alpha'));
      expect(regData['cantidadProductos'], equals(55));

      // Verify Operation 2: lotes
      final loteOp = batch.recordedOperations[1];
      expect(loteOp['action'], equals('set'));
      expect(loteOp['path'], equals('lotes/lote_atomic_alpha'));
      expect(loteOp['merge'], isTrue);
      final loteData = loteOp['data'] as Map<String, dynamic>;
      expect(loteData['id'], equals('lote_atomic_alpha'));
      expect(loteData['cantidadProductos'], equals(55));
      expect(loteData['ultimoInicio'], equals(inicio.toIso8601String()));
      expect(loteData['proximoDesbloqueo'], equals(registro.nuevoDesbloqueo.toIso8601String()));

      // Verify Firestore state after atomic commit
      expect(firestore.documents.containsKey('registros_trabajo/reg_alpha_01'), isTrue);
      expect(firestore.documents.containsKey('lotes/lote_atomic_alpha'), isTrue);

      // Verify cache synchronization post-commit
      final cachedLotes = jsonDecode(prefs.getString(FirestoreOtsRepository.keyLotes)!) as List<dynamic>;
      expect(cachedLotes.any((l) => l['id'] == 'lote_atomic_alpha' && l['proximoDesbloqueo'] == registro.nuevoDesbloqueo.toIso8601String()), isTrue);
      final cachedRegs = jsonDecode(prefs.getString(FirestoreOtsRepository.keyRegistros)!) as List<dynamic>;
      expect(cachedRegs.any((r) => r['id'] == 'reg_alpha_01'), isTrue);
    });

    test('Batch commit failure (network disconnected) aborts all writes and leaves cache pristine', () async {
      final firestore = AdversarialBatchFirestore();
      firestore.commitException = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'The network connection was lost.',
      );

      final initialLote = Lote.crear(
        id: 'lote_pristine',
        supermercado: 'Dia Pompeya',
        area: 'Carnes',
        cantidadProductos: 30,
      );
      firestore.documents['lotes/lote_pristine'] = initialLote.toJson();

      // Seed pre-existing cache to verify it is NOT overwritten or corrupted
      await prefs.setString(
        FirestoreOtsRepository.keyLotes,
        jsonEncode([initialLote.toJson()]),
      );
      await prefs.setString(
        FirestoreOtsRepository.keyRegistros,
        jsonEncode([]),
      );

      final repo = FirestoreOtsRepository(firestore: firestore, prefs: prefs);

      final registro = RegistroTrabajo.crear(
        id: 'reg_doomed',
        loteId: 'lote_pristine',
        supermercado: 'Dia Pompeya',
        area: 'Carnes',
        cantidadProductos: 35,
        inicio: DateTime(2026, 11, 12, 10, 0),
        fin: DateTime(2026, 11, 12, 11, 0),
      );

      await expectLater(
        () => repo.guardarRegistro(registro),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );

      // Batch was NOT committed
      expect(firestore.createdBatches.length, equals(1));
      final batch = firestore.createdBatches.first;
      expect(batch.isCommitted, isFalse);

      // Remote documents were NOT modified
      expect(firestore.documents.containsKey('registros_trabajo/reg_doomed'), isFalse);
      final unmutatedRemoteLote = firestore.documents['lotes/lote_pristine'] as Map<String, dynamic>;
      expect(unmutatedRemoteLote['proximoDesbloqueo'], isNull);

      // Cache was NOT corrupted: remains exactly in initial state
      final cachedLotes = jsonDecode(prefs.getString(FirestoreOtsRepository.keyLotes)!) as List<dynamic>;
      expect(cachedLotes.length, equals(1));
      expect(cachedLotes.first['proximoDesbloqueo'], isNull);
      final cachedRegs = jsonDecode(prefs.getString(FirestoreOtsRepository.keyRegistros)!) as List<dynamic>;
      expect(cachedRegs, isEmpty);
    });

    test('Batch commit failure (permission-denied) throws and preserves zero partial writes', () async {
      final firestore = AdversarialBatchFirestore();
      firestore.commitException = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Insufficient permissions for batch write.',
      );

      final repo = FirestoreOtsRepository(firestore: firestore, prefs: prefs);
      final registro = RegistroTrabajo.crear(
        id: 'reg_forbidden',
        loteId: 'lote_unauthorized',
        supermercado: 'Disco Belgrano',
        area: 'Verdulería',
        cantidadProductos: 20,
        inicio: DateTime(2026, 11, 12, 12, 0),
        fin: DateTime(2026, 11, 12, 13, 0),
      );

      await expectLater(
        () => repo.guardarRegistro(registro),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );

      expect(prefs.getString(FirestoreOtsRepository.keyRegistros), isNull);
      expect(prefs.getString(FirestoreOtsRepository.keyLotes), isNull);
      expect(firestore.documents, isEmpty);
    });

    test('Pre-batch remote read offline fallback creates valid lot from cached lot', () async {
      final firestore = AdversarialBatchFirestore();
      firestore.failOnGet = true; // Emulate offline timeout/error on remote get()

      final cachedLote = Lote.crear(
        id: 'lote_cached_only',
        supermercado: 'Vea Mendoza',
        area: 'Congelados',
        cantidadProductos: 88,
      );
      await prefs.setString(
        FirestoreOtsRepository.keyLotes,
        jsonEncode([cachedLote.toJson()]),
      );

      final repo = FirestoreOtsRepository(firestore: firestore, prefs: prefs);

      final registro = RegistroTrabajo.crear(
        id: 'reg_from_cached',
        loteId: 'lote_cached_only',
        supermercado: 'Vea Mendoza',
        area: 'Congelados',
        cantidadProductos: 0, // Should preserve existing 88
        inicio: DateTime(2026, 11, 12, 14, 0),
        fin: DateTime(2026, 11, 12, 15, 0),
      );

      final result = await repo.guardarRegistro(registro);
      expect(result.id, equals('reg_from_cached'));

      final batch = firestore.createdBatches.first;
      expect(batch.isCommitted, isTrue);
      final loteOp = batch.recordedOperations[1];
      final loteData = loteOp['data'] as Map<String, dynamic>;
      expect(loteData['cantidadProductos'], equals(88), reason: 'Zero quantity in registration must preserve cached quantity');
      expect(loteData['proximoDesbloqueo'], equals(registro.nuevoDesbloqueo.toIso8601String()));
    });

    test('Pre-batch remote read missing from both remote and cache synthesizes new Lote correctly', () async {
      final firestore = AdversarialBatchFirestore();
      final repo = FirestoreOtsRepository(firestore: firestore, prefs: prefs);

      final registro = RegistroTrabajo.crear(
        id: 'reg_unknown_lote',
        loteId: 'lote_brand_new',
        supermercado: 'Makro San Martín',
        area: 'Bazar',
        cantidadProductos: 60,
        inicio: DateTime(2026, 11, 12, 9, 0),
        fin: DateTime(2026, 11, 12, 10, 0),
      );

      await repo.guardarRegistro(registro);

      final batch = firestore.createdBatches.first;
      expect(batch.isCommitted, isTrue);
      final loteOp = batch.recordedOperations[1];
      final loteData = loteOp['data'] as Map<String, dynamic>;
      expect(loteData['id'], equals('lote_brand_new'));
      expect(loteData['supermercado'], equals('Makro San Martín'));
      expect(loteData['proximoDesbloqueo'], equals(registro.nuevoDesbloqueo.toIso8601String()));
    });
  });

  group('CHALLENGE 2: TableroViewModel Non-Redundant Invariant & State Synchronization', () {
    test('guardarSesionFotos executes guardarRegistro ONCE and NEVER calls guardarLote (0 redundant writes)', () async {
      final fakeRepo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: fakeRepo);
      await vm.inicializar();

      final lote = vm.lotesHabilitados.first;
      final inicio = DateTime(2026, 11, 12, 8, 0);
      final fin = DateTime(2026, 11, 12, 9, 30);

      // Start session first to test cleanup
      await vm.iniciarFotos(lote);
      expect(vm.sesionActiva, isNotNull);

      await vm.guardarSesionFotos(
        loteId: lote.id,
        supermercado: lote.supermercado,
        area: lote.area,
        cantidadProductos: 125,
        inicio: inicio,
        fin: fin,
        observaciones: 'Non-redundant verification',
      );

      // STRICT CONTRACT VERIFICATION:
      expect(fakeRepo.guardarRegistroCallCount, equals(1), reason: 'guardarRegistro must be called exactly once');
      expect(fakeRepo.guardarLoteCallCount, equals(0), reason: 'guardarLote must NEVER be called by guardarSesionFotos');

      // Active session must be cleaned up
      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(fakeRepo.limpiarSesionActivaCallCount, equals(1));

      // Lot state transition: from habilitados to lotesFuturos (+120 days)
      expect(vm.lotesHabilitados.any((l) => l.id == lote.id), isFalse);
      expect(vm.lotesFuturos.any((l) => l.id == lote.id), isTrue);

      final rescheduledLote = vm.lotesFuturos.firstWhere((l) => l.id == lote.id);
      expect(rescheduledLote.cantidadProductos, equals(125));
      expect(rescheduledLote.ultimoInicio, equals(inicio));
      expect(rescheduledLote.proximoDesbloqueo, isNotNull);
      // Verify the 120-day rule exactly
      final expectedUnlock = DateTime(inicio.year, inicio.month, inicio.day + 120, inicio.hour, inicio.minute, inicio.second);
      expect(rescheduledLote.proximoDesbloqueo, equals(expectedUnlock));

      // Registers list updated
      expect(vm.registros.length, equals(1));
      expect(vm.registros.first.loteId, equals(lote.id));
    });

    test('ViewModel preserves active session when repository.guardarRegistro fails (no work lost)', () async {
      final fakeRepo = FakeOtsRepository(useSeedData: true);
      fakeRepo.simulateFailOnGuardarRegistro = true;

      final vm = TableroViewModel(repository: fakeRepo);
      await vm.inicializar();

      final lote = vm.lotesHabilitados.first;
      await vm.iniciarFotos(lote);
      expect(vm.sesionActiva, isNotNull);

      final inicio = DateTime(2026, 11, 12, 8, 0);

      await expectLater(
        () => vm.guardarSesionFotos(
          loteId: lote.id,
          supermercado: lote.supermercado,
          area: lote.area,
          cantidadProductos: 50,
          inicio: inicio,
          fin: inicio.add(const Duration(minutes: 45)),
        ),
        throwsA(isA<FirebaseException>()),
      );

      // Critical resilience property: because guardarRegistro threw before cancelarSesionActiva(),
      // the user session is preserved so photos/time are not destroyed on network failure!
      expect(vm.sesionActiva, isNotNull, reason: 'Active session must be preserved on persistence failure');
      expect(fakeRepo.guardarLoteCallCount, equals(0));
      expect(fakeRepo.registros, isEmpty);
      expect(fakeRepo.atomicBatchesCommitted, equals(0));
    });

    test('Multiple sequential session saves consistently maintain 0 redundant guardarLote calls', () async {
      final fakeRepo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: fakeRepo);
      await vm.inicializar();

      expect(vm.lotesHabilitados.length, greaterThanOrEqualTo(3));
      final lotesToSave = vm.lotesHabilitados.take(3).toList();

      for (int i = 0; i < lotesToSave.length; i++) {
        final lote = lotesToSave[i];
        final inicio = DateTime(2026, 11, 12, 8 + i, 0);
        await vm.guardarSesionFotos(
          loteId: lote.id,
          supermercado: lote.supermercado,
          area: lote.area,
          cantidadProductos: 30 + i * 10,
          inicio: inicio,
          fin: inicio.add(const Duration(hours: 1)),
        );
      }

      expect(fakeRepo.guardarRegistroCallCount, equals(3));
      expect(fakeRepo.guardarLoteCallCount, equals(0), reason: 'Zero redundant calls across all 3 sessions');
      expect(fakeRepo.atomicBatchesCommitted, equals(3));
      expect(vm.registros.length, equals(3));
      for (final l in lotesToSave) {
        expect(vm.lotesFuturos.any((f) => f.id == l.id), isTrue, reason: 'Saved lot ${l.id} must be in lotesFuturos');
      }
    });
  });

  group('CHALLENGE 3: High-Stress Concurrency, Overlapping Batches & Consistency Harness', () {
    test('Massive parallel batch writes across 10 distinct lots maintain atomic isolation', () async {
      final firestore = AdversarialBatchFirestore();

      // Pre-populate 10 lots in firestore
      for (int i = 0; i < 10; i++) {
        final lote = Lote.crear(
          id: 'lote_conc_$i',
          supermercado: 'Supermercado $i',
          area: 'Sector $i',
          cantidadProductos: 10 * i,
        );
        firestore.documents['lotes/lote_conc_$i'] = lote.toJson();
      }

      final repo = FirestoreOtsRepository(firestore: firestore, prefs: prefs);

      // Launch 10 simultaneous saves
      final futures = List.generate(10, (i) {
        final inicio = DateTime(2026, 11, 12, 7, i);
        final reg = RegistroTrabajo.crear(
          id: 'reg_conc_$i',
          loteId: 'lote_conc_$i',
          supermercado: 'Supermercado $i',
          area: 'Sector $i',
          cantidadProductos: 100 + i,
          inicio: inicio,
          fin: inicio.add(const Duration(minutes: 45)),
        );
        return repo.guardarRegistro(reg);
      });

      final results = await Future.wait(futures);
      expect(results.length, equals(10));

      // Verify 10 separate atomic batches were created and all committed
      expect(firestore.createdBatches.length, equals(10));
      for (final b in firestore.createdBatches) {
        expect(b.isCommitted, isTrue);
        expect(b.recordedOperations.length, equals(2));
      }

      // Verify all 10 records and 10 lot reschedules exist in firestore
      for (int i = 0; i < 10; i++) {
        expect(firestore.documents.containsKey('registros_trabajo/reg_conc_$i'), isTrue);
        expect(firestore.documents.containsKey('lotes/lote_conc_$i'), isTrue);
        final lData = firestore.documents['lotes/lote_conc_$i'] as Map<String, dynamic>;
        expect(lData['cantidadProductos'], equals(100 + i));
        expect(lData['proximoDesbloqueo'], isNotNull);
      }

      // SharedPreferences cache receives writes (non-null)
      expect(prefs.getString(FirestoreOtsRepository.keyLotes), isNotNull);
      expect(prefs.getString(FirestoreOtsRepository.keyRegistros), isNotNull);
    });

    test('Sequential batch writes across multiple lots reliably accumulate in local cache', () async {
      final firestore = AdversarialBatchFirestore();
      final repo = FirestoreOtsRepository(firestore: firestore, prefs: prefs);

      for (int i = 0; i < 5; i++) {
        final inicio = DateTime(2026, 11, 12, 8, i * 10);
        final reg = RegistroTrabajo.crear(
          id: 'reg_seq_$i',
          loteId: 'lote_seq_$i',
          supermercado: 'Supermercado $i',
          area: 'Sector $i',
          cantidadProductos: 50 + i,
          inicio: inicio,
          fin: inicio.add(const Duration(minutes: 30)),
        );
        await repo.guardarRegistro(reg);
      }

      final cachedLotes = jsonDecode(prefs.getString(FirestoreOtsRepository.keyLotes)!) as List<dynamic>;
      expect(cachedLotes.length, equals(5));
      final cachedRegs = jsonDecode(prefs.getString(FirestoreOtsRepository.keyRegistros)!) as List<dynamic>;
      expect(cachedRegs.length, equals(5));
    });

    test('Parallel writes to the SAME lot resolve cleanly without crashing or partial corruption', () async {
      final firestore = AdversarialBatchFirestore();
      final initialLote = Lote.crear(
        id: 'lote_shared_target',
        supermercado: 'Carrefour Express Palermo',
        area: 'Góndola Central',
        cantidadProductos: 50,
      );
      firestore.documents['lotes/lote_shared_target'] = initialLote.toJson();

      final repo = FirestoreOtsRepository(firestore: firestore, prefs: prefs);

      // Launch 5 concurrent saves on the exact same lot ID
      final futures = List.generate(5, (i) {
        final inicio = DateTime(2026, 11, 12, 10 + i, 0);
        final reg = RegistroTrabajo.crear(
          id: 'reg_shared_$i',
          loteId: 'lote_shared_target',
          supermercado: 'Carrefour Express Palermo',
          area: 'Góndola Central',
          cantidadProductos: 50 + i * 5,
          inicio: inicio,
          fin: inicio.add(const Duration(minutes: 30)),
        );
        return repo.guardarRegistro(reg);
      });

      final results = await Future.wait(futures);
      expect(results.length, equals(5));

      // Each got its own atomic WriteBatch
      expect(firestore.createdBatches.length, equals(5));
      for (final b in firestore.createdBatches) {
        expect(b.isCommitted, isTrue);
      }

      // All 5 work records were registered
      for (int i = 0; i < 5; i++) {
        expect(firestore.documents.containsKey('registros_trabajo/reg_shared_$i'), isTrue);
      }

      // Target lot was rescheduled and has proximoDesbloqueo
      final finalLote = firestore.documents['lotes/lote_shared_target'] as Map<String, dynamic>;
      expect(finalLote['proximoDesbloqueo'], isNotNull);
    });

    test('FakeOtsRepository failMidBatch discriminator catches pre-atomic partial write defects', () async {
      // This test acts as a negative oracle: it proves that our test harness
      // can unmistakably detect the legacy defect (work record written, lot left unrescheduled).
      final fakeRepo = FakeOtsRepository(useSeedData: true);
      fakeRepo.failMidBatch = true; // Inject legacy non-atomic bug

      final lote = fakeRepo.lotes.first;
      final initialUnlock = lote.proximoDesbloqueo;
      final reg = RegistroTrabajo.crear(
        id: 'reg_defective',
        loteId: lote.id,
        supermercado: lote.supermercado,
        area: lote.area,
        cantidadProductos: 99,
        inicio: DateTime(2026, 11, 12, 10, 0),
        fin: DateTime(2026, 11, 12, 11, 0),
      );

      // Throws due to mid-batch failure
      await expectLater(
        () => fakeRepo.guardarRegistro(reg),
        throwsA(isA<FirebaseException>()),
      );

      // The defective legacy mode leaves a partial record:
      expect(fakeRepo.registros.length, equals(1), reason: 'Discriminator confirms failMidBatch creates partial work record');
      // But the lot was NOT rescheduled to reg.nuevoDesbloqueo:
      final unrescheduled = fakeRepo.lotes.firstWhere((l) => l.id == lote.id);
      expect(unrescheduled.proximoDesbloqueo, equals(initialUnlock), reason: 'Discriminator confirms legacy bug failed to update unlock date');
      expect(unrescheduled.proximoDesbloqueo, isNot(equals(reg.nuevoDesbloqueo)));

      // Now reset and demonstrate that atomic behavior (simulateFailOnGuardarRegistro) prevents partial state:
      final pristineRepo = FakeOtsRepository(useSeedData: true);
      pristineRepo.simulateFailOnGuardarRegistro = true;

      await expectLater(
        () => pristineRepo.guardarRegistro(reg),
        throwsA(isA<FirebaseException>()),
      );
      // Under atomic batch, ZERO partial state exists:
      expect(pristineRepo.registros, isEmpty, reason: 'Atomic rollback leaves ZERO work records');
      expect(pristineRepo.atomicBatchesCommitted, equals(0));
    });
  });
}
