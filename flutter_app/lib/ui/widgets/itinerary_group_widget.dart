import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/models/lote.dart';
import 'lote_card_widget.dart';

class ItineraryGroupWidget extends StatelessWidget {
  final String fechaClave; // YYYY-MM-DD
  final List<Lote> lotes;
  final Function(Lote) onEditar;
  final Function(Lote) onEliminar;
  final Function(Lote) onVerDetalles;

  const ItineraryGroupWidget({
    super.key,
    required this.fechaClave,
    required this.lotes,
    required this.onEditar,
    required this.onEliminar,
    required this.onVerDetalles,
  });

  @override
  Widget build(BuildContext context) {
    final partes = fechaClave.split('-');
    final fecha = DateTime(
      int.parse(partes[0]),
      int.parse(partes[1]),
      int.parse(partes[2]),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado del día
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.lavenderContainer.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: const Border(
                bottom: BorderSide(color: AppColors.borderSubtle),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormatter.fechaGrupoItinerario(fecha),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ],
                ),
                Text(
                  DateFormatter.fechaCorta(fecha),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Lista de Lotes del Día
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: lotes.map((lote) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LoteCardWidget(
                    lote: lote,
                    onIniciarFotos: () {},
                    onTerminarFotos: () {},
                    onEditar: () => onEditar(lote),
                    onEliminar: () => onEliminar(lote),
                    onVerDetalles: () => onVerDetalles(lote),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
