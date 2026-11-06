import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/models/lote.dart';

class ModalDetalleLoteSheet extends StatelessWidget {
  final Lote lote;
  final VoidCallback onHabilitarHoy;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const ModalDetalleLoteSheet({
    super.key,
    required this.lote,
    required this.onHabilitarHoy,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        lote.supermercado,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Text(
                  lote.area,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryPurple,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),

          // Tarjeta de Cuenta Regresiva
          if (lote.proximoDesbloqueo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lavenderContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.lavenderBorder),
              ),
              child: Column(
                children: [
                  const Text(
                    'TIEMPO RESTANTE PARA DESBLOQUEO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDim,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormatter.cuentaRegresiva(lote.proximoDesbloqueo!),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Se habilita el ${DateFormatter.fechaHoraCompleta(lote.proximoDesbloqueo!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // Información adicional
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInput,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CANTIDAD', style: TextStyle(fontSize: 10, color: AppColors.textDim, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        lote.cantidadProductos > 0 ? '${lote.cantidadProductos} productos' : 'No especificada',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInput,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ÚLTIMAS FOTOS', style: TextStyle(fontSize: 10, color: AppColors.textDim, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        lote.ultimoInicio != null ? DateFormatter.fechaCorta(lote.ultimoInicio!) : 'Sin registro',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (lote.notas != null && lote.notas!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceInput,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NOTAS DEL SECTOR', style: TextStyle(fontSize: 10, color: AppColors.textDim, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    lote.notas!,
                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Botón destacado: Habilitar / Desbloquear Hoy
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.bolt, size: 20),
              label: const Text('⚡ Habilitar / Desbloquear Hoy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onHabilitarHoy();
              },
            ),
          ),
          const SizedBox(height: 10),

          // Botones secundarios
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modificar'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onEditar();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.dangerRed),
                  label: const Text('Eliminar', style: TextStyle(color: AppColors.dangerRed)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.dangerBorder),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onEliminar();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  ),
),
);
  }
}
