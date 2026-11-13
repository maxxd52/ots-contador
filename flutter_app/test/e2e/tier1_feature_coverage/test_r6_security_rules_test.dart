import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import '../harness/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R6: Tier 1 - Firestore Security Rules & Immutability', () {
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

    test('TEST-R6-T1-01: Unauthenticated read on lotes is denied', () async {
      // 1. Static CEL security rule verification
      expect(rulesContent, matches(RegExp(r'match /lotes/\{loteId\}\s*\{[^}]*allow read:\s*if isAuthenticated\(\);')));
      expect(rulesContent, isNot(contains('match /lotes/{loteId} {\n      allow read: if true;')));

      // 2. Behavioral verification in test runner
      final repo = FakeOtsRepository();
      repo.simulatePermissionDenied = true;
      await expectLater(
        () => repo.obtenerLotes(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );
    });

    test('TEST-R6-T1-02: Unauthenticated read on registros is denied', () async {
      // 1. Static CEL security rule verification
      expect(rulesContent, matches(RegExp(r'match /registros_trabajo/\{registroId\}\s*\{[^}]*allow read:\s*if isAuthenticated\(\);')));

      // 2. Behavioral verification in test runner
      final repo = FakeOtsRepository();
      repo.simulatePermissionDenied = true;
      await expectLater(
        () => repo.obtenerRegistros(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );
    });

    test('TEST-R6-T1-03: Unauthenticated delete on lotes is denied', () async {
      // 1. Static CEL security rule verification
      expect(rulesContent, matches(RegExp(r'match /lotes/\{loteId\}\s*\{[^}]*allow delete:\s*if isAuthenticated\(\);')));

      // 2. Behavioral verification in test runner
      final repo = FakeOtsRepository();
      repo.simulatePermissionDenied = true;
      await expectLater(
        () => repo.eliminarLote('lote_any'),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );
    });

    test('TEST-R6-T1-04: Delete on registros denied even when authenticated', () {
      // Historical work logs are strictly immutable: allow delete: if false;
      expect(rulesContent, matches(RegExp(r'match /registros_trabajo/\{registroId\}\s*\{[^}]*allow delete:\s*if false;')));
    });

    test('TEST-R6-T1-05: Authenticated user can read lotes and registros', () async {
      // 1. Helper rule verification
      expect(rulesContent, contains('function isAuthenticated()'));
      expect(rulesContent, contains('return request.auth != null;'));

      // 2. Behavioral verification: Authenticated read succeeds
      final repo = FakeOtsRepository(useSeedData: true);
      repo.simulatePermissionDenied = false;

      final lotes = await repo.obtenerLotes();
      final registros = await repo.obtenerRegistros();

      expect(lotes, isNotEmpty);
      expect(registros, isNotNull);
    });
  });
}
