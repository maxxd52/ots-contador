import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/logic/time_calculator.dart';
import '../../domain/models/lote.dart';

class ModalSesionSheet extends StatefulWidget {
  final Lote lote;
  final DateTime inicio;
  final DateTime? fin;
  final Function({
    required String loteId,
    required String supermercado,
    required String area,
    required int cantidadProductos,
    required DateTime inicio,
    required DateTime fin,
    String? observaciones,
  }) onGuardar;

  const ModalSesionSheet({
    super.key,
    required this.lote,
    required this.inicio,
    this.fin,
    required this.onGuardar,
  });

  @override
  State<ModalSesionSheet> createState() => _ModalSesionSheetState();
}

class _ModalSesionSheetState extends State<ModalSesionSheet> {
  late TextEditingController _supermercadoCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _productosCtrl;
  late TextEditingController _observacionesCtrl;

  late DateTime _inicio;
  late DateTime _fin;

  @override
  void initState() {
    super.initState();
    _supermercadoCtrl = TextEditingController(text: widget.lote.supermercado);
    _areaCtrl = TextEditingController(text: widget.lote.area);
    _productosCtrl = TextEditingController(
      text: widget.lote.cantidadProductos > 0 ? '${widget.lote.cantidadProductos}' : '',
    );
    _observacionesCtrl = TextEditingController();

    _inicio = widget.inicio;
    _fin = widget.fin ?? DateTime.now();
    if (_fin.isBefore(_inicio)) {
      _fin = _inicio.add(const Duration(minutes: 45));
    }
  }

  @override
  void dispose() {
    _supermercadoCtrl.dispose();
    _areaCtrl.dispose();
    _productosCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  void _aplicarDuracionRapida(int minutos) {
    setState(() {
      _fin = _inicio.add(Duration(minutes: minutos));
    });
  }

  Future<void> _seleccionarFechaHora(bool esInicio) async {
    final fechaBase = esInicio ? _inicio : _fin;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: fechaBase,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(fechaBase),
    );
    if (pickedTime == null || !mounted) return;

    final result = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (esInicio) {
        _inicio = result;
        if (_fin.isBefore(_inicio)) {
          _fin = _inicio.add(const Duration(minutes: 30));
        }
      } else {
        _fin = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final duracion = TimeCalculator.calcularHorasTrabajadas(_inicio, _fin);
    final proximoDesbloqueo = TimeCalculator.calcularProximoDesbloqueo(_inicio);

    return Dialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
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
                    const Text(
                      'Registrar Sesión de Fotos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),

            // Supermercado
            TextField(
              controller: _supermercadoCtrl,
              decoration: const InputDecoration(
                labelText: 'Supermercado *',
                prefixIcon: Icon(Icons.storefront, size: 20, color: AppColors.primaryPurple),
              ),
            ),
            const SizedBox(height: 12),

            // Área y Cantidad
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _areaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Área / Sector *',
                      prefixIcon: Icon(Icons.category_outlined, size: 18, color: AppColors.primaryPurple),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _productosCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cant. Prods',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Selectores de Inicio y Fin
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _seleccionarFechaHora(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha y Hora Inicio *',
                        prefixIcon: Icon(Icons.play_arrow, size: 18, color: AppColors.primaryGreen),
                      ),
                      child: Text(
                        DateFormatter.fechaHoraCompleta(_inicio),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _seleccionarFechaHora(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha y Hora Fin *',
                        prefixIcon: Icon(Icons.stop, size: 18, color: AppColors.dangerRed),
                      ),
                      child: Text(
                        DateFormatter.fechaHoraCompleta(_fin),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Duración Rápida: 4 chips iguales
            const Text(
              'Duración rápida:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildQuickChip(minutos: 30, label: '+30 min'),
                const SizedBox(width: 6),
                _buildQuickChip(minutos: 45, label: '+45 min'),
                const SizedBox(width: 6),
                _buildQuickChip(minutos: 60, label: '+1 hora'),
                const SizedBox(width: 6),
                _buildQuickChip(minutos: 90, label: '+1.5 h'),
              ],
            ),
            const SizedBox(height: 14),

            // Caja de Cálculo en Vivo & Próximo Desbloqueo a 120 días
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lavenderContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.lavenderBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 16, color: AppColors.primaryPurple),
                          SizedBox(width: 6),
                          Text(
                            'Tiempo trabajado:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      Text(
                        duracion.texto,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: AppColors.lavenderBorder),
                  const SizedBox(height: 10),

                  // Tarjeta destacada de desbloqueo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.lavenderBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.lock_clock, size: 15, color: AppColors.primaryPurple),
                                SizedBox(width: 4),
                                Text(
                                  'Próximo desbloqueo:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.lavenderContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '+120 días exactos',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormatter.fechaHoraCompleta(proximoDesbloqueo),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryPurple,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'El lote volverá a estar disponible exactamente a la misma hora del inicio.',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Observaciones
            TextField(
              controller: _observacionesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observaciones / Novedades (Opcional)',
                hintText: 'Faltantes de stock, fotos especiales, etc.',
              ),
            ),
            const SizedBox(height: 16),

            // Acciones del Modal
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final superName = _supermercadoCtrl.text.trim();
                      final areaName = _areaCtrl.text.trim();
                      if (superName.isEmpty || areaName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Supermercado y Área son obligatorios.')),
                        );
                        return;
                      }

                      widget.onGuardar(
                        loteId: widget.lote.id,
                        supermercado: superName,
                        area: areaName,
                        cantidadProductos: int.tryParse(_productosCtrl.text) ?? 0,
                        inicio: _inicio,
                        fin: _fin,
                        observaciones: _observacionesCtrl.text,
                      );
                      Navigator.of(context).pop();
                    },
                    child: const Text('Guardar y Reprogramar'),
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

  Widget _buildQuickChip({required int minutos, required String label}) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          side: const BorderSide(color: AppColors.borderSubtle),
          backgroundColor: AppColors.surfaceInput,
        ),
        onPressed: () => _aplicarDuracionRapida(minutos),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryPurple),
        ),
      ),
    );
  }
}
