import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/data/repositories/ots_repository.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import 'package:flutter_app/ui/views/home_screen.dart';
import 'e2e/harness/fake_ots_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CHALLENGER PROBE 1: Adversarial Fuzzing of TableroViewModel.parsearFechaInicio', () {
    test('Empirical Fuzzing: Negative numbers, zeros, and extreme limits never throw unhandled exceptions', () {
      final negativeInputs = <dynamic>[
        -1,
        -1000,
        -1715498400,
        -999999999999,
        -9223372036854775808, // min 64-bit signed integer
        -1.0,
        -500.5,
        -1e10,
        -1e300,
        0,
        0.0,
      ];

      for (final input in negativeInputs) {
        expect(
          () {
            final res = TableroViewModel.parsearFechaInicio(input);
            // Result must either be a valid DateTime or null — never throw!
            if (res != null) {
              expect(res, isA<DateTime>());
            }
          },
          returnsNormally,
          reason: 'Failed on negative input: $input (${input.runtimeType})',
        );
      }
    });

    test('Empirical Fuzzing: Giant numbers (> 2^53, max 64-bit, overflows) never throw unhandled exceptions', () {
      final giantInputs = <dynamic>[
        9007199254740992, // 2^53
        9007199254740993, // 2^53 + 1
        8640000000000000, // max Dart DateTime ms limit (year ~275760)
        8640000000000001, // exceeds Dart DateTime limit (would throw ArgumentError if unhandled)
        9223372036854775807, // max 64-bit integer
        1e15,
        1e20,
        1e300,
        1.7976931348623157e+308, // double.maxFinite
      ];

      for (final input in giantInputs) {
        expect(
          () {
            final res = TableroViewModel.parsearFechaInicio(input);
            if (res != null) {
              expect(res, isA<DateTime>());
            }
          },
          returnsNormally,
          reason: 'Failed on giant input: $input (${input.runtimeType})',
        );
      }
    });

    test('Empirical Fuzzing: IEEE 754 specials (NaN, Infinity, -Infinity) never throw unhandled exceptions', () {
      final specialNumbers = <double>[
        double.nan,
        double.infinity,
        -double.infinity,
      ];

      for (final input in specialNumbers) {
        expect(
          () {
            final res = TableroViewModel.parsearFechaInicio(input);
            // NaN and infinities must safely return null without throwing UnsupportedError
            expect(res, isNull, reason: 'Expected null for special number $input');
          },
          returnsNormally,
          reason: 'Failed on IEEE 754 input: $input',
        );
      }

      // -0.0 is finite and equals 0.0 -> returns DateTime epoch 0 without throwing
      expect(() => TableroViewModel.parsearFechaInicio(-0.0), returnsNormally);
      expect(TableroViewModel.parsearFechaInicio(-0.0), isA<DateTime>());
    });

    test('Empirical Fuzzing: Emojis, Unicode control characters, RTL overrides, and null bytes never throw', () {
      final weirdStrings = <String>[
        '🔥',
        '🎉 2026-11-12',
        '💀💀💀',
        '🤖 1715498400',
        '2026-11-12 🔥 10:00:00',
        '\u0000', // null byte
        '2026-11-12\u0000T00:00:00',
        '\u200B', // zero-width space
        '\u200B2026-11-12T05:00:00Z',
        '\u202E2026-11-12\u202C', // RTL override
        'مرحبا 2026-11-12', // Arabic
        'こんにちは 2026-11-12', // Japanese
        '\n\r\t',
        '!@#\$%^&*()_+{}[]:;"\'<>?,./~`',
        '\\',
        '///',
      ];

      for (final input in weirdStrings) {
        expect(
          () {
            final res = TableroViewModel.parsearFechaInicio(input);
            if (res != null) {
              expect(res, isA<DateTime>());
            }
          },
          returnsNormally,
          reason: 'Failed on weird string input: "$input"',
        );
      }
    });

    test('Empirical Fuzzing: Malformed date strings and date boundaries never throw FormatException', () {
      final malformedDates = <String>[
        '2026-02-31', // invalid day in Feb (Dart tryParse normalizes or keeps; must not throw)
        '2026-99-99', // out-of-bounds month/day -> must safely return null
        '2026-00-10', // month 0 -> must safely return null
        '2026-13-10', // month 13 -> must safely return null
        '2026-04-32', // day 32 -> must safely return null
        '2026-04-00', // day 0 -> must safely return null
        '2026-12-00', // day 0 -> must safely return null
        '2026-00-00', // month 0, day 0 -> must safely return null
        'abc',
        'not a date',
        '2026',
        '2026-',
        '2026-11',
        '2026-11-',
        '--::T',
        '-1715498400',
        '171549840000000000000000000000000000000000000000', // overflow for int.tryParse
        '999999999999999999999999999999999999999999999999',
        '0',
        '1',
        '999999999', // 9 digits (below 10-digit epoch seconds threshold)
        '     ',
        '',
      ];

      for (final input in malformedDates) {
        expect(
          () {
            final res = TableroViewModel.parsearFechaInicio(input);
            if (input == '2026-99-99' ||
                input == '2026-00-10' ||
                input == '2026-13-10' ||
                input == '2026-04-32' ||
                input == '2026-04-00' ||
                input == '2026-00-00' ||
                input == 'abc' ||
                input == 'not a date' ||
                input == '     ' ||
                input == '') {
              expect(res, isNull, reason: 'Expected null for invalid date string "$input"');
            }
          },
          returnsNormally,
          reason: 'Failed on malformed date string: "$input"',
        );
      }
    });

    test('Empirical Fuzzing: Collections, Symbols, Closures, and Complex Objects safely return null without TypeError', () {
      final complexObjects = <dynamic>[
        {}, // empty map
        {'nested': {'a': 1}},
        [], // empty list
        [1, 2, 3],
        [[1, 2], [3, 4]],
        {'set_item_1', 'set_item_2'},
        #someSymbol,
        () => '2026-11-12',
        () => null,
        Object(),
        DateTime, // The Type object itself
        StringBuffer('2026-11-12'),
      ];

      for (final input in complexObjects) {
        expect(
          () {
            final res = TableroViewModel.parsearFechaInicio(input);
            expect(res, isNull, reason: 'Expected null for complex object $input');
          },
          returnsNormally,
          reason: 'Failed on complex object input: $input (${input.runtimeType})',
        );
      }
    });
  });

  group('CHALLENGER PROBE 2: Persistent Storage Crash Loop Breaking & Self-Healing', () {
    test('Crash loop break: Corrupted timestamp values in SharedPreferences are purged and restart cleanly', () async {
      final corruptPayloads = <Map<String, dynamic>>[
        {'loteId': 'lote_c1', 'inicio': 'malformed-string'},
        {'loteId': 'lote_c2', 'inicio': '2026-99-99'},
        {'loteId': 'lote_c3', 'inicio': null},
        {'loteId': 'lote_c4'}, // missing 'inicio' key
        {'inicio': '2026-11-12T05:00:00Z'}, // missing 'loteId' key
        {'loteId': '', 'inicio': '2026-11-12T05:00:00Z'}, // empty 'loteId'
        {'loteId': 12345, 'inicio': '2026-11-12T05:00:00Z'}, // non-string 'loteId'
        {'loteId': 'lote_c5', 'inicio': true}, // boolean inicio
        {'loteId': 'lote_c6', 'inicio': [2026, 11, 12]}, // list inicio
        {'loteId': 'lote_c7', 'inicio': {'year': 2026}}, // map inicio
        {'loteId': 'lote_c8', 'inicio': double.nan}, // NaN inicio
        {'loteId': 'lote_c9', 'inicio': 9223372036854775807}, // out of range integer
      ];

      for (int i = 0; i < corruptPayloads.length; i++) {
        final payload = corruptPayloads[i];
        final repo = FakeOtsRepository(
          useSeedData: true,
          initialSesionActiva: payload,
        );

        // --- LAUNCH 1: Startup encounters corrupt session ---
        final vm1 = TableroViewModel(repository: repo);
        await vm1.inicializar();

        expect(vm1.sesionActiva, isNull, reason: 'vm1 did not nullify corrupt session for case $i');
        expect(vm1.segundosTranscurridos, equals(0), reason: 'vm1 did not reset seconds for case $i');
        expect(repo.sesionActiva, isNull, reason: 'repo did not purge corrupt session for case $i');
        expect(repo.limpiarSesionActivaCallCount, greaterThanOrEqualTo(1));
        vm1.dispose();

        // --- LAUNCH 2: Immediate App Restart on same repo ---
        final vm2 = TableroViewModel(repository: repo);
        await vm2.inicializar();

        expect(vm2.sesionActiva, isNull, reason: 'vm2 did not stay clean after restart for case $i');
        expect(vm2.segundosTranscurridos, equals(0));
        expect(vm2.isLoading, isFalse);
        vm2.dispose();

        // --- LAUNCH 3: Third sequential launch to verify zero crash-looping ---
        final vm3 = TableroViewModel(repository: repo);
        await vm3.inicializar();
        expect(vm3.sesionActiva, isNull);
        vm3.dispose();
      }
    });

    test('LocalOtsRepository with raw SharedPreferences: Malformed JSON strings in storage return null safely', () async {
      // Mock SharedPreferences with raw corrupt JSON
      SharedPreferences.setMockInitialValues({
        LocalOtsRepository.keySesionActiva: '{this is completely malformed json: not valid at all}',
      });

      final localRepo = LocalOtsRepository();
      final sesion = await localRepo.obtenerSesionActiva();
      expect(sesion, isNull);

      // Verify TableroViewModel initializes cleanly against this corrupt storage
      final vm = TableroViewModel(repository: localRepo);
      await vm.inicializar();

      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(vm.errorMessage, isNull);
      vm.dispose();
    });

    test('LocalOtsRepository with raw SharedPreferences: Non-Map JSON (e.g. JSON list or string) returns null safely', () async {
      // Mock SharedPreferences with valid JSON that is NOT a Map
      SharedPreferences.setMockInitialValues({
        LocalOtsRepository.keySesionActiva: jsonEncode(['item1', 'item2']),
      });

      final localRepo = LocalOtsRepository();
      final sesion = await localRepo.obtenerSesionActiva();
      expect(sesion, isNull);

      final vm = TableroViewModel(repository: localRepo);
      await vm.inicializar();

      expect(vm.sesionActiva, isNull);
      vm.dispose();
    });
  });

  group('CHALLENGER PROBE 3: Runtime Timer & Asynchronous Corruption Probes', () {
    test('Runtime injection: Mutating active session while timer is ticking triggers clean cancel without zone errors', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final lote = Lote.crear(
        supermercado: 'Coto Central',
        area: 'Bebidas',
        cantidadProductos: 50,
      );

      // Start legitimate session
      await vm.iniciarFotos(lote);
      expect(vm.sesionActiva, isNotNull);
      expect(vm.sesionActiva!['loteId'], equals(lote.id));

      // Wait briefly for timer to tick at least once
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(vm.segundosTranscurridos, greaterThanOrEqualTo(1));

      // Inject corruption into active session at runtime
      vm.sesionActiva!['inicio'] = 'corrupted_at_runtime';

      // Let timer tick again with corrupted state
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      // Auto-recovery must have triggered:
      expect(vm.sesionActiva, isNull, reason: 'Active session was not nullified after runtime corruption');
      expect(vm.segundosTranscurridos, equals(0), reason: 'Seconds were not reset to 0');
      expect(repo.sesionActiva, isNull, reason: 'Corrupt session was not purged from repository');

      // Wait additional time to verify timer is truly cancelled and doesn't fire again
      final purgeCallsBefore = repo.limpiarSesionActivaCallCount;
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final purgeCallsAfter = repo.limpiarSesionActivaCallCount;

      expect(purgeCallsAfter, equals(purgeCallsBefore), reason: 'Timer kept ticking after corruption recovery!');

      vm.dispose();
    });

    test('Asynchronous resilience: If repository.limpiarSesionActiva() fails during auto-recovery, error is caught gracefully', () async {
      final failingRepo = FailingPurgeFakeOtsRepository(
        initialSesionActiva: {
          'loteId': 'lote_fail_1',
          'inicio': 'bad-timestamp',
        },
      );
      final vm = TableroViewModel(repository: failingRepo);

      // Must not throw or crash unhandled zone
      await expectLater(vm.inicializar(), completes);

      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      vm.dispose();
    });

    test('Future timestamp: In-flight or stored future session timestamp clamps to 0 seconds without error', () async {
      final futureTime = DateTime.now().add(const Duration(days: 30));
      final repo = FakeOtsRepository(
        useSeedData: true,
        initialSesionActiva: {
          'loteId': 'lote_seed_1',
          'inicio': futureTime.toIso8601String(),
        },
      );

      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      // Session is retained because future DateTime is structurally valid, but elapsed seconds must clamp to 0
      expect(vm.sesionActiva, isNotNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(vm.cronometroTexto, equals('00:00'));

      vm.dispose();
    });

    test('Threshold boundary: 10,000,000,000 epoch boundary handles seconds vs milliseconds gracefully', () {
      // 9,999,999,999 (< 10B) is treated as seconds -> multiplied by 1000
      final resBelow = TableroViewModel.parsearFechaInicio(9999999999);
      expect(resBelow, isNotNull);
      expect(resBelow!.millisecondsSinceEpoch, equals(9999999999 * 1000));

      // 10,000,000,000 (>= 10B) is treated directly as milliseconds
      final resAbove = TableroViewModel.parsearFechaInicio(10000000000);
      expect(resAbove, isNotNull);
      expect(resAbove!.millisecondsSinceEpoch, equals(10000000000));
    });

    testWidgets('Widget Stress: HomeScreen handles runtime session corruption without red screen or uncaught FlutterError', (tester) async {
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

      // Start session
      final lote = vm.lotes.first;
      await vm.iniciarFotos(lote);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      // Verify active timer card is visible
      expect(find.textContaining('Terminar Fotos'), findsOneWidget);

      // Now inject runtime corruption into ViewModel's active session
      vm.sesionActiva!['inicio'] = 'bad_corrupt_date_runtime';

      // Pump 1 second to trigger the periodic timer tick
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify auto-recovery executed: session nullified, timer stopped, Terminar Fotos button removed
      expect(vm.sesionActiva, isNull);
      expect(vm.segundosTranscurridos, equals(0));
      expect(find.textContaining('Terminar Fotos'), findsNothing);

      // Clean teardown
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
    });
  });
}

class FailingPurgeFakeOtsRepository extends FakeOtsRepository {
  FailingPurgeFakeOtsRepository({super.initialSesionActiva})
      : super(useSeedData: true);

  @override
  Future<void> limpiarSesionActiva() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    throw Exception('Simulated disk I/O failure when clearing active session');
  }
}
