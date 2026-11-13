import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter_app/data/repositories/ots_repository.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/domain/models/registro_trabajo.dart';
import 'package:flutter_app/data/datasources/seed_data.dart';

/// Represents a recorded atomic batch or repository mutation for verification and auditing.
class BatchOperationRecord {
  final String operation;
  final DateTime timestamp;
  final Map<String, dynamic> details;
  final bool succeeded;

  const BatchOperationRecord({
    required this.operation,
    required this.timestamp,
    required this.details,
    required this.succeeded,
  });

  @override
  String toString() =>
      'BatchOperationRecord(operation: $operation, succeeded: $succeeded, details: $details, timestamp: $timestamp)';
}

/// In-memory implementation of [OtsRepository] engineered for high-fidelity E2E and integration tests.
///
/// Features:
/// - Real state retention (lotes, registros, sesionActiva) in memory.
/// - Atomic batch tracking ([batchLog], [atomicBatchesCommitted]).
/// - Failure simulation toggles (network outage, quota exceeded, permission denied, slow response).
/// - Atomic write-batch emulation with optional mid-batch failure injection.
/// - Call counters for every interface contract method to detect duplicate/redundant invocations.
/// - Seed data initialization and clean reset capability.
class FakeOtsRepository implements OtsRepository {
  final List<Lote> _lotes = [];
  final List<RegistroTrabajo> _registros = [];
  Map<String, dynamic>? _sesionActiva;

  // Audit and Batch Tracking
  final List<BatchOperationRecord> _batchLog = [];
  int _atomicBatchesCommitted = 0;

  // Failure simulation toggles
  bool simulateNetworkError = false;
  bool simulateQuotaExceeded = false;
  bool simulatePermissionDenied = false;
  Duration? simulateDelay;

  // Fine-grained failure toggles
  bool simulateFailOnObtenerLotes = false;
  bool simulateFailOnGuardarLote = false;
  bool simulateFailOnEliminarLote = false;
  bool simulateFailOnObtenerRegistros = false;

  /// When true, simulates an atomic WriteBatch failure during [guardarRegistro].
  ///
  /// Emulates Firestore's all-or-nothing transaction rollback:
  /// throws [FirebaseException] with code 'unavailable' leaving **ZERO partial state**
  /// (neither the work record is added nor the lot unlock date is rescheduled).
  ///
  /// Use this toggle for testing atomic batch rollback and consistency (e.g., TEST-R2-T2-01).
  /// For simulating the legacy defect where partial state was left behind, see [failMidBatch].
  bool simulateFailOnGuardarRegistro = false;

  /// When true, causes active session methods ([guardarSesionActiva], [obtenerSesionActiva],
  /// [limpiarSesionActiva]) to fail with an [Exception], simulating local storage I/O errors.
  ///
  /// Note: Active session operations are local to SharedPreferences and are NOT affected
  /// by [simulateNetworkError], [simulateQuotaExceeded], or [simulatePermissionDenied].
  bool simulateFailOnSesionActiva = false;

  /// Simulates the legacy (pre-atomic R2) non-atomic failure mode:
  /// persists the work record into memory but aborts before rescheduling the lot,
  /// deliberately leaving inconsistent partial state in the repository.
  ///
  /// ⚠️ DO NOT USE this toggle to test atomic WriteBatch rollback (e.g., TEST-R2-T2-01),
  /// as this toggle intentionally mutates [_registros].
  /// For atomic rollback testing where ZERO partial state is written, use
  /// [simulateFailOnGuardarRegistro] = true (or [simulateNetworkError] = true).
  bool failMidBatch = false;

  // Invocation Call Counters
  int obtenerLotesCallCount = 0;
  int guardarLoteCallCount = 0;
  int eliminarLoteCallCount = 0;
  int obtenerRegistrosCallCount = 0;
  int guardarRegistroCallCount = 0;
  int guardarSesionActivaCallCount = 0;
  int obtenerSesionActivaCallCount = 0;
  int limpiarSesionActivaCallCount = 0;

