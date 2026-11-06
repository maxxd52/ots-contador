import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/models/lote.dart';

class ModalLoteSheet extends StatefulWidget {
  final Lote? loteParaEditar;
  final Function(Lote) onGuardar;

  const ModalLoteSheet({
    super.key,
    this.loteParaEditar,
    required this.onGuardar,
  });

  @override
  State<ModalLoteSheet> createState() => _ModalLoteSheetState();
}

class _ModalLoteSheetState extends State<ModalLoteSheet> {
  late TextEditingController _supermercadoCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _productosCtrl;
  late TextEditingController _notasCtrl;

  DateTime? _ultimoInicio;

  @override
  void initState() {
    super.initState();
    final l = widget.loteParaEditar;
    _supermercadoCtrl = TextEditingController(text: l?.supermercado ?? '');
    _areaCtrl = TextEditingController(text: l?.area ?? '');
    _productosCtrl = TextEditingController(
      text: l != null && l.cantidadProductos > 0 ? '${l.cantidadProductos}' : '',
    );
    _notasCtrl = TextEditingController(text: l?.notas ?? '');
    _ultimoInicio = l?.ultimoInicio;
  }

  @override
  void dispose() {
    _supermercadoCtrl.dispose();
    _areaCtrl.dispose();
    _productosCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFechaInicio() async {
    final base = _ultimoInicio ?? DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _ultimoInicio = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.loteParaEditar != null;

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
                    Text(
                      esEdicion ? 'Modificar Lote' : 'Nuevo Lote de Supermercado',
                      style: const TextStyle(
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

            TextField(
              controller: _supermercadoCtrl,
              decoration: const InputDecoration(
                labelText: 'Supermercado *',
                hintText: 'Ej: Carrefour San Martín',
                prefixIcon: Icon(Icons.storefront, size: 20, color: AppColors.primaryPurple),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _areaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Área / Sector *',
                      hintText: 'Ej: Lácteos',
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
                      hintText: '100',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Último relevamiento (opcional si es nuevo)
            InkWell(
              onTap: _seleccionarFechaInicio,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Última Fecha/Hora de Fotos (Opcional)',
                  prefixIcon: const Icon(Icons.history, size: 20, color: AppColors.primaryPurple),
                  suffixIcon: _ultimoInicio != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _ultimoInicio = null),
                        )
                      : null,
                ),
                child: Text(
                  _ultimoInicio != null
                      ? DateFormatter.fechaHoraCompleta(_ultimoInicio!)
                      : 'Sin fotos previas (quedará habilitado de inmediato)',
                  style: TextStyle(
                    fontSize: 13,
                    color: _ultimoInicio != null ? AppColors.textPrimary : AppColors.textDim,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Si lo dejas vacío, el lote quedará habilitado de inmediato para fotografiar hoy.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textDim),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notasCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas del Sector (Opcional)',
                hintText: 'Ej: Góndola 3, pasillo central',
              ),
            ),
            const SizedBox(height: 18),

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

                      final lote = widget.loteParaEditar != null
                          ? widget.loteParaEditar!.copyWith(
                              supermercado: superName,
                              area: areaName,
                              cantidadProductos: int.tryParse(_productosCtrl.text) ?? 0,
                              ultimoInicio: _ultimoInicio,
                              resetUltimoInicio: _ultimoInicio == null,
                              resetDesbloqueo: _ultimoInicio == null,
                              notas: _notasCtrl.text,
                            )
                          : Lote.crear(
                              supermercado: superName,
                              area: areaName,
                              cantidadProductos: int.tryParse(_productosCtrl.text) ?? 0,
                              ultimoInicio: _ultimoInicio,
                              notas: _notasCtrl.text,
                            );

                      widget.onGuardar(lote);
                      Navigator.of(context).pop();
                    },
                    child: Text(esEdicion ? 'Guardar Cambios' : 'Crear Lote'),
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
