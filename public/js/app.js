/**
 * Controlador Principal de la Aplicación: OTS 120 Días
 * Flujo simplificado: Cronómetro de 1 toque (Iniciar -> En Curso -> Terminar),
 * Gestión completa (Editar y Eliminar) y Ficha interactiva de lotes futuros.
 */

import { getStorage } from './storage/index.js';
import { CONFIG } from './config.js';
import {
  clasificarEstadoLote,
  calcularProximoDesbloqueo,
  calcularHorasTrabajadas,
  aInputDateTimeLocal,
  formatearFechaHora,
  formatearFechaCorta,
  formatearHora,
  formatearCronometro,
  obtenerNombreDia,
  claveDia,
  esMismoDia,
  ESTADOS
} from './domain/time.js';

class AppController {
  constructor() {
    this.storage = getStorage();
    this.lotes = [];
    this.registros = [];
    this.sesionActiva = null; // { loteId, supermercado, area, cantidadProductos, fechaHoraInicio }
    this.tabActiva = 'tablero';
    this.loteSeleccionadoDetalle = null;

    this._intervaloTicker = null;
    this._intervaloSegundo = null;
  }

  async iniciar() {
    this._vincularElementosUI();
    this._vincularEventos();

    // Recuperar sesión activa persistida si existe (resiste recargas de navegador)
    this.sesionActiva = await this.storage.obtenerSesionActiva();
    if (this.sesionActiva) {
      this._iniciarTickerSegundo();
    }

    await this.cargarDatos();

    // Actualizar tiempos relativos cada 60 segundos
    this._intervaloTicker = setInterval(() => {
      this.renderizar();
    }, 60000);
  }

  _vincularElementosUI() {
    // Tabs
    this.tabBtns = document.querySelectorAll('.tab-btn');
    this.viewTablero = document.getElementById('view-tablero');
    this.viewHistorial = document.getElementById('view-historial');

    // Stats
    this.statHorasHoy = document.getElementById('stat-horas-hoy');
    this.statListos = document.getElementById('stat-listos');
    this.statProximos = document.getElementById('stat-proximos');

    // Contenedores
    this.listaListos = document.getElementById('lista-listos');
    this.listaProximos = document.getElementById('lista-proximos');
    this.listaFuturos = document.getElementById('lista-futuros');
    this.listaHistorial = document.getElementById('lista-historial');

    // Badges de conteo
    this.badgeCountListos = document.getElementById('badge-count-listos');
    this.badgeCountProximos = document.getElementById('badge-count-proximos');
    this.badgeCountFuturos = document.getElementById('badge-count-futuros');
    this.badgeCountHistorial = document.getElementById('badge-count-historial');

    // Banner acumulados
    this.bannerAcumulados = document.getElementById('banner-acumulados');
    this.bannerAcumuladosDesc = document.getElementById('banner-acumulados-desc');

    // Resumen de horas
    this.horasSemana = document.getElementById('horas-semana');
    this.horasMes = document.getElementById('horas-mes');
    this.horasMesNombre = document.getElementById('horas-mes-nombre');

    // Modales
    this.modalSesion = document.getElementById('modal-sesion');
    this.formSesion = document.getElementById('form-sesion');
    this.modalLote = document.getElementById('modal-lote');
    this.formLote = document.getElementById('form-lote');
    this.modalLoteTitulo = document.getElementById('modal-lote-titulo');
    this.modalDetalleLote = document.getElementById('modal-detalle-lote');

    // Datalists para autocompletar
    this.datalistSupermercados = document.getElementById('datalist-supermercados');
    this.datalistAreas = document.getElementById('datalist-areas');

    // Campos modal sesión
    this.inputSesionLoteId = document.getElementById('sesion-lote-id');
    this.inputSesionSupermercado = document.getElementById('sesion-supermercado');
    this.inputSesionArea = document.getElementById('sesion-area');
    this.inputSesionProductos = document.getElementById('sesion-productos');
    this.inputSesionInicio = document.getElementById('sesion-inicio');
    this.inputSesionFin = document.getElementById('sesion-fin');
    this.inputSesionObs = document.getElementById('sesion-observaciones');
    this.calcTiempoTrabajado = document.getElementById('calc-tiempo-trabajado');
    this.calcDesbloqueoPreview = document.getElementById('calc-desbloqueo-preview');

    // Elementos Ficha Detalle
    this.detalleTitulo = document.getElementById('detalle-titulo');
    this.detalleSubtitulo = document.getElementById('detalle-subtitulo');
    this.detalleCountdownValor = document.getElementById('detalle-countdown-valor');
    this.detalleFechaExacta = document.getElementById('detalle-fecha-exacta');
    this.detalleSupermercado = document.getElementById('detalle-supermercado');
    this.detalleArea = document.getElementById('detalle-area');
    this.detalleProductos = document.getElementById('detalle-productos');
    this.detalleUltimaDuracion = document.getElementById('detalle-ultima-duracion');
    this.detalleNotasWrapper = document.getElementById('detalle-notas-wrapper');
    this.detalleNotasTexto = document.getElementById('detalle-notas-texto');
    this.btnAdelantarLote = document.getElementById('btn-adelantar-lote');
    this.btnEditarDesdeDetalle = document.getElementById('btn-editar-desde-detalle');
    this.btnEliminarDesdeDetalle = document.getElementById('btn-eliminar-desde-detalle');

    // Botón superior único
    this.btnNuevoLote = document.getElementById('btn-nuevo-lote');

    // Modal confirmación estilizado
    this.modalConfirmacion = document.getElementById('modal-confirmacion');
    this.confirmIcono = document.getElementById('confirm-icono');
    this.confirmIconBox = document.querySelector('.confirm-icon-box');
    this.confirmTitulo = document.getElementById('confirm-titulo');
    this.confirmMensaje = document.getElementById('confirm-mensaje');
    this.btnConfirmAceptar = document.getElementById('btn-confirm-aceptar');
    this.btnConfirmCancelar = document.getElementById('btn-confirm-cancelar');
  }

