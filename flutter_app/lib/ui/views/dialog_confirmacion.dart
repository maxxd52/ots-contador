import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class DialogConfirmacion extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final String textoAceptar;
  final String textoCancelar;
  final bool esPeligroso;
  final IconData icono;

  const DialogConfirmacion({
    super.key,
    required this.titulo,
    required this.mensaje,
    this.textoAceptar = 'Aceptar',
    this.textoCancelar = 'Cancelar',
    this.esPeligroso = false,
    this.icono = Icons.warning_amber_rounded,
  });

  static Future<bool> mostrar(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    String textoAceptar = 'Aceptar',
    String textoCancelar = 'Cancelar',
    bool esPeligroso = false,
    IconData icono = Icons.warning_amber_rounded,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogConfirmacion(
        titulo: titulo,
        mensaje: mensaje,
        textoAceptar: textoAceptar,
        textoCancelar: textoCancelar,
        esPeligroso: esPeligroso,
        icono: icono,
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surfaceCard,
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: esPeligroso ? AppColors.dangerContainer : AppColors.warningContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: esPeligroso ? AppColors.dangerBorder : AppColors.warningBorder,
              ),
            ),
            child: Icon(
              icono,
              size: 26,
              color: esPeligroso ? AppColors.dangerRed : AppColors.warningAmberDark,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(textoCancelar),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: esPeligroso ? AppColors.dangerRed : AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(textoAceptar),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
