enum TipoEstadoLote {
  habilitado,
  enCurso,
  proximo7Dias,
  futuro,
}

class EstadoLoteInfo {
  final TipoEstadoLote tipo;
  final bool esAcumulado;
  final String etiqueta;
  final String descripcion;
  final int? diasFaltantes;
  final int? horasFaltantes;

  const EstadoLoteInfo({
    required this.tipo,
    this.esAcumulado = false,
    required this.etiqueta,
    required this.descripcion,
    this.diasFaltantes,
    this.horasFaltantes,
  });
}