  /// Creates a [FakeOtsRepository] pre-populated with optional data or seed defaults.
  FakeOtsRepository({
    List<Lote>? initialLotes,
    List<RegistroTrabajo>? initialRegistros,
    Map<String, dynamic>? initialSesionActiva,
    bool useSeedData = false,
  }) {
    if (initialLotes != null) {
      _lotes.addAll(initialLotes);
    } else if (useSeedData) {
      _lotes.addAll(SeedData.obtenerLotesIniciales());
    }

    if (initialRegistros != null) {
      _registros.addAll(initialRegistros);
    }

    if (initialSesionActiva != null) {
      _sesionActiva = Map<String, dynamic>.from(initialSesionActiva);
    }
  }

  // State inspection getters
  List<Lote> get lotes => List.unmodifiable(_lotes);
  List<RegistroTrabajo> get registros => List.unmodifiable(_registros);
  Map<String, dynamic>? get sesionActiva =>
      _sesionActiva != null ? Map<String, dynamic>.unmodifiable(_sesionActiva!) : null;

  List<BatchOperationRecord> get batchLog => List.unmodifiable(_batchLog);
  int get atomicBatchesCommitted => _atomicBatchesCommitted;

  /// Resets all call invocation counters to zero.
  void resetCallCounters() {
    obtenerLotesCallCount = 0;
    guardarLoteCallCount = 0;
    eliminarLoteCallCount = 0;
    obtenerRegistrosCallCount = 0;
    guardarRegistroCallCount = 0;
    guardarSesionActivaCallCount = 0;
    obtenerSesionActivaCallCount = 0;
    limpiarSesionActivaCallCount = 0;
  }

  /// Alias for [resetState] adhering to standard test lifecycle conventions.
  ///
  /// Clears in-memory collections, active session, logs, failure toggles,
  /// and resets all invocation counters to zero. Optionally restores seed data.
  void reset({bool useSeedData = false}) => resetState(useSeedData: useSeedData);

  /// Clears state and logs, optionally restoring seed data.
  void resetState({bool useSeedData = false}) {
    _lotes.clear();
    _registros.clear();
    _sesionActiva = null;
    _batchLog.clear();
    _atomicBatchesCommitted = 0;

    simulateNetworkError = false;
    simulateQuotaExceeded = false;
    simulatePermissionDenied = false;
    simulateDelay = null;

    simulateFailOnObtenerLotes = false;
    simulateFailOnGuardarLote = false;
    simulateFailOnEliminarLote = false;
    simulateFailOnObtenerRegistros = false;
    simulateFailOnGuardarRegistro = false;
    simulateFailOnSesionActiva = false;
    failMidBatch = false;

    resetCallCounters();

    if (useSeedData) {
      _lotes.addAll(SeedData.obtenerLotesIniciales());
    }
  }

  /// Directly seeds lotes into memory.
  void seedLotes(List<Lote> lotes) {
    _lotes.clear();
    _lotes.addAll(lotes);
  }

  /// Directly seeds registros into memory.
  void seedRegistros(List<RegistroTrabajo> registros) {
    _registros.clear();
    _registros.addAll(registros);
  }

