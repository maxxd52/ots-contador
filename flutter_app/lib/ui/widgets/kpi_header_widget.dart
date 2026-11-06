import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class KpiHeaderWidget extends StatelessWidget {
  final String horasHoy;
  final int listosHoy;
  final int proximos7d;

  const KpiHeaderWidget({
    super.key,
    required this.horasHoy,
    required this.listosHoy,
    required this.proximos7d,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            context,
            label: 'HORAS HOY',
            value: horasHoy,
            valueColor: AppColors.primaryPurple,
            icon: Icons.timer_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            context,
            label: 'LISTOS HOY',
            value: '$listosHoy',
            valueColor: AppColors.primaryGreen,
            icon: Icons.camera_alt_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            context,
            label: 'PRÓXIMOS 7D',
            value: '$proximos7d',
            valueColor: AppColors.upcomingBlue,
            icon: Icons.calendar_month_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDim,
                  letterSpacing: 0.4,
                ),
              ),
              Icon(icon, size: 13, color: AppColors.textDim),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
