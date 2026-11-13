import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/data/repositories/ots_repository.dart';
import 'package:flutter_app/domain/models/lote.dart';
import 'package:flutter_app/domain/models/registro_trabajo.dart';
import 'package:flutter_app/ui/viewmodels/tablero_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalOtsRepository & TableroViewModel', () {
    test('Inicializa con datos semilla cuando el almacenamiento está vacío', () async {
      final repo = LocalOtsRepository();
      final lotes = await repo.obtenerLotes();

      expect(lotes.isNotEmpty, isTrue);
      expect(lotes.any((l) => l.supermercado == 'Carrefour San Martín'), isTrue);
    });

    test('Guardar un registro de trabajo reinicia el ciclo del lote a 120 días', () async {
      final repo = LocalOtsRepository();
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final primerLote = vm.lotes.firstWhere((l) => l.supermercado == 'Carrefour San Martín');
      final inicio = DateTime(2026, 11, 5, 10, 0);
      final fin = DateTime(2026, 11, 5, 10, 45);

      await vm.guardarSesionFotos(
        loteId: primerLote.id,
        supermercado: primerLote.supermercado,
        area: primerLote.area,
        cantidadProductos: 95,
        inicio: inicio,
        fin: fin,
      );

      expect(vm.registros.length, equals(1));
      expect(vm.registros.first.duracionMinutos, equals(45));

      final loteActualizado = vm.lotes.firstWhere((l) => l.id == primerLote.id);
      expect(loteActualizado.proximoDesbloqueo, isNotNull);
      // Debe estar reprogramado exactamente a 120 días desde el inicio (5 de marzo 2027)
      expect(loteActualizado.proximoDesbloqueo!.day, equals(5));
      expect(loteActualizado.proximoDesbloqueo!.month, equals(3));
      expect(loteActualizado.proximoDesbloqueo!.year, equals(2027));
    });

    test('Iniciar fotos activa la sesión y el cronómetro', () async {
      final repo = LocalOtsRepository();
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final lote = vm.lotes.first;
      await vm.iniciarFotos(lote);

      expect(vm.sesionActiva, isNotNull);
      expect(vm.sesionActiva!['loteId'], equals(lote.id));

      await vm.cancelarSesionActiva();
      expect(vm.sesionActiva, isNull);
    });

    test('Desbloquear lote anticipadamente lo pasa a habilitado de inmediato', () async {
      final repo = LocalOtsRepository();
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      // Tomar lote futuro
      final loteFuturo = vm.lotes.firstWhere((l) => l.supermercado == 'Disco Recoleta');
      await vm.desbloquearLoteAnticipadamente(loteFuturo);

      final actualizado = vm.lotes.firstWhere((l) => l.id == loteFuturo.id);
      expect(actualizado.proximoDesbloqueo, isNull);
      expect(vm.lotesHabilitados.any((l) => l.id == loteFuturo.id), isTrue);
    });

    test('TableroViewModel.guardarSesionFotos ejecuta guardarRegistro de forma atómica y no realiza guardarLote redundante', () async {
      final repo = _MinimalMockRepository();
      final vm = TableroViewModel(repository: repo);
      await vm.inicializar();

      final loteInicial = vm.lotes.first;
      expect(vm.lotesHabilitados.any((l) => l.id == loteInicial.id), isTrue);
      expect(vm.lotesFuturos.any((l) => l.id == loteInicial.id), isFalse);

      final ahora = DateTime.now();
      await vm.guardarSesionFotos(
        loteId: loteInicial.id,
        supermercado: 'Supermercado Editado',
        area: 'Area Editada',
        cantidadProductos: 120,
        inicio: ahora,
        fin: ahora.add(const Duration(minutes: 45)),
        observaciones: 'Sesión completada',
      );

      // Verificación de atomicidad y no-redundancia (R2)
      expect(repo.guardarRegistroCallCount, equals(1));
      expect(repo.guardarLoteCallCount, equals(0), reason: 'guardarLote no debe llamarse redundantemente');

      expect(vm.registros.length, equals(1));
      expect(vm.lotesHabilitados.any((l) => l.id == loteInicial.id), isFalse);
      expect(vm.lotesFuturos.any((l) => l.id == loteInicial.id), isTrue);

      final loteMovido = vm.lotesFuturos.firstWhere((l) => l.id == loteInicial.id);
      expect(loteMovido.supermercado, equals('Supermercado Editado'));
      expect(loteMovido.area, equals('Area Editada'));
      expect(loteMovido.cantidadProductos, equals(120));
      expect(loteMovido.proximoDesbloqueo, isNotNull);
    });
  });
}

/// Repositorio simulado que emula el comportamiento atómico de Firestore
/// donde guardarRegistro persiste atómicamente el registro y reprograma el lote asociado.
class _MinimalMockRepository implements OtsRepository {
  final List<Lote> _lotes = [
    Lote.crear(
      id: 'lote_test_1',
      supermercado: 'Coto Temperley',
      area: 'Bebidas',
      cantidadProductos: 80,
    ),
  ];
  final List<RegistroTrabajo> _registros = [];
  Map<String, dynamic>? _sesion;

  int guardarRegistroCallCount = 0;
  int guardarLoteCallCount = 0;

  @override
  Future<List<Lote>> obtenerLotes() async => List.unmodifiable(_lotes);

  @override
  Future<Lote> guardarLote(Lote lote) async {
    guardarLoteCallCount++;
    final idx = _lotes.indexWhere((l) => l.id == lote.id);
    if (idx >= 0) {
      _lotes[idx] = lote;
    } else {
      _lotes.add(lote);
    }
    return lote;
  }

  @override
  Future<void> eliminarLote(String id) async {
    _lotes.removeWhere((l) => l.id == id);
  }

  @override
  Future<List<RegistroTrabajo>> obtenerRegistros() async => List.unmodifiable(_registros);

  @override
  Future<RegistroTrabajo> guardarRegistro(RegistroTrabajo registro) async {
    guardarRegistroCallCount++;
    _registros.insert(0, registro);

    // Persistencia atómica de lote asociada al registro (contrato R2)
    final idx = _lotes.indexWhere((l) => l.id == registro.loteId);
    if (idx >= 0) {
      final loteActual = _lotes[idx];
      _lotes[idx] = loteActual.copyWith(
        supermercado: registro.supermercado,
        area: registro.area,
        ultimoInicio: registro.inicio,
        proximoDesbloqueo: registro.nuevoDesbloqueo,
        cantidadProductos: registro.cantidadProductos > 0
            ? registro.cantidadProductos
            : loteActual.cantidadProductos,
      );
    }
    return registro;
  }

  @override
  Future<void> guardarSesionActiva(Map<String, dynamic> sesion) async {
    _sesion = sesion;
  }

  @override
  Future<Map<String, dynamic>?> obtenerSesionActiva() async => _sesion;

  @override
  Future<void> limpiarSesionActiva() async {
    _sesion = null;
  }
}
