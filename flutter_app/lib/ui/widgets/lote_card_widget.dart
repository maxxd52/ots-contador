import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/logic/time_calculator.dart';
import '../../domain/models/estado_lote.dart';
import '../../domain/models/lote.dart';

class LoteCardWidget extends StatelessWidget {
  final Lote lote;
  final bool esSesionActiva;
  final String? cronometroTexto;
  final VoidCallback onIniciarFotos;
  final VoidCallback onTerminarFotos;
  final VoidCallback? onDescartarSesion;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback? onVerDetalles;

  const LoteCardWidget({
    super.key,
    required this.lote,
    this.esSesionActiva = false,
    this.cronometroTexto,
    required this.onIniciarFotos,
    required this.onTerminarFotos,
    this.onDescartarSesion,
    required this.onEditar,
    required this.onEliminar,
    this.onVerDetalles,
  });

  @override
  Widget build(BuildContext context) {
    final estado = TimeCalculator.clasificarEstadoLote(
      proximoDesbloqueo: lote.proximoDesbloqueo,
      esSesionActiva: esSesionActiva,
    );

    Color leftBorderColor;
    if (esSesionActiva) {
      leftBorderColor = AppColors.dangerRed;
    } else if (estado.esAcumulado) {
      leftBorderColor = AppColors.warningAmber;
    } else if (estado.tipo == TipoEstadoLote.habilitado) {
      leftBorderColor = AppColors.primaryGreen;
    } else if (estado.tipo == TipoEstadoLote.proximo7Dias) {
      leftBorderColor = AppColors.upcomingBlue;
    } else {
      leftBorderColor = AppColors.textDim;
    }

    return InkWell(
      onTap: onVerDetalles,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: esSesionActiva
                ? AppColors.dangerRed.withValues(alpha: 0.5)
                : AppColors.borderSubtle,
            width: esSesionActiva ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: leftBorderColor.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra lateral indicadora de estado
              Container(
                width: 5,
                color: leftBorderColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabecera de la tarjeta: Título + Badge + Acciones
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lote.supermercado,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: AppColors.primaryPurple,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        lote.area,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryPurple,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildBadge(estado),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: AppColors.textSecondary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: onEditar,
                            tooltip: 'Editar lote',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: AppColors.textSecondary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: onEliminar,
                            tooltip: 'Eliminar lote',
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Metadata: Productos + Horario de desbloqueo
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          if (lote.cantidadProductos > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 13, color: AppColors.textDim),
                                const SizedBox(width: 4),
                                Text(
                                  '${lote.cantidadProductos} productos',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          if (lote.proximoDesbloqueo != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  estado.tipo == TipoEstadoLote.habilitado
                                      ? Icons.lock_open_outlined
                                      : Icons.lock_clock_outlined,
                                  size: 13,
                                  color: leftBorderColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  estado.tipo == TipoEstadoLote.habilitado
                                      ? 'Desbloqueado a las ${DateFormatter.horaMinutos(lote.proximoDesbloqueo!)}'
                                      : '${DateFormatter.fechaCorta(lote.proximoDesbloqueo!)} a las ${DateFormatter.horaMinutos(lote.proximoDesbloqueo!)} (${DateFormatter.cuentaRegresiva(lote.proximoDesbloqueo!)})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: leftBorderColor,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                      if (lote.notas != null && lote.notas!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '"${lote.notas}"',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],

                      // Botón Dinámico de 1 Toque
                      if (estado.tipo == TipoEstadoLote.habilitado || esSesionActiva) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: esSesionActiva
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.stop_circle, size: 18),
                                        label: Text('⏹ Terminar Fotos (${cronometroTexto ?? "00:00"})'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.dangerRed,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: onTerminarFotos,
                                      ),
                                    ),
                                    if (onDescartarSesion != null) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 20),
                                        tooltip: 'Descartar cronómetro',
                                        style: IconButton.styleFrom(
                                          backgroundColor: AppColors.dangerContainer,
                                          foregroundColor: AppColors.dangerRed,
                                          padding: const EdgeInsets.all(12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: const BorderSide(color: AppColors.dangerBorder),
                                          ),
                                        ),
                                        onPressed: onDescartarSesion,
                                      ),
                                    ],
                                  ],
                                )
                              : ElevatedButton.icon(
                                  icon: const Icon(Icons.play_circle_filled, size: 18),
                                  label: const Text('▶ Iniciar Fotos'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: onIniciarFotos,
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(EstadoLoteInfo estado) {
    Color bg;
    Color border;
    Color text;

    if (esSesionActiva) {
      bg = AppColors.dangerContainer;
      border = AppColors.dangerBorder;
      text = AppColors.dangerRedDark;
    } else if (estado.esAcumulado) {
      bg = AppColors.warningContainer;
      border = AppColors.warningBorder;
      text = AppColors.warningAmberDark;
    } else if (estado.tipo == TipoEstadoLote.habilitado) {
      bg = AppColors.primaryGreenLight;
      border = AppColors.primaryGreen.withValues(alpha: 0.3);
      text = AppColors.primaryGreenDark;
    } else if (estado.tipo == TipoEstadoLote.proximo7Dias) {
      bg = AppColors.upcomingContainer;
      border = AppColors.upcomingBorder;
      text = AppColors.upcomingBlue;
    } else {
      bg = AppColors.lavenderContainer;
      border = AppColors.lavenderBorder;
      text = AppColors.primaryPurple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        estado.etiqueta,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