  _vincularEventos() {
    // Cambio de pestañas
    this.tabBtns.forEach(btn => {
      btn.addEventListener('click', (e) => {
        const tab = e.currentTarget.dataset.tab;
        this.cambiarPestana(tab);
      });
    });

    // Abrir modal nuevo lote
    this.btnNuevoLote.addEventListener('click', () => this.abrirModalLote());

    // Cerrar modales
    document.getElementById('btn-cerrar-modal-sesion').addEventListener('click', () => this.cerrarModales());
    document.getElementById('btn-cancelar-sesion').addEventListener('click', () => this.cerrarModales());
    document.getElementById('btn-cerrar-modal-lote').addEventListener('click', () => this.cerrarModales());
    document.getElementById('btn-cancelar-lote').addEventListener('click', () => this.cerrarModales());
    document.getElementById('btn-cerrar-modal-detalle').addEventListener('click', () => this.cerrarModales());

    // Cerrar al hacer clic en el backdrop (fuera de la tarjeta)
    [this.modalSesion, this.modalLote, this.modalDetalleLote].forEach(overlay => {
      overlay.addEventListener('click', (e) => {
        if (e.target === overlay) {
          this.cerrarModales();
        }
      });
    });

    // Acciones dentro de Ficha Detallada
    this.btnAdelantarLote.addEventListener('click', () => this.adelantarLoteSeleccionado());
    this.btnEditarDesdeDetalle.addEventListener('click', () => {
      const lote = this.loteSeleccionadoDetalle;
      this.cerrarModales();
      if (lote) this.abrirModalLote(lote.id);
    });
    this.btnEliminarDesdeDetalle.addEventListener('click', () => {
      const lote = this.loteSeleccionadoDetalle;
      if (lote) this.eliminarLote(lote.id);
    });

    // Submits
    this.formSesion.addEventListener('submit', (e) => this.guardarSesion(e));
    this.formLote.addEventListener('submit', (e) => this.guardarLote(e));

    // Cálculo en vivo
    this.inputSesionInicio.addEventListener('input', () => this.actualizarCalculoEnVivo());
    this.inputSesionFin.addEventListener('input', () => this.actualizarCalculoEnVivo());

    // Chips duración rápida
    document.querySelectorAll('.btn-chip').forEach(chip => {
      chip.addEventListener('click', (e) => {
        const minutos = parseInt(e.currentTarget.dataset.minutos, 10);
        this.aplicarDuracionRapida(minutos);
      });
    });
  }

  _bloquearScroll() {
    document.body.classList.add('modal-open');
  }

  _desbloquearScroll() {
    setTimeout(() => {
      const algunModalAbierto = document.querySelector('.modal-overlay:not(.oculto)');
      if (!algunModalAbierto) {
        document.body.classList.remove('modal-open');
      }
    }, 50);
  }

