import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/models/lote.dart';
import '../viewmodels/tablero_viewmodel.dart';
import '../widgets/itinerary_group_widget.dart';
import '../widgets/kpi_header_widget.dart';
import '../widgets/lote_card_widget.dart';
import 'dialog_confirmacion.dart';
import 'modal_detalle_lote_sheet.dart';
import 'modal_lote_sheet.dart';
import 'modal_sesion_sheet.dart';

class HomeScreen extends StatefulWidget {
  final TableroViewModel viewModel;

  const HomeScreen({super.key, required this.viewModel});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _mostrarFuturos = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _abrirModalNuevoLote({Lote? loteParaEditar}) {
    showDialog(
      context: context,
      builder: (ctx) => ModalLoteSheet(
        loteParaEditar: loteParaEditar,
        onGuardar: (lote) async {
          await widget.viewModel.guardarLote(lote);
        },
      ),
    );
  }

  void _abrirModalTerminarSesion(Lote lote) {
    final sesion = widget.viewModel.sesionActiva;
    DateTime inicio = DateTime.now();
    if (sesion != null && sesion['loteId'] == lote.id) {
      inicio = DateTime.parse(sesion['inicio'] as String);
    }

    showDialog(
      context: context,
      builder: (ctx) => ModalSesionSheet(
        lote: lote,
        inicio: inicio,
        fin: DateTime.now(),
        onGuardar: ({
          required loteId,
          required supermercado,
          required area,
          required cantidadProductos,
          required inicio,
          required fin,
          observaciones,
        }) async {
          await widget.viewModel.guardarSesionFotos(
            loteId: loteId,
            supermercado: supermercado,
            area: area,
            cantidadProductos: cantidadProductos,
            inicio: inicio,
            fin: fin,
            observaciones: observaciones,
          );
        },
      ),
    );
  }

  void _abrirModalDetalles(Lote lote) {
    showDialog(
      context: context,
      builder: (ctx) => ModalDetalleLoteSheet(
        lote: lote,
        onHabilitarHoy: () async {
          await widget.viewModel.desbloquearLoteAnticipadamente(lote);
        },
        onEditar: () => _abrirModalNuevoLote(loteParaEditar: lote),
        onEliminar: () => _confirmarEliminarLote(lote),
      ),
    );
  }

  Future<void> _confirmarEliminarLote(Lote lote) async {
    final confirmado = await DialogConfirmacion.mostrar(
      context,
      titulo: '¿Eliminar Lote?',
      mensaje: '¿Estás seguro de eliminar "${lote.supermercado} - ${lote.area}"? Se perderán sus fechas asociadas.',
      textoAceptar: 'Eliminar',
      esPeligroso: true,
      icono: Icons.delete_forever,
    );

    if (confirmado) {
      await widget.viewModel.eliminarLote(lote.id);
    }
  }

