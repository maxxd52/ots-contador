import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import 'package:flutter_app/ui/views/modal_sesion_sheet.dart';
import '../harness/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockSharedPreferencesHelper.setEmpty();
  });

  group('Tier 2 - R5: Debounce Stress & Mutex Concurrency', () {
    // TEST-R5-T2-01: High-frequency burst (5 rapid taps) in ModalSesionSheet
    testWidgets('TEST-R5-T2-01: High-frequency burst of 5 rapid taps executes callback exactly once', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int onGuardarCallCount = 0;
      final lote = LoteBuilder.habilitado().build();

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: DateTime(2026, 11, 12, 10, 0),
          fin: DateTime(2026, 11, 12, 10, 45),
          onGuardar: ({
            required loteId,
            required supermercado,
            required area,
            required cantidadProductos,
            required inicio,
            required fin,
            observaciones,
          }) async {
            onGuardarCallCount++;
            await Future<void>.delayed(const Duration(milliseconds: 100));
          },
        ),
      );

      final btn = find.byType(ElevatedButton).last;
      for (int i = 0; i < 5; i++) {
        await tester.tap(btn, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      expect(onGuardarCallCount, equals(1));
      expect(find.byType(ModalSesionSheet), findsNothing);
    });

    // TEST-R5-T2-02: Button visually disables during asynchronous save
    testWidgets('TEST-R5-T2-02: Button visually disables and displays spinner during pending submission', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final completer = Completer<void>();
      final lote = LoteBuilder.habilitado().build();

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: DateTime(2026, 11, 12, 10, 0),
          fin: DateTime(2026, 11, 12, 10, 45),
          onGuardar: ({
            required loteId,
            required supermercado,
            required area,
            required cantidadProductos,
            required inicio,
            required fin,
            observaciones,
          }) async {
            await completer.future;
          },
        ),
      );

      final btnFinder = find.text('Guardar y Reprogramar');
      await tester.tap(btnFinder);
      await tester.pump(); // Advance single frame to update widget with _isSubmitting = true

      final elevatedBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton).last);
      expect(elevatedBtn.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Guardar y Reprogramar'), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ModalSesionSheet), findsNothing);
    });

    // TEST-R5-T2-03: Submission failure releases debounce lock for retry
    testWidgets('TEST-R5-T2-03: Submission failure resets isSubmitting and re-enables button for retry', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int attempts = 0;
      final lote = LoteBuilder.habilitado().build();

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: DateTime(2026, 11, 12, 10, 0),
          fin: DateTime(2026, 11, 12, 10, 45),
          onGuardar: ({
            required loteId,
            required supermercado,
            required area,
            required cantidadProductos,
            required inicio,
            required fin,
            observaciones,
          }) async {
            attempts++;
            if (attempts == 1) {
              throw Exception('Simulated network timeout');
            }
          },
        ),
      );

      // Attempt 1: Throws exception
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Simulated network timeout'), findsOneWidget);
      expect(find.byType(ModalSesionSheet), findsOneWidget);

      final state = tester.state<ModalSesionSheetState>(find.byType(ModalSesionSheet));
      expect(state.isSubmitting, isFalse);

      final elevatedBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton).last);
      expect(elevatedBtn.onPressed, isNotNull);

      // Attempt 2: Succeeds and closes modal
      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      expect(attempts, equals(2));
      expect(find.byType(ModalSesionSheet), findsNothing);
    });

    // TEST-R5-T2-04: Rapid tapping on quick duration chips preserves state
    testWidgets('TEST-R5-T2-04: Rapid tapping on quick duration chips settles cleanly on last selection', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lote = LoteBuilder.habilitado().build();
      final inicio = DateTime(2026, 11, 12, 10, 0);
      DateTime? savedFin;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: inicio,
          onGuardar: ({
            required loteId,
            required supermercado,
            required area,
            required cantidadProductos,
            required inicio,
            required fin,
            observaciones,
          }) {
            savedFin = fin;
          },
        ),
      );

      // Rapidly tap all chips in sequence and end on +30 min
      await tester.tap(find.text('+30 min'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.text('+45 min'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.text('+1 hora'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.text('+1.5 h'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.text('+30 min'));
      await tester.pumpAndSettle();

      expect(find.text('0h 30m'), findsOneWidget);

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      expect(savedFin, equals(inicio.add(const Duration(minutes: 30))));
    });

    // TEST-R5-T2-05: Concurrent lot creation and session save do not deadlock
    test('TEST-R5-T2-05: Concurrent lot creation and session save execute independently without deadlock', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      repo.simulateDelay = const Duration(milliseconds: 40);
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      final targetLote = vm.lotes.first;
      final newLote = Lote.crear(
        id: 'lote_concurrent_05',
        supermercado: 'Coto Express',
        area: 'Fiambrería',
        cantidadProductos: 35,
      );

      final f1 = vm.guardarLote(newLote);
      final f2 = vm.guardarSesionFotos(
        loteId: targetLote.id,
        supermercado: targetLote.supermercado,
        area: targetLote.area,
        cantidadProductos: targetLote.cantidadProductos,
        inicio: DateTime(2026, 11, 12, 10, 0),
        fin: DateTime(2026, 11, 12, 10, 45),
      );

      await Future.wait([f1, f2]);

      expect(vm.isSavingLote, isFalse);
      expect(vm.isSavingSesion, isFalse);
      expect(repo.guardarLoteCallCount, equals(1));
      expect(repo.guardarRegistroCallCount, equals(1));
      expect(vm.lotes.any((l) => l.id == 'lote_concurrent_05'), isTrue);
      expect(vm.registros.length, equals(1));
    });
  });
}
