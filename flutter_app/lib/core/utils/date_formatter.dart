abstract class DateFormatter {
  static const List<String> _diasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo'
  ];

  static const List<String> _meses = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic'
  ];

  static String nombreDia(DateTime fecha) {
    return _diasSemana[fecha.weekday - 1];
  }

  static String fechaCorta(DateTime fecha) {
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    return '$d/$m/${fecha.year}';
  }

  static String horaMinutos(DateTime fecha) {
    final h = fecha.hour.toString().padLeft(2, '0');
    final m = fecha.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String fechaHoraCompleta(DateTime fecha) {
    return '${fechaCorta(fecha)} ${horaMinutos(fecha)}';
  }

  static String fechaGrupoItinerario(DateTime fecha) {
    final d = fecha.day.toString().padLeft(2, '0');
    final mes = _meses[fecha.month - 1];
    return '${nombreDia(fecha)}, $d $mes';
  }

  static String cuentaRegresiva(DateTime fechaFutura, [DateTime? ahora]) {
    final ref = ahora ?? DateTime.now();
    final diff = fechaFutura.difference(ref);
    if (diff.isNegative) return 'Habilitado';

    final dias = diff.inDays;
    final horas = diff.inHours % 24;
    final minutos = diff.inMinutes % 60;

    if (dias > 0) {
      return 'en ${dias}d ${horas}h';
    }
    if (horas > 0) {
      return 'en ${horas}h ${minutos}m';
    }
    return 'en ${minutos}m';
  }
}