  Future<void> _confirmarDescartarSesion(Lote lote) async {
    final confirmado = await DialogConfirmacion.mostrar(
      context,
      titulo: '¿Descartar sesión en curso?',
      mensaje: 'Se cancelará el cronómetro sin registrar las horas trabajadas.',
      textoAceptar: 'Descartar',
      esPeligroso: true,
      icono: Icons.warning_amber_rounded,
    );

    if (confirmado) {
      await widget.viewModel.cancelarSesionActiva();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;

        return Scaffold(
          backgroundColor: AppColors.desktopBackdrop,
          body: vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 580;

                    final appContent = Container(
                      color: AppColors.scaffoldBackground,
                      child: Column(
                        children: [
                          // Cabecera Púrpura Curvada Integrada
                          Container(
                            decoration: const BoxDecoration(
                              color: AppColors.primaryPurple,
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x2A612680),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              (isDesktop ? 16.0 : MediaQuery.of(context).padding.top + 10),
                              16,
                              16,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.camera_alt, size: 22, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text(
                                          'OTS 120 Días',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 19,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    FilledButton.icon(
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Lote'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primaryGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: () => _abrirModalNuevoLote(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                KpiHeaderWidget(
                                  horasHoy: vm.kpiHorasHoy,
                                  listosHoy: vm.kpiListosHoy,
                                  proximos7d: vm.kpiProximos7d,
                                ),
                              ],
                            ),
                          ),

                          // Selector de Pestañas M3
                          Container(
                            color: AppColors.surfaceCard,
                            child: TabBar(
                              controller: _tabController,
                              labelColor: AppColors.primaryPurple,
                              unselectedLabelColor: AppColors.textDim,
                              indicatorColor: AppColors.primaryPurple,
                              indicatorWeight: 3,
                              tabs: const [
                                Tab(
                                  icon: Icon(Icons.assignment_outlined, size: 18),
                                  text: 'Tablero & Itinerario',
                                ),
                                Tab(
                                  icon: Icon(Icons.history_outlined, size: 18),
                                  text: 'Historial & Horas',
                                ),
                              ],
                            ),
                          ),

                          // Contenido de las pestañas
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildTableroTab(vm),
                                _buildHistorialTab(vm),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                    if (!isDesktop) {
                      return appContent;
                    }

                    // En pantallas de escritorio: marco de aplicación centrado
                    return Center(
                      child: Container(
                        width: 500,
                        margin: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBackground,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryPurple.withValues(alpha: 0.12),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: appContent,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildTableroTab(TableroViewModel vm) {
    final listos = vm.lotesHabilitados;
    final itinerario = vm.itinerarioProximos7Dias;
    final futuros = vm.lotesFuturos;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // SECCIÓN 1: Listos para Fotografiar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Listos para Fotografiar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryGreenLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${listos.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreenDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Lotes cuyo ciclo de 120 días ya se cumplió. Listos para iniciar fotos hoy.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        if (listos.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Center(
              child: Text(
                '🎉 No hay lotes pendientes para hoy.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          ...listos.map((lote) {
            final esActivo = vm.sesionActiva != null && vm.sesionActiva!['loteId'] == lote.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LoteCardWidget(
                lote: lote,
                esSesionActiva: esActivo,
                cronometroTexto: vm.cronometroTexto,
                onIniciarFotos: () => vm.iniciarFotos(lote),
                onTerminarFotos: () => _abrirModalTerminarSesion(lote),
                onDescartarSesion: () => _confirmarDescartarSesion(lote),
                onEditar: () => _abrirModalNuevoLote(loteParaEditar: lote),
                onEliminar: () => _confirmarEliminarLote(lote),
                onVerDetalles: () => _abrirModalDetalles(lote),
              ),
            );
          }),

        const SizedBox(height: 18),

        // SECCIÓN 2: Itinerario Próximos 7 Días
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.upcomingBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Itinerario Próximos 7 Días',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.upcomingContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${vm.kpiProximos7d}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.upcomingBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Lotes que se desbloquearán durante la próxima semana con su hora exacta.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        if (itinerario.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Center(
              child: Text(
                'No hay lotes programados para los siguientes 7 días.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          ...itinerario.entries.map((entry) {
            return ItineraryGroupWidget(
              fechaClave: entry.key,
              lotes: entry.value,
              onEditar: (l) => _abrirModalNuevoLote(loteParaEditar: l),
              onEliminar: (l) => _confirmarEliminarLote(l),
              onVerDetalles: (l) => _abrirModalDetalles(l),
            );
          }),

        const SizedBox(height: 14),

        // SECCIÓN 3: Lotes Futuros (>7 días) Colapsable
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              'Lotes Futuros (> 7 días) (${futuros.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            initiallyExpanded: _mostrarFuturos,
            onExpansionChanged: (v) => setState(() => _mostrarFuturos = v),
            children: [
              if (futuros.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No hay lotes en el horizonte lejano.', style: TextStyle(color: AppColors.textDim)),
                )
              else
                ...futuros.map((lote) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LoteCardWidget(
                      lote: lote,
                      onIniciarFotos: () {},
                      onTerminarFotos: () {},
                      onEditar: () => _abrirModalNuevoLote(loteParaEditar: lote),
                      onEliminar: () => _confirmarEliminarLote(lote),
                      onVerDetalles: () => _abrirModalDetalles(lote),
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHistorialTab(TableroViewModel vm) {
    final registros = vm.registros;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'Historial de Sesiones Fotográficas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Registro de horas y auditorías fotográficas realizadas.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),

        if (registros.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Center(
              child: Text(
                'Aún no hay sesiones registradas.\nInicia y completa una sesión para acumular tus horas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
            ),
          )
        else
          ...registros.map((reg) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reg.supermercado,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${reg.area} • ${reg.cantidadProductos} productos',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormatter.fechaHoraCompleta(reg.inicio),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.lavenderContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      reg.duracionTexto,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
