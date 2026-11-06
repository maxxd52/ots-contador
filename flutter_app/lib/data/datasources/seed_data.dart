import '../../domain/models/lote.dart';

abstract class SeedData {
  static List<Lote> obtenerLotesIniciales([DateTime? referencia]) {
    final ahora = referencia ?? DateTime.now();

    return [
      Lote(
        id: 'lote_seed_1',
        supermercado: 'Carrefour San Martín',
        area: 'Lácteos y Yogures',
        cantidadProductos: 95,
        ultimoInicio: ahora.subtract(const Duration(days: 120, hours: 2)),
        proximoDesbloqueo: ahora.subtract(const Duration(hours: 2)), // Desbloqueado hoy
        notas: 'Revisar góndola central y heladeras de yogures firmes.',
        creadoEn: ahora.subtract(const Duration(days: 120)),
      ),
      Lote(
        id: 'lote_seed_2',
        supermercado: 'Jumbo Palermo',
        area: 'Bebidas sin Alcohol y Aguas',
        cantidadProductos: 110,
        ultimoInicio: ahora.subtract(const Duration(days: 118)),
        proximoDesbloqueo: ahora.add(const Duration(days: 2)), // Próximo en 2 días
        notas: 'Sector aguas saborizadas y gaseosas línea cola.',
        creadoEn: ahora.subtract(const Duration(days: 118)),
      ),
      Lote(
        id: 'lote_seed_3',
        supermercado: 'Coto Belgrano',
        area: 'Perfumería y Cuidado Personal',
        cantidadProductos: 140,
        ultimoInicio: ahora.subtract(const Duration(days: 122)),
        proximoDesbloqueo: ahora.subtract(const Duration(days: 2)), // Acumulado hace 2 días
        notas: 'Pasillos 4 y 5. Prioridad higiene oral.',
        creadoEn: ahora.subtract(const Duration(days: 122)),
      ),
      Lote(
        id: 'lote_seed_4',
        supermercado: 'Disco Recoleta',
        area: 'Limpieza y Hogar',
        cantidadProductos: 80,
        ultimoInicio: ahora.subtract(const Duration(days: 90)),
        proximoDesbloqueo: ahora.add(const Duration(days: 30)), // Futuro a 30 días
        notas: 'Detergentes y lavavajillas.',
        creadoEn: ahora.subtract(const Duration(days: 90)),
      ),
      Lote(
        id: 'lote_seed_5',
        supermercado: 'Día Villa Urquiza',
        area: 'Galletitas y Snacks',
        cantidadProductos: 120,
        ultimoInicio: null,
        proximoDesbloqueo: null, // Nuevo -> Listo inmediatamente
        notas: 'Lote recién asignado sin relevamiento fotográfico anterior.',
        creadoEn: ahora,
      ),
    ];
  }
}
