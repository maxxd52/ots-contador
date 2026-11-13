import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';
import 'package:flutter_app/ui/views/modal_sesion_sheet.dart';
import 'package:flutter_app/ui/views/modal_lote_sheet.dart';
import '../harness/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockSharedPreferencesHelper.setEmpty();
  });

  group('R5: Tier 1 - Mutation Idempotency & UI Debouncing', () {
    testWidgets('TEST-R5-T1-01: Single tap on session submit executes once', (tester) async {
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

      int saveCount = 0;
      final lote = LoteBuilder.habilitado().build();

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: DateTime(2026, 11, 12, 10, 0),
          fin: DateTime(2026, 11, 12, 10, 45),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) {
            saveCount++;
          },
        ),
      );

      await tester.tap(find.text('Guardar y Reprogramar'));
      await tester.pumpAndSettle();

      expect(saveCount, equals(1));
      expect(find.byType(ModalSesionSheet), findsNothing);
    });

    testWidgets('TEST-R5-T1-02: Rapid double-tap on session submit executes once', (tester) async {
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

      int saveCount = 0;
      final lote = LoteBuilder.habilitado().build();

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalSesionSheet(
          lote: lote,
          inicio: DateTime(2026, 11, 12, 10, 0),
          fin: DateTime(2026, 11, 12, 10, 45),
          onGuardar: ({required loteId, required supermercado, required area, required cantidadProductos, required inicio, required fin, observaciones}) async {
            saveCount++;
            await Future<void>.delayed(const Duration(milliseconds: 50));
          },
        ),
      );

      final button = find.text('Guardar y Reprogramar');
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false); // Duplicate tap immediately
      await tester.pumpAndSettle();

      expect(saveCount, equals(1), reason: 'Debounce / unmount guard suppressed duplicate tap');
      expect(find.byType(ModalSesionSheet), findsNothing);
    });

    testWidgets('TEST-R5-T1-03: Rapid double-tap on lot creation executes once', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int createCount = 0;

      await WidgetTestHarness.pumpWidget(
        tester,
        child: ModalLoteSheet(
          onGuardar: (l) async {
            createCount++;
            await Future<void>.delayed(const Duration(milliseconds: 50));
          },
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'Carrefour');
      await tester.enterText(find.byType(TextField).at(1), 'Bebidas');

      final btn = find.text('Crear Lote');
      await tester.tap(btn);
      await tester.tap(btn, warnIfMissed: false); // Duplicate tap
      await tester.pumpAndSettle();

      expect(createCount, equals(1), reason: 'Debounce / unmount guard suppressed duplicate lot creation');
      expect(find.byType(ModalLoteSheet), findsNothing);
    });

    test('TEST-R5-T1-04: ViewModel guardarSesionFotos mutex blocks concurrent call', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      repo.simulateDelay = const Duration(milliseconds: 50);
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      final initialLoteCount = vm.lotes.length;
      final targetLote = vm.lotes.first;
      final start = DateTime(2026, 11, 12, 10, 0);
      final fin = DateTime(2026, 11, 12, 10, 45);

      // Launch two concurrent calls simultaneously
      final future1 = vm.guardarSesionFotos(
        loteId: targetLote.id,
        supermercado: targetLote.supermercado,
        area: targetLote.area,
        cantidadProductos: 55,
        inicio: start,
        fin: fin,
      );
      final future2 = vm.guardarSesionFotos(
        loteId: targetLote.id,
        supermercado: targetLote.supermercado,
        area: targetLote.area,
        cantidadProductos: 55,
        inicio: start,
        fin: fin,
      );

      await Future.wait([future1, future2]);

      // Assert mutex allowed exactly 1 write
      expect(repo.guardarRegistroCallCount, equals(1), reason: 'Concurrent call blocked by _isSavingSesion mutex');
      expect(repo.registros.length, equals(1));
      expect(repo.guardarLoteCallCount, equals(0), reason: 'Redundant secondary write eliminated');
      expect(vm.isSavingSesion, isFalse);

      // Verify lot was rescheduled without duplicate lots
      expect(vm.lotes.length, equals(initialLoteCount));
      expect(vm.lotes.where((l) => l.id == targetLote.id).length, equals(1));
      expect(repo.lotes.length, equals(initialLoteCount));
      expect(repo.lotes.where((l) => l.id == targetLote.id).length, equals(1));
      expect(vm.sesionActiva, isNull);
    });

    test('TEST-R5-T1-05: ViewModel guardarLote mutex blocks concurrent call', () async {
      final repo = FakeOtsRepository(useSeedData: true);
      repo.simulateDelay = const Duration(milliseconds: 50);
      final vm = TableroViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.inicializar();

      final initialCount = vm.lotes.length;
      final existingLote = vm.lotes.first;
      final updatedLote1 = existingLote.copyWith(cantidadProductos: 120);
      final updatedLote2 = existingLote.copyWith(cantidadProductos: 150);

      // Launch two concurrent calls simultaneously
      final future1 = vm.guardarLote(updatedLote1);
      final future2 = vm.guardarLote(updatedLote2);

      await Future.wait([future1, future2]);

      // Assert mutex allowed exactly 1 write
      expect(repo.guardarLoteCallCount, equals(1), reason: 'Concurrent call blocked by _isSavingLote mutex');
      expect(vm.isSavingLote, isFalse);

      // Invariant: lot count must remain strictly unchanged; in-place upsert guarantees zero duplicate lots
      expect(vm.lotes.length, equals(initialCount));
      expect(vm.lotes.where((l) => l.id == existingLote.id).length, equals(1));
      expect(repo.lotes.length, equals(initialCount));
      expect(repo.lotes.where((l) => l.id == existingLote.id).length, equals(1));
    });
  });
}