  /// Checks and throws simulated errors according to active toggles.
  Future<void> _checkSimulatedFailures({
    bool isRead = false,
    bool isWrite = false,
  }) async {
    if (simulateDelay != null && simulateDelay! > Duration.zero) {
      await Future<void>.delayed(simulateDelay!);
    }

    if (simulateNetworkError) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'The service is currently unavailable or network is disconnected.',
      );
    }

    if (simulateQuotaExceeded) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'resource-exhausted',
        message: 'Quota exceeded for Google Cloud Firestore operations.',
      );
    }

    if (simulatePermissionDenied) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions according to firestore.rules.',
      );
    }
  }

  @override
  Future<List<Lote>> obtenerLotes() async {
    obtenerLotesCallCount++;
    await _checkSimulatedFailures(isRead: true);

    if (simulateFailOnObtenerLotes) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Failed to retrieve lotes collection from Firestore.',
      );
    }

    final copy = List<Lote>.from(_lotes);
    copy.sort((a, b) => a.supermercado.compareTo(b.supermercado));
    return copy;
  }

  @override
  Future<Lote> guardarLote(Lote lote) async {
    guardarLoteCallCount++;
    await _checkSimulatedFailures(isWrite: true);

    if (simulateFailOnGuardarLote) {
      _batchLog.add(BatchOperationRecord(
        operation: 'guardarLote',
        timestamp: DateTime.now(),
        details: {'loteId': lote.id},
        succeeded: false,
      ));
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Failed to write lote document to Firestore.',
      );
    }

    final index = _lotes.indexWhere((l) => l.id == lote.id);
    if (index >= 0) {
      _lotes[index] = lote;
    } else {
      _lotes.add(lote);
    }

    _batchLog.add(BatchOperationRecord(
      operation: 'guardarLote',
      timestamp: DateTime.now(),
      details: {
        'loteId': lote.id,
        'supermercado': lote.supermercado,
        'proximoDesbloqueo': lote.proximoDesbloqueo?.toIso8601String(),
      },
      succeeded: true,
    ));

    return lote;
  }

  @override
  Future<void> eliminarLote(String id) async {
    eliminarLoteCallCount++;
    await _checkSimulatedFailures(isWrite: true);

    if (simulateFailOnEliminarLote) {
      _batchLog.add(BatchOperationRecord(
        operation: 'eliminarLote',
        timestamp: DateTime.now(),
        details: {'loteId': id},
        succeeded: false,
      ));
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Deletion denied for lote $id.',
      );
    }

    _lotes.removeWhere((l) => l.id == id);
    _batchLog.add(BatchOperationRecord(
      operation: 'eliminarLote',
      timestamp: DateTime.now(),
      details: {'loteId': id},
      succeeded: true,
    ));
  }

  @override
  Future<List<RegistroTrabajo>> obtenerRegistros() async {
    obtenerRegistrosCallCount++;
    await _checkSimulatedFailures(isRead: true);

    if (simulateFailOnObtenerRegistros) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Failed to retrieve registros_trabajo collection.',
      );
    }

    final copy = List<RegistroTrabajo>.from(_registros);
    copy.sort((a, b) => b.inicio.compareTo(a.inicio));
    return copy;
  }

  /// Atomically persists [registro] and reschedules the corresponding [Lote].
  ///
  /// Emulates Firestore's `WriteBatch.commit()` atomic transaction.
  ///
  /// Failure simulation behaviors:
  /// - [simulateFailOnGuardarRegistro] (or [simulateNetworkError]): Simulates genuine
  ///   atomic batch rollback where the connection drops or the transaction aborts.
  ///   Throws [FirebaseException] and commits **ZERO partial state** ([registros] and [lotes] untouched).
  ///   Use this for R2 atomicity tests (e.g., TEST-R2-T2-01).
  /// - [failMidBatch]: Simulates the legacy non-atomic defect where the work record was
  ///   written first, but a subsequent error prevented lot rescheduling.
  ///   Inserts [registro] and throws [FirebaseException], leaving partial state for recovery tests.
  @override
  Future<RegistroTrabajo> guardarRegistro(RegistroTrabajo registro) async {
    guardarRegistroCallCount++;
    await _checkSimulatedFailures(isWrite: true);

    if (simulateFailOnGuardarRegistro) {
      _batchLog.add(BatchOperationRecord(
        operation: 'guardarRegistroAtomicBatch',
        timestamp: DateTime.now(),
        details: {'registroId': registro.id, 'loteId': registro.loteId},
        succeeded: false,
      ));
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'WriteBatch commit aborted due to network failure.',
      );
    }

    if (failMidBatch) {
      // Simulate partial write failure (pre-atomic behavior)
      _registros.insert(0, registro);
      _batchLog.add(BatchOperationRecord(
        operation: 'partial_write_aborted_mid_batch',
        timestamp: DateTime.now(),
        details: {
          'registroId': registro.id,
          'loteId': registro.loteId,
          'error': 'Interrupted before lot reschedule',
        },
        succeeded: false,
      ));
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Connection dropped during batch commit.',
      );
    }

    // Atomic execution: Work record inserted and Lot rescheduled together
    _registros.insert(0, registro);

    final index = _lotes.indexWhere((l) => l.id == registro.loteId);
    if (index >= 0) {
      final loteActual = _lotes[index];
      final loteActualizado = loteActual.copyWith(
        supermercado: registro.supermercado,
        area: registro.area,
        ultimoInicio: registro.inicio,
        proximoDesbloqueo: registro.nuevoDesbloqueo,
        cantidadProductos: registro.cantidadProductos > 0
            ? registro.cantidadProductos
            : loteActual.cantidadProductos,
      );
      _lotes[index] = loteActualizado;
    } else {
      // If lot is not present, upsert a new one aligned with atomic batch semantics
      final nuevoLote = Lote.crear(
        id: registro.loteId,
        supermercado: registro.supermercado,
        area: registro.area,
        cantidadProductos: registro.cantidadProductos,
        ultimoInicio: registro.inicio,
      ).copyWith(proximoDesbloqueo: registro.nuevoDesbloqueo);
      _lotes.add(nuevoLote);
    }

    _atomicBatchesCommitted++;
    _batchLog.add(BatchOperationRecord(
      operation: 'guardarRegistroAtomicBatch',
      timestamp: DateTime.now(),
      details: {
        'registroId': registro.id,
        'loteId': registro.loteId,
        'duracionMinutos': registro.duracionMinutos,
        'nuevoDesbloqueo': registro.nuevoDesbloqueo.toIso8601String(),
        'atomicBatchIndex': _atomicBatchesCommitted,
      },
      succeeded: true,
    ));

    return registro;
  }

  @override
  Future<void> guardarSesionActiva(Map<String, dynamic> sesion) async {
    guardarSesionActivaCallCount++;
    if (simulateDelay != null && simulateDelay! > Duration.zero) {
      await Future<void>.delayed(simulateDelay!);
    }

    if (simulateFailOnSesionActiva) {
      throw Exception('Failed to persist active session.');
    }

    _sesionActiva = Map<String, dynamic>.from(sesion);
    _batchLog.add(BatchOperationRecord(
      operation: 'guardarSesionActiva',
      timestamp: DateTime.now(),
      details: {'loteId': sesion['loteId']},
      succeeded: true,
    ));
  }

  @override
  Future<Map<String, dynamic>?> obtenerSesionActiva() async {
    obtenerSesionActivaCallCount++;
    if (simulateDelay != null && simulateDelay! > Duration.zero) {
      await Future<void>.delayed(simulateDelay!);
    }

    if (simulateFailOnSesionActiva) {
      throw Exception('Failed to read active session.');
    }

    return _sesionActiva != null ? Map<String, dynamic>.from(_sesionActiva!) : null;
  }

  @override
  Future<void> limpiarSesionActiva() async {
    limpiarSesionActivaCallCount++;
    if (simulateDelay != null && simulateDelay! > Duration.zero) {
      await Future<void>.delayed(simulateDelay!);
    }

    if (simulateFailOnSesionActiva) {
      throw Exception('Failed to clear active session.');
    }

    _sesionActiva = null;
    _batchLog.add(BatchOperationRecord(
      operation: 'limpiarSesionActiva',
      timestamp: DateTime.now(),
      details: {},
      succeeded: true,
    ));
  }
}
