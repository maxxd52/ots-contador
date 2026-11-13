import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/domain/models/registro_trabajo.dart';
import '../harness/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String rulesContent;

  setUpAll(() {
    final possiblePaths = [
      '../firestore.rules',
      'firestore.rules',
      '../../firestore.rules',
    ];
    File? foundFile;
    for (final p in possiblePaths) {
      final f = File(p);
      if (f.existsSync()) {
        foundFile = f;
        break;
      }
    }
    expect(foundFile, isNotNull, reason: 'firestore.rules file must be reachable');
    rulesContent = foundFile!.readAsStringSync();
  });

  setUp(() {
    MockSharedPreferencesHelper.setEmpty();
  });

  group('Tier 2 - R6: Security Attack Scenarios & CEL Rules Enforcement', () {
    // TEST-R6-T2-01: Authenticated user cannot delete any registros document
    test('TEST-R6-T2-01: Authenticated deletion on registros_trabajo is unconditionally denied in rules', () {
      // 1. Static CEL security rules verification
      final registrosBlock = RegExp(
        r'match /registros_trabajo/\{registroId\}\s*\{([^}]+)\}',
        multiLine: true,
      ).firstMatch(rulesContent);

      expect(registrosBlock, isNotNull, reason: 'registros_trabajo match block must exist');
      final blockText = registrosBlock!.group(1)!;

      // Unconditional denial: allow delete: if false;
      expect(
        blockText,
        matches(RegExp(r'allow\s+delete:\s*if\s+false;')),
        reason: 'Deletion on historical work records must be strictly denied (allow delete: if false;)',
      );

      // Verify no conditional delete (such as isAuthenticated) exists for work records
      expect(
        blockText,
        isNot(matches(RegExp(r'allow\s+delete:\s*if\s+isAuthenticated'))),
        reason: 'Even authenticated users must never delete historical work records',
      );
    });

    // TEST-R6-T2-02: Create lote with missing required fields is rejected
    test('TEST-R6-T2-02: Creating a lote with missing required fields is rejected by schema validator', () {
      // 1. Static CEL validator verification
      expect(
        rulesContent,
        contains("hasRequiredFields([\n               'id', 'supermercado', 'area', 'cantidadProductos', 'creadoEn'\n             ])"),
        reason: 'Rules must enforce required fields on lot creation',
      );

      expect(
        rulesContent,
        contains("hasOnlyAllowedFields([\n               'id', 'supermercado', 'area', 'cantidadProductos',\n               'ultimoInicio', 'proximoDesbloqueo', 'notas', 'creadoEn'\n             ])"),
        reason: 'Rules must reject unknown fields on lot creation',
      );

      // 2. Domain model verification
      final validLote = Lote.crear(
        id: 'lote_valid_req',
        supermercado: 'Carrefour Central',
        area: 'Fiambrería',
        cantidadProductos: 30,
      );
      expect(validLote.id, isNotEmpty);
      expect(validLote.supermercado, isNotEmpty);
      expect(validLote.area, isNotEmpty);
      expect(validLote.cantidadProductos, greaterThanOrEqualTo(0));
      expect(validLote.creadoEn, isNotNull);
    });

    // TEST-R6-T2-03: Create registro with negative duration is rejected
    test('TEST-R6-T2-03: Creating registro with negative duration is rejected at rules and domain layers', () {
      // 1. CEL validator verification
      expect(
        rulesContent,
        contains('data.duracionMinutos is number && data.duracionMinutos >= 0 && data.duracionMinutos <= 14400'),
        reason: 'Rules must enforce duracionMinutos between 0 and 14400',
      );
      expect(
        rulesContent,
        contains('data.horasDecimales is number && data.horasDecimales >= 0 && data.horasDecimales <= 240'),
        reason: 'Rules must enforce horasDecimales between 0 and 240',
      );

      // 2. Domain model guard verification
      final inicio = DateTime(2026, 11, 12, 10, 0);
      final finNegativo = inicio.subtract(const Duration(minutes: 10));

      expect(
        () => RegistroTrabajo.crear(
          loteId: 'lote_neg_dur',
          supermercado: 'Coto',
          area: 'Bebidas',
          inicio: inicio,
          fin: finNegativo,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('no puede ser anterior'),
        )),
      );
    });

    // TEST-R6-T2-04: Modifying immutable creadoEn timestamp is rejected
    test('TEST-R6-T2-04: Modifying immutable creadoEn timestamp is rejected on both collections', () {
      // 1. Verify on lotes collection
      expect(
        rulesContent,
        matches(RegExp(
          r'match /lotes/\{loteId\}\s*\{[\s\S]*?allow update:[^;]*request\.resource\.data\.creadoEn == resource\.data\.creadoEn',
        )),
        reason: 'lotes update rule must enforce immutability of creadoEn',
      );

      // 2. Verify on registros_trabajo collection
      expect(
        rulesContent,
        matches(RegExp(
          r'match /registros_trabajo/\{registroId\}\s*\{[\s\S]*?allow update:[^;]*request\.resource\.data\.creadoEn == resource\.data\.creadoEn',
        )),
        reason: 'registros_trabajo update rule must enforce immutability of creadoEn',
      );
    });

    // TEST-R6-T2-05: Tampering document ID in payload vs path is rejected
    test('TEST-R6-T2-05: Document ID tampering in payload body vs path is rejected by rules', () {
      // 1. Verify id == path parameter on create and update in lotes
      expect(
        rulesContent,
        contains('request.resource.data.id == loteId'),
        reason: 'lotes rules must bind payload id to URL document ID',
      );
      expect(
        rulesContent,
        contains('request.resource.data.id == resource.data.id'),
        reason: 'lotes update rule must prevent id mutations',
      );

      // 2. Verify id == path parameter on create and update in registros_trabajo
      expect(
        rulesContent,
        contains('request.resource.data.id == registroId'),
        reason: 'registros_trabajo rules must bind payload id to URL document ID',
      );
      expect(
        rulesContent,
        contains('request.resource.data.id == resource.data.id'),
        reason: 'registros_trabajo update rule must prevent id mutations',
      );
    });
  });
}