  mostrarConfirmacion({ titulo, mensaje, textoAceptar = 'Eliminar', icono = '🗑️', esPeligroso = true }) {
    this._bloquearScroll();
    return new Promise((resolve) => {
      this.confirmTitulo.textContent = titulo;
      this.confirmMensaje.textContent = mensaje;
      this.confirmIcono.textContent = icono;
      this.btnConfirmAceptar.textContent = textoAceptar;

      if (esPeligroso) {
        this.confirmIconBox.classList.remove('confirm-info');
        this.btnConfirmAceptar.className = 'btn btn-danger';
      } else {
        this.confirmIconBox.classList.add('confirm-info');
        this.btnConfirmAceptar.className = 'btn btn-primary';
      }

      const limpiar = () => {
        this.modalConfirmacion.classList.add('oculto');
        this.btnConfirmAceptar.removeEventListener('click', onAceptar);
        this.btnConfirmCancelar.removeEventListener('click', onCancelar);
        this.modalConfirmacion.removeEventListener('click', onBackdrop);
        this._desbloquearScroll();
      };

      const onAceptar = () => {
        limpiar();
        resolve(true);
      };

      const onCancelar = () => {
        limpiar();
        resolve(false);
      };

      const onBackdrop = (e) => {
        if (e.target === this.modalConfirmacion) {
          limpiar();
          resolve(false);
        }
      };

      this.btnConfirmAceptar.addEventListener('click', onAceptar);
      this.btnConfirmCancelar.addEventListener('click', onCancelar);
      this.modalConfirmacion.addEventListener('click', onBackdrop);
      this.modalConfirmacion.classList.remove('oculto');
    });
  }

  cambiarPestana(tab) {
    this.tabActiva = tab;
    this.tabBtns.forEach(btn => {
      btn.classList.toggle('active', btn.dataset.tab === tab);
    });

    if (tab === 'tablero') {
      this.viewTablero.classList.add('active');
      this.viewHistorial.classList.remove('active');
    } else {
      this.viewTablero.classList.remove('active');
      this.viewHistorial.classList.add('active');
    }
  }

  async cargarDatos() {
    try {
      this.lotes = await this.storage.obtenerLotes();
      this.registros = await this.storage.obtenerRegistros();
      this.renderizar();
    } catch (err) {
      console.error('Error al cargar datos:', err);
      alert('Error al acceder al almacenamiento: ' + err.message);
    }
  }

  /* ========================================================================
     LÓGICA DEL CRONÓMETRO DE 1 TOQUE (INICIAR -> EN CURSO -> TERMINAR)
     ======================================================================== */

  async iniciarTrabajoLote(loteId) {
    if (this.sesionActiva) {
      alert(`Ya tienes una sesión en curso en "${this.sesionActiva.supermercado} - ${this.sesionActiva.area}". Termínala o cancélala antes de iniciar otra.`);
      return;
    }

    const lote = this.lotes.find(l => l.id === loteId);
    if (!lote) return;

    const ahora = new Date();
    this.sesionActiva = {
      loteId: lote.id,
      supermercado: lote.supermercado,
      area: lote.area,
      cantidadProductos: lote.cantidadProductos || 0,
      fechaHoraInicio: ahora.toISOString()
    };

    await this.storage.guardarSesionActiva(this.sesionActiva);
    this._iniciarTickerSegundo();
    this.renderizar();
  }

  terminarSesionActiva() {
    if (!this.sesionActiva) return;

    const ahora = new Date();
    const inicio = new Date(this.sesionActiva.fechaHoraInicio);

    // Abrir modal de confirmación con los datos exactos precargados
    this.inputSesionLoteId.value = this.sesionActiva.loteId;
    this.inputSesionSupermercado.value = this.sesionActiva.supermercado;
    this.inputSesionArea.value = this.sesionActiva.area;
    this.inputSesionProductos.value = this.sesionActiva.cantidadProductos || '';
    this.inputSesionInicio.value = aInputDateTimeLocal(inicio);
    this.inputSesionFin.value = aInputDateTimeLocal(ahora);
    this.inputSesionObs.value = '';

    this.actualizarCalculoEnVivo();
    this._bloquearScroll();
    this.modalSesion.classList.remove('oculto');
  }

  async cancelarSesionActiva() {
    if (!this.sesionActiva) return;
    const confirmado = await this.mostrarConfirmacion({
      titulo: '¿Descartar sesión en curso?',
      mensaje: `Se cancelará el cronómetro de "${this.sesionActiva.supermercado} - ${this.sesionActiva.area}" sin registrar las horas.`,
      textoAceptar: 'Descartar',
      icono: '⚠️',
      esPeligroso: true
    });
    if (confirmado) {
      this._detenerTickerSegundo();
      this.sesionActiva = null;
      await this.storage.limpiarSesionActiva();
      this.renderizar();
    }
  }

  _iniciarTickerSegundo() {
    this._detenerTickerSegundo();
    this._actualizarDigitosCronometro();
    this._intervaloSegundo = setInterval(() => {
      this._actualizarDigitosCronometro();
    }, 1000);
  }

