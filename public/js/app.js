/**
 * Controlador Principal de la Aplicación: OTS 120 Días
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
    this.tabActiva = 'tablero';
    this._intervaloTicker = null;
  }

  async iniciar() {
    this._vincularElementosUI();
    this._vincularEventos();
    this._actualizarBadgeBackend();
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

    // Botones
    this.btnNuevoLote = document.getElementById('btn-nuevo-lote');
    this.fabCompletar = document.getElementById('fab-completar');
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

    // FAB para registrar sesión
    this.fabCompletar.addEventListener('click', () => this.abrirModalSesion());

    // Cerrar modales
    document.getElementById('btn-cerrar-modal-sesion').addEventListener('click', () => this.cerrarModales());
    document.getElementById('btn-cancelar-sesion').addEventListener('click', () => this.cerrarModales());
    document.getElementById('btn-cerrar-modal-lote').addEventListener('click', () => this.cerrarModales());
    document.getElementById('btn-cancelar-lote').addEventListener('click', () => this.cerrarModales());

    // Submit formulario sesión de fotos
    this.formSesion.addEventListener('submit', (e) => this.guardarSesion(e));

    // Submit formulario nuevo lote
    this.formLote.addEventListener('submit', (e) => this.guardarLote(e));

    // Cálculo en vivo en modal sesión
    this.inputSesionInicio.addEventListener('input', () => this.actualizarCalculoEnVivo());
    this.inputSesionFin.addEventListener('input', () => this.actualizarCalculoEnVivo());

    // Chips de duración rápida (+30m, +45m, +60m, +90m)
    document.querySelectorAll('.btn-chip').forEach(chip => {
      chip.addEventListener('click', (e) => {
        const minutos = parseInt(e.currentTarget.dataset.minutos, 10);
        this.aplicarDuracionRapida(minutos);
      });
    });
  }

  _actualizarBadgeBackend() {
    const badge = document.getElementById('badge-backend');
    if (badge) {
      if (CONFIG.STORAGE_BACKEND === 'firebase') {
        badge.textContent = 'Firebase';
        badge.classList.add('firebase');
      } else {
        badge.textContent = 'Local';
        badge.classList.remove('firebase');
      }
    }
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

  renderizar() {
    const ahora = new Date();

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

    // Ordenar listos: primero los acumulados más antiguos, luego los de hoy
    listos.sort((a, b) => {
      const tA = a.proximoDesbloqueo ? new Date(a.proximoDesbloqueo).getTime() : 0;
      const tB = b.proximoDesbloqueo ? new Date(b.proximoDesbloqueo).getTime() : 0;
      return tA - tB;
    });

    // Ordenar próximos por fecha de desbloqueo más cercana
    proximos.sort((a, b) => new Date(a.proximoDesbloqueo) - new Date(b.proximoDesbloqueo));

    // Ordenar futuros por fecha
    futuros.sort((a, b) => new Date(a.proximoDesbloqueo) - new Date(b.proximoDesbloqueo));

    // 2. Renderizar secciones
    this._renderizarBannerAcumulados(cantidadAcumulados);
    this._renderizarListos(listos);
    this._renderizarProximos(proximos);
    this._renderizarFuturos(futuros);
    this._renderizarHistorialYHoras();

    // 3. Actualizar contadores
    this.badgeCountListos.textContent = listos.length;
    this.badgeCountProximos.textContent = proximos.length;
    this.badgeCountFuturos.textContent = futuros.length;
    this.statListos.textContent = listos.length;
    this.statProximos.textContent = proximos.length;
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
      const esAcumulado = lote.info.esAcumulado;
      const claseCard = esAcumulado ? 'card-accumulated' : 'card-ready';
      const claseBadge = esAcumulado ? 'badge-accumulated' : 'badge-ready';
      const iconoBadge = esAcumulado ? '⚠️' : '✅';

      return `
        <article class="lote-card ${claseCard}">
          <div class="card-top">
            <div>
              <h3 class="card-supermercado">${lote.supermercado}</h3>
              <p class="card-area">📍 ${lote.area}</p>
            </div>
            <span class="card-badge ${claseBadge}">
              ${iconoBadge} ${lote.info.etiqueta}
            </span>
          </div>

          <div class="card-meta">
            <span class="meta-item">📦 <strong>${lote.cantidadProductos || 0}</strong> productos</span>
            ${lote.duracionMinutos ? `<span class="meta-item">⏱️ Última: ${lote.duracionMinutos} min</span>` : ''}
          </div>

          <p class="card-subtitulo">${lote.info.subtitulo}</p>
          ${lote.notas ? `<p class="card-subtitulo"><em>"${lote.notas}"</em></p>` : ''}

          <div class="card-actions">
            <button class="btn btn-sm btn-action-start" data-accion="fotografiar" data-id="${lote.id}">
              📸 Iniciar / Completar Fotos
            </button>
          </div>
        </article>
      `;
    }).join('');

    // Delegación de eventos para botones de iniciar sesión
    this.listaListos.querySelectorAll('[data-accion="fotografiar"]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const id = e.currentTarget.dataset.id;
        this.abrirModalSesion(id);
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

    // Agrupar por día (YYYY-MM-DD)
    const grupos = new Map();
    proximos.forEach(lote => {
      const key = claveDia(lote.proximoDesbloqueo);
      if (!grupos.has(key)) {
        grupos.set(key, []);
      }
      grupos.get(key).push(lote);
    });

    let html = '';
    grupos.forEach((lotesDelDia, fechaKey) => {
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
              <article class="lote-card card-upcoming">
                <div class="card-top">
                  <div>
                    <h4 class="card-supermercado">${lote.supermercado}</h4>
                    <p class="card-area">📍 ${lote.area}</p>
                  </div>
                  <span class="card-badge badge-upcoming">
                    🔓 Desbloquea ${formatearHora(lote.proximoDesbloqueo)}
                  </span>
                </div>
                <div class="card-meta">
                  <span class="meta-item">📦 ${lote.cantidadProductos || 0} productos</span>
                  <span class="meta-item">⏳ ${lote.info.etiqueta}</span>
                </div>
              </article>
            `).join('')}
          </div>
        </div>
      `;
    });

    this.listaProximos.innerHTML = html;
  }

  _renderizarFuturos(futuros) {
    if (futuros.length === 0) {
      this.listaFuturos.innerHTML = `
        <div class="empty-state">No hay más lotes registrados para fechas posteriores.</div>
      `;
      return;
    }

    this.listaFuturos.innerHTML = futuros.map(lote => `
      <article class="lote-card">
        <div class="card-top">
          <div>
            <h4 class="card-supermercado">${lote.supermercado}</h4>
            <p class="card-area">📍 ${lote.area}</p>
          </div>
          <span class="card-badge badge-future">${lote.info.etiqueta}</span>
        </div>
        <p class="card-subtitulo">${lote.info.subtitulo}</p>
      </article>
    `).join('');
  }

  _renderizarHistorialYHoras() {
    const ahora = new Date();
    let minsHoy = 0;
    let minsSemana = 0;
    let minsMes = 0;

    // Calcular inicio de semana (Lunes a las 00:00)
    const inicioSemana = new Date(ahora);
    const diaSemana = (ahora.getDay() + 6) % 7; // Lunes = 0
    inicioSemana.setDate(ahora.getDate() - diaSemana);
    inicioSemana.setHours(0, 0, 0, 0);

    // Calcular inicio de mes
    const inicioMes = new Date(ahora.getFullYear(), ahora.getMonth(), 1, 0, 0, 0, 0);

    this.registros.forEach(r => {
      const fInicio = new Date(r.fechaHoraInicio);
      const mins = r.duracionMinutos || 0;

      if (esMismoDia(fInicio, ahora)) {
        minsHoy += mins;
      }
      if (fInicio >= inicioSemana) {
        minsSemana += mins;
      }
      if (fInicio >= inicioMes) {
        minsMes += mins;
      }
    });

    // Formatear tiempos
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

    // Lista del historial
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
        <div class="history-duration">
          <span class="history-badge">${r.duracionTexto || `${r.duracionMinutos}m`}</span>
          <span class="history-date">Desbloquea en 120d</span>
        </div>
      </div>
    `).join('');
  }

  abrirModalSesion(loteId = null) {
    const ahora = new Date();
    const lote = loteId ? this.lotes.find(l => l.id === loteId) : null;

    this.inputSesionLoteId.value = lote ? lote.id : '';
    this.inputSesionSupermercado.value = lote ? lote.supermercado : '';
    this.inputSesionArea.value = lote ? lote.area : '';
    this.inputSesionProductos.value = lote ? (lote.cantidadProductos || '') : '';
    this.inputSesionObs.value = '';

    // Fechas por defecto: inicio hace 45 minutos (o ahora), fin ahora mismo
    const finPorDefecto = ahora;
    const duracionDefaultMins = (lote && lote.duracionMinutos) ? lote.duracionMinutos : 45;
    const inicioPorDefecto = new Date(ahora.getTime() - (duracionDefaultMins * 60 * 1000));

    this.inputSesionInicio.value = aInputDateTimeLocal(inicioPorDefecto);
    this.inputSesionFin.value = aInputDateTimeLocal(finPorDefecto);

    this.actualizarCalculoEnVivo();
    this.modalSesion.classList.remove('oculto');
  }

  abrirModalLote() {
    this.formLote.reset();
    document.getElementById('lote-id').value = '';
    this.modalLote.classList.remove('oculto');
  }

  cerrarModales() {
    this.modalSesion.classList.add('oculto');
    this.modalLote.classList.add('oculto');
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