  _detenerTickerSegundo() {
    if (this._intervaloSegundo) {
      clearInterval(this._intervaloSegundo);
      this._intervaloSegundo = null;
    }
  }

  _actualizarDigitosCronometro() {
    if (!this.sesionActiva) {
      this._detenerTickerSegundo();
      return;
    }

    const inicio = new Date(this.sesionActiva.fechaHoraInicio).getTime();
    const ahora = Date.now();
    const segs = Math.max(0, Math.floor((ahora - inicio) / 1000));
    const texto = formatearCronometro(segs);

    // Actualizar tiempo en el botón de la tarjeta activa
    const spans = document.querySelectorAll(`.clock-span[data-id="${this.sesionActiva.loteId}"]`);
    spans.forEach(el => {
      el.textContent = texto;
    });
  }

  /* ========================================================================
     RENDERIZADO PRINCIPAL
     ======================================================================== */

  renderizar() {
    const ahora = new Date();

    // Actualizar cronómetro si hay sesión activa
    if (this.sesionActiva) {
      this._actualizarDigitosCronometro();
    }

    // 1. Clasificar cada lote
    const listos = [];
    const proximos = [];
    const futuros = [];
    let cantidadAcumulados = 0;

    this.lotes.forEach(lote => {
      const info = clasificarEstadoLote(lote, ahora);
      const loteConInfo = { ...lote, info };

      if (info.estado === ESTADOS.HABILITADO) {
        listos.push(loteConInfo);
        if (info.esAcumulado) cantidadAcumulados++;
      } else if (info.estado === ESTADOS.PROXIMO_7_DIAS) {
        proximos.push(loteConInfo);
      } else {
        futuros.push(loteConInfo);
      }
    });

    // Ordenar listos: primero la sesión activa (si hay), luego acumulados más antiguos, luego hoy
    listos.sort((a, b) => {
      if (this.sesionActiva) {
        if (a.id === this.sesionActiva.loteId) return -1;
        if (b.id === this.sesionActiva.loteId) return 1;
      }
      const tA = a.proximoDesbloqueo ? new Date(a.proximoDesbloqueo).getTime() : 0;
      const tB = b.proximoDesbloqueo ? new Date(b.proximoDesbloqueo).getTime() : 0;
      return tA - tB;
    });

    proximos.sort((a, b) => new Date(a.proximoDesbloqueo) - new Date(b.proximoDesbloqueo));
    futuros.sort((a, b) => new Date(a.proximoDesbloqueo) - new Date(b.proximoDesbloqueo));

    // 3. Renderizar secciones
    this._renderizarBannerAcumulados(cantidadAcumulados);
    this._renderizarListos(listos);
    this._renderizarProximos(proximos);
    this._renderizarFuturos(futuros);
    this._renderizarHistorialYHoras();
    this._actualizarDatalists();

    // 4. Actualizar contadores
    this.badgeCountListos.textContent = listos.length;
    this.badgeCountProximos.textContent = proximos.length;
    this.badgeCountFuturos.textContent = futuros.length;
    this.statListos.textContent = listos.length;
    this.statProximos.textContent = proximos.length;
  }

  _actualizarDatalists() {
    if (!this.datalistSupermercados || !this.datalistAreas) return;

    const supers = new Set();
    const areas = new Set();

    this.lotes.forEach(l => {
      if (l.supermercado) supers.add(l.supermercado);
      if (l.area) areas.add(l.area);
    });

    this.datalistSupermercados.innerHTML = Array.from(supers)
      .sort()
      .map(s => `<option value="${s}"></option>`)
      .join('');

    this.datalistAreas.innerHTML = Array.from(areas)
      .sort()
      .map(a => `<option value="${a}"></option>`)
      .join('');
  }

  _renderizarBannerAcumulados(cantidad) {
    if (cantidad > 0) {
      this.bannerAcumulados.classList.remove('oculto');
      this.bannerAcumuladosDesc.textContent = cantidad === 1
        ? `Tienes 1 lote habilitado de días anteriores listo para fotografiar hoy.`
        : `Tienes ${cantidad} lotes acumulados de días anteriores o fin de semana listos para fotografiar hoy.`;
    } else {
      this.bannerAcumulados.classList.add('oculto');
    }
  }

  _renderizarListos(listos) {
    if (listos.length === 0) {
      this.listaListos.innerHTML = `
        <div class="empty-state">
          🎉 ¡Todo al día! No tienes lotes pendientes para fotografiar hoy.
        </div>
      `;
      return;
    }

    this.listaListos.innerHTML = listos.map(lote => {
      const esActivo = this.sesionActiva && this.sesionActiva.loteId === lote.id;
      const esAcumulado = lote.info.esAcumulado;

      let claseCard = esAcumulado ? 'card-accumulated' : 'card-ready';
      if (esActivo) claseCard = 'card-active-session';

      const claseBadge = esAcumulado ? 'badge-accumulated' : 'badge-ready';
      const iconoBadge = esAcumulado ? '⚠️' : '✅';

      return `
        <article class="lote-card ${claseCard}">
          <div class="card-top">
            <div class="card-title-group">
              <h3 class="card-supermercado">${lote.supermercado}</h3>
              <p class="card-area">📍 ${lote.area}</p>
            </div>
            <div style="display: flex; align-items: center; gap: 6px;">
              <span class="card-badge ${claseBadge}">
                ${esActivo ? '⏱️ EN CURSO' : `${iconoBadge} ${lote.info.etiqueta}`}
              </span>
              <button class="btn-icon" data-accion="editar-lote" data-id="${lote.id}" title="Editar lote">✏️</button>
              <button class="btn-icon btn-icon-danger" data-accion="eliminar-lote" data-id="${lote.id}" title="Eliminar lote">🗑️</button>
            </div>
          </div>

          <div class="card-meta">
            <span class="meta-item">📦 <strong>${lote.cantidadProductos || 0}</strong> productos</span>
            ${lote.duracionMinutos ? `<span class="meta-item">⏱️ Última: ${lote.duracionMinutos} min</span>` : ''}
          </div>

          <p class="card-subtitulo">${lote.info.subtitulo}</p>
          ${lote.notas ? `<p class="card-subtitulo"><em>"${lote.notas}"</em></p>` : ''}

          <div class="card-actions">
            ${esActivo ? `
              <button class="btn btn-action-finish flex-1" data-accion="terminar-sesion" data-id="${lote.id}">
                ⏹️ Terminar Fotos (<span class="clock-span" data-id="${lote.id}">00:00</span>)
              </button>
              <button class="btn btn-secondary btn-sm" data-accion="cancelar-sesion" data-id="${lote.id}" title="Descartar sesión">
                ✖️ Descartar
              </button>
            ` : `
              <button class="btn btn-action-start" data-accion="iniciar-trabajo" data-id="${lote.id}">
                ▶️ Iniciar Fotos
              </button>
            `}
          </div>
        </article>
      `;
    }).join('');

    // Eventos de botones
    this.listaListos.querySelectorAll('[data-accion="iniciar-trabajo"]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const id = e.currentTarget.dataset.id;
        this.iniciarTrabajoLote(id);
      });
    });

    this.listaListos.querySelectorAll('[data-accion="terminar-sesion"]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.terminarSesionActiva();
      });
    });

    this.listaListos.querySelectorAll('[data-accion="cancelar-sesion"]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.cancelarSesionActiva();
      });
    });

    this.listaListos.querySelectorAll('[data-accion="editar-lote"]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const id = e.currentTarget.dataset.id;
        this.abrirModalLote(id);
      });
    });

    this.listaListos.querySelectorAll('[data-accion="eliminar-lote"]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const id = e.currentTarget.dataset.id;
        this.eliminarLote(id);
      });
    });
  }

  _renderizarProximos(proximos) {
    if (proximos.length === 0) {
      this.listaProximos.innerHTML = `
        <div class="empty-state">
          No hay lotes con desbloqueo en los próximos 7 días.
        </div>
      `;
      return;
    }

    const grupos = new Map();
    proximos.forEach(lote => {
      const key = claveDia(lote.proximoDesbloqueo);
      if (!grupos.has(key)) {
        grupos.set(key, []);
      }
      grupos.get(key).push(lote);
    });

    let html = '';
    grupos.forEach((lotesDelDia) => {
      const fechaObj = new Date(lotesDelDia[0].proximoDesbloqueo);
      const nombreDia = obtenerNombreDia(fechaObj);
      const fechaCorta = formatearFechaCorta(fechaObj);

      html += `
        <div class="itinerary-day-group">
          <div class="day-header">
            <span class="day-title">📅 ${nombreDia}</span>
            <span class="day-date">${fechaCorta}</span>
          </div>
          <div class="day-items">
            ${lotesDelDia.map(lote => `
              <article class="lote-card card-upcoming card-clickable" data-accion="ver-detalle" data-id="${lote.id}">
                <div class="card-top">
                  <div class="card-title-group">
                    <h4 class="card-supermercado">${lote.supermercado}</h4>
                    <p class="card-area">📍 ${lote.area}</p>
                  </div>
                  <div style="display: flex; align-items: center; gap: 6px;">
                    <span class="card-badge badge-upcoming">
                      🔓 ${formatearHora(lote.proximoDesbloqueo)}
                    </span>
                    <button class="btn-icon" data-accion="editar-lote" data-id="${lote.id}" title="Editar">✏️</button>
                    <button class="btn-icon btn-icon-danger" data-accion="eliminar-lote" data-id="${lote.id}" title="Eliminar">🗑️</button>
                  </div>
                </div>
                <div class="card-meta">
                  <span class="meta-item">📦 ${lote.cantidadProductos || 0} prods</span>
                  <span class="meta-item">⏳ ${lote.info.etiqueta}</span>
                </div>
              </article>
            `).join('')}
          </div>
        </div>
      `;
    });

    this.listaProximos.innerHTML = html;
    this._vincularEventosCards(this.listaProximos);
  }

  _renderizarFuturos(futuros) {
    if (futuros.length === 0) {
      this.listaFuturos.innerHTML = `
        <div class="empty-state">No hay más lotes registrados para fechas posteriores.</div>
      `;
      return;
    }

    this.listaFuturos.innerHTML = futuros.map(lote => `
      <article class="lote-card card-clickable" data-accion="ver-detalle" data-id="${lote.id}">
        <div class="card-top">
          <div class="card-title-group">
            <h4 class="card-supermercado">${lote.supermercado}</h4>
            <p class="card-area">📍 ${lote.area}</p>
          </div>
          <div style="display: flex; align-items: center; gap: 6px;">
            <span class="card-badge badge-future">${lote.info.etiqueta}</span>
            <button class="btn-icon" data-accion="editar-lote" data-id="${lote.id}" title="Editar">✏️</button>
            <button class="btn-icon btn-icon-danger" data-accion="eliminar-lote" data-id="${lote.id}" title="Eliminar">🗑️</button>
          </div>
        </div>
        <p class="card-subtitulo">${lote.info.subtitulo}</p>
      </article>
    `).join('');

    this._vincularEventosCards(this.listaFuturos);
  }

  _vincularEventosCards(contenedor) {
    contenedor.querySelectorAll('[data-accion="ver-detalle"]').forEach(card => {
      card.addEventListener('click', (e) => {
        // Evitar activar detalle si tocó en botones de editar o eliminar
        if (e.target.closest('[data-accion="editar-lote"]') || e.target.closest('[data-accion="eliminar-lote"]')) {
          return;
        }
        const id = card.dataset.id;
        this.abrirModalDetalleLote(id);
      });
    });

    contenedor.querySelectorAll('[data-accion="editar-lote"]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const id = e.currentTarget.dataset.id;
        this.abrirModalLote(id);
      });
    });

    contenedor.querySelectorAll('[data-accion="eliminar-lote"]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const id = e.currentTarget.dataset.id;
        this.eliminarLote(id);
      });
    });
  }

  _renderizarHistorialYHoras() {
    const ahora = new Date();
    let minsHoy = 0;
    let minsSemana = 0;
    let minsMes = 0;

    const inicioSemana = new Date(ahora);
    const diaSemana = (ahora.getDay() + 6) % 7;
    inicioSemana.setDate(ahora.getDate() - diaSemana);
    inicioSemana.setHours(0, 0, 0, 0);

    const inicioMes = new Date(ahora.getFullYear(), ahora.getMonth(), 1, 0, 0, 0, 0);

    this.registros.forEach(r => {
      const fInicio = new Date(r.fechaHoraInicio);
      const mins = r.duracionMinutos || 0;

      if (esMismoDia(fInicio, ahora)) minsHoy += mins;
      if (fInicio >= inicioSemana) minsSemana += mins;
      if (fInicio >= inicioMes) minsMes += mins;
    });

    const formatearMinutos = (m) => {
      const h = Math.floor(m / 60);
      const resto = m % 60;
      return `${h}h ${resto}m`;
    };

    this.statHorasHoy.textContent = formatearMinutos(minsHoy);
    this.horasSemana.textContent = formatearMinutos(minsSemana);
    this.horasMes.textContent = formatearMinutos(minsMes);

    const nombresMeses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    this.horasMesNombre.textContent = nombresMeses[ahora.getMonth()];

    this.badgeCountHistorial.textContent = this.registros.length;
    if (this.registros.length === 0) {
      this.listaHistorial.innerHTML = `
        <div class="empty-state">Aún no has registrado sesiones de trabajo completadas.</div>
      `;
      return;
    }

    this.listaHistorial.innerHTML = this.registros.slice(0, 30).map(r => `
      <div class="history-card">
        <div class="history-main">
          <strong>${r.supermercado}</strong>
          <span>📍 ${r.area} · 📦 ${r.cantidadProductos || 0} prods</span>
          <div class="history-date">${formatearFechaHora(r.fechaHoraInicio)}</div>
        </div>
        <div style="display: flex; align-items: center; gap: 10px;">
          <div class="history-duration">
            <span class="history-badge">${r.duracionTexto || `${r.duracionMinutos}m`}</span>
            <span class="history-date">Desbloquea en 120d</span>
          </div>
          <button class="btn-icon btn-icon-danger" data-accion="eliminar-registro" data-id="${r.id}" title="Eliminar registro">🗑️</button>
        </div>
      </div>
    `).join('');

    this.listaHistorial.querySelectorAll('[data-accion="eliminar-registro"]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const id = e.currentTarget.dataset.id;
        this.eliminarRegistroHistorial(id);
      });
    });
  }

  /* ========================================================================
     FICHA DETALLADA DE LOTE (INTERACCIÓN PARA LOTES FUTUROS)
     ======================================================================== */

  abrirModalDetalleLote(loteId) {
    const lote = this.lotes.find(l => l.id === loteId);
    if (!lote) return;

    this.loteSeleccionadoDetalle = lote;
    const ahora = new Date();
    const info = clasificarEstadoLote(lote, ahora);

    this.detalleTitulo.textContent = lote.supermercado;
    this.detalleSubtitulo.textContent = `📍 ${lote.area}`;
    this.detalleCountdownValor.textContent = info.etiqueta;
    this.detalleFechaExacta.textContent = lote.proximoDesbloqueo
      ? `Desbloquea el ${formatearFechaCorta(lote.proximoDesbloqueo)} a las ${formatearHora(lote.proximoDesbloqueo)}`
      : 'Disponible de inmediato';

    this.detalleSupermercado.textContent = lote.supermercado;
    this.detalleArea.textContent = lote.area;
    this.detalleProductos.textContent = `${lote.cantidadProductos || 0} productos`;
    this.detalleUltimaDuracion.textContent = lote.duracionMinutos
      ? `${lote.duracionMinutos} minutos`
      : 'Sin datos previos';

    if (lote.notas) {
      this.detalleNotasWrapper.classList.remove('oculto');
      this.detalleNotasTexto.textContent = `"${lote.notas}"`;
    } else {
      this.detalleNotasWrapper.classList.add('oculto');
    }

    this._bloquearScroll();
    this.modalDetalleLote.classList.remove('oculto');
  }

  async adelantarLoteSeleccionado() {
    if (!this.loteSeleccionadoDetalle) return;
    const { supermercado, area, id } = this.loteSeleccionadoDetalle;

    const confirmado = await this.mostrarConfirmacion({
      titulo: '¿Habilitar para hoy?',
      mensaje: `¿Deseas adelantar "${supermercado} - ${area}" para poder fotografiarlo hoy mismo?`,
      textoAceptar: 'Habilitar Hoy',
      icono: '⚡',
      esPeligroso: false
    });

    if (confirmado) {
      try {
        await this.storage.adelantarLote(id);
        this.cerrarModales();
        await this.cargarDatos();
      } catch (err) {
        alert('Error al adelantar lote: ' + err.message);
      }
    }
  }

  /* ========================================================================
     MODALES: EDICIÓN, CREACIÓN Y ELIMINACIÓN
     ======================================================================== */

  abrirModalLote(loteId = null) {
    this.formLote.reset();

    if (loteId) {
      const lote = this.lotes.find(l => l.id === loteId);
      if (!lote) return;

      this.modalLoteTitulo.textContent = 'Editar Lote de Trabajo';
      document.getElementById('lote-id').value = lote.id;
      document.getElementById('lote-supermercado').value = lote.supermercado;
      document.getElementById('lote-area').value = lote.area;
      document.getElementById('lote-productos').value = lote.cantidadProductos || '';
      document.getElementById('lote-ultimo-inicio').value = lote.ultimoInicio ? aInputDateTimeLocal(lote.ultimoInicio) : '';
      document.getElementById('lote-notas').value = lote.notas || '';
    } else {
      this.modalLoteTitulo.textContent = 'Nuevo Lote de Trabajo';
      document.getElementById('lote-id').value = '';
    }

    this._bloquearScroll();
    this.modalLote.classList.remove('oculto');
  }

  async eliminarLote(loteId) {
    const lote = this.lotes.find(l => l.id === loteId);
    if (!lote) return;

    const confirmado = await this.mostrarConfirmacion({
      titulo: '¿Eliminar este lote?',
      mensaje: `Se quitará "${lote.supermercado} - ${lote.area}" de tus tiendas. El historial previo se mantendrá.`,
      textoAceptar: 'Eliminar Lote',
      icono: '🗑️',
      esPeligroso: true
    });

    if (confirmado) {
      try {
        await this.storage.eliminarLote(loteId);
        this.cerrarModales();
        await this.cargarDatos();
      } catch (err) {
        alert('Error al eliminar lote: ' + err.message);
      }
    }
  }

  async eliminarRegistroHistorial(registroId) {
    const confirmado = await this.mostrarConfirmacion({
      titulo: '¿Eliminar registro?',
      mensaje: '¿Estás seguro de que deseas eliminar esta sesión de fotos del historial?',
      textoAceptar: 'Eliminar Registro',
      icono: '🗑️',
      esPeligroso: true
    });

    if (confirmado) {
      try {
        await this.storage.eliminarRegistro(registroId);
        await this.cargarDatos();
      } catch (err) {
        alert('Error al eliminar registro: ' + err.message);
      }
    }
  }

  cerrarModales() {
    this.modalSesion.classList.add('oculto');
    this.modalLote.classList.add('oculto');
    this.modalDetalleLote.classList.add('oculto');
    this.loteSeleccionadoDetalle = null;
    this._desbloquearScroll();
  }

  aplicarDuracionRapida(minutos) {
    const fInicio = new Date(this.inputSesionInicio.value);
    if (!isNaN(fInicio.getTime())) {
      const fFin = new Date(fInicio.getTime() + (minutos * 60 * 1000));
      this.inputSesionFin.value = aInputDateTimeLocal(fFin);
      this.actualizarCalculoEnVivo();
    }
  }

  actualizarCalculoEnVivo() {
    const fInicio = new Date(this.inputSesionInicio.value);
    const fFin = new Date(this.inputSesionFin.value);

    if (!isNaN(fInicio.getTime()) && !isNaN(fFin.getTime())) {
      const duracion = calcularHorasTrabajadas(fInicio, fFin);
      this.calcTiempoTrabajado.textContent = duracion.texto;

      const proximoDesbloqueo = calcularProximoDesbloqueo(fInicio);
      this.calcDesbloqueoPreview.textContent = formatearFechaHora(proximoDesbloqueo);
    } else {
      this.calcTiempoTrabajado.textContent = '--';
      this.calcDesbloqueoPreview.textContent = '--/--/---- --:--';
    }
  }

  async guardarSesion(e) {
    e.preventDefault();

    const loteId = this.inputSesionLoteId.value;
    const supermercado = this.inputSesionSupermercado.value.trim();
    const area = this.inputSesionArea.value.trim();
    const cantidadProductos = parseInt(this.inputSesionProductos.value, 10) || 0;
    const inicio = new Date(this.inputSesionInicio.value);
    const fin = new Date(this.inputSesionFin.value);
    const observaciones = this.inputSesionObs.value.trim();

    if (fin.getTime() < inicio.getTime()) {
      alert('La fecha y hora de fin no puede ser anterior al inicio.');
      return;
    }

    try {
      await this.storage.registrarSesionTrabajo({
        loteId,
        supermercado,
        area,
        cantidadProductos,
        fechaHoraInicio: inicio,
        fechaHoraFin: fin,
        observaciones
      });

      this._detenerTickerSegundo();
      this.sesionActiva = null;
      await this.storage.limpiarSesionActiva();

      this.cerrarModales();
      await this.cargarDatos();
    } catch (err) {
      console.error('Error al guardar sesión:', err);
      alert('Error al guardar sesión: ' + err.message);
    }
  }

  async guardarLote(e) {
    e.preventDefault();

    const id = document.getElementById('lote-id').value;
    const supermercado = document.getElementById('lote-supermercado').value.trim();
    const area = document.getElementById('lote-area').value.trim();
    const cantidadProductos = parseInt(document.getElementById('lote-productos').value, 10) || 0;
    const ultimoInicioStr = document.getElementById('lote-ultimo-inicio').value;
    const notas = document.getElementById('lote-notas').value.trim();

    const ultimoInicio = ultimoInicioStr ? new Date(ultimoInicioStr) : null;

    try {
      await this.storage.guardarLote({
        id: id || undefined,
        supermercado,
        area,
        cantidadProductos,
        ultimoInicio,
        notas
      });

      this.cerrarModales();
      await this.cargarDatos();
    } catch (err) {
      console.error('Error al guardar lote:', err);
      alert('Error al guardar lote: ' + err.message);
    }
  }
}

// Inicialización al cargar el DOM
document.addEventListener('DOMContentLoaded', () => {
  const app = new AppController();
  app.iniciar();
});
