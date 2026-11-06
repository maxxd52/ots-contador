/**
 * Adaptador de Persistencia Local (LocalStorageAdapter)
 * Permite ejecutar la aplicación 100% en local sin backend ni conexión a internet.
 */

import { StorageInterface } from './storage-interface.js';
import { crearLote, crearRegistroTrabajo, generarId } from '../domain/models.js';
import { calcularProximoDesbloqueo, calcularHorasTrabajadas, MS_POR_DIA } from '../domain/time.js';

const KEY_LOTES = 'ots_lotes_v1';
const KEY_REGISTROS = 'ots_registros_v1';

export class LocalStorageAdapter extends StorageInterface {
  constructor() {
    super();
    this._memStore = new Map();
    this._asegurarSemillas();
  }

  _isBrowser() {
    return typeof window !== 'undefined' && typeof window.localStorage !== 'undefined';
  }

  _leer(key, fallback = []) {
    if (this._isBrowser()) {
      try {
        const raw = window.localStorage.getItem(key);
        return raw ? JSON.parse(raw) : fallback;
      } catch (err) {
        console.warn(`Error al leer LocalStorage [${key}]:`, err);
        return fallback;
      }
    }
    return this._memStore.get(key) || fallback;
  }

  _guardar(key, valor) {
    if (this._isBrowser()) {
      try {
        window.localStorage.setItem(key, JSON.stringify(valor));
      } catch (err) {
        console.error(`Error al escribir en LocalStorage [${key}]:`, err);
      }
    } else {
      this._memStore.set(key, valor);
    }
  }

  _asegurarSemillas() {
    const lotes = this._leer(KEY_LOTES, null);
    if (!lotes || lotes.length === 0) {
      const ahora = new Date();

      // Generar 5 lotes de ejemplo representativos:
      // 1. Desbloqueado hoy a las 08:30 (Hoy)
      const fechaHoy = new Date(ahora.getTime() - (120 * MS_POR_DIA) - (3 * 3600 * 1000));
      // 2. Desbloqueado hace 2 días (Acumulado de día no trabajado / finde)
      const fechaAcumulado = new Date(ahora.getTime() - (122 * MS_POR_DIA));
      // 3. Desbloqueo en 2 días (Próximos 7 días)
      const fechaProx2d = new Date(ahora.getTime() - (118 * MS_POR_DIA));
      // 4. Desbloqueo en 5 días (Próximos 7 días)
      const fechaProx5d = new Date(ahora.getTime() - (115 * MS_POR_DIA));
      // 5. Desbloqueo en 50 días (Futuro)
      const fechaFuturo = new Date(ahora.getTime() - (70 * MS_POR_DIA));

      const semillas = [
        crearLote({
          id: 'lote_carrefour_lacteos',
          supermercado: 'Carrefour San Martín',
          area: 'Lácteos y Yogures',
          cantidadProductos: 95,
          ultimoInicio: fechaHoy,
          ultimoFin: new Date(fechaHoy.getTime() + (45 * 60 * 1000)),
          proximoDesbloqueo: calcularProximoDesbloqueo(fechaHoy),
          duracionMinutos: 45,
          notas: 'Revisar góndola central y heladeras de yogures firmes.'
        }),
        crearLote({
          id: 'lote_coto_perfumeria',
          supermercado: 'Coto Belgrano',
          area: 'Perfumería y Cuidado Personal',
          cantidadProductos: 140,
          ultimoInicio: fechaAcumulado,
          ultimoFin: new Date(fechaAcumulado.getTime() + (60 * 60 * 1000)),
          proximoDesbloqueo: calcularProximoDesbloqueo(fechaAcumulado),
          duracionMinutos: 60,
          notas: 'Pendiente del fin de semana. Sacar fotos de desodorantes y cremas.'
        }),
        crearLote({
          id: 'lote_jumbo_bebidas',
          supermercado: 'Jumbo Palermo',
          area: 'Bebidas sin Alcohol y Aguas',
          cantidadProductos: 110,
          ultimoInicio: fechaProx2d,
          ultimoFin: new Date(fechaProx2d.getTime() + (50 * 60 * 1000)),
          proximoDesbloqueo: calcularProximoDesbloqueo(fechaProx2d),
          duracionMinutos: 50,
          notas: 'Pasillo 4 y 5 completo.'
        }),
        crearLote({
          id: 'lote_changomas_limpieza',
          supermercado: 'ChangoMás Avellaneda',
          area: 'Artículos de Limpieza',
          cantidadProductos: 80,
          ultimoInicio: fechaProx5d,
          ultimoFin: new Date(fechaProx5d.getTime() + (40 * 60 * 1000)),
          proximoDesbloqueo: calcularProximoDesbloqueo(fechaProx5d),
          duracionMinutos: 40,
          notas: 'Jabones líquidos y suavizantes.'
        }),
        crearLote({
          id: 'lote_carrefour_galletitas',
          supermercado: 'Carrefour San Martín',
          area: 'Galletitas y Snacks',
          cantidadProductos: 130,
          ultimoInicio: fechaFuturo,
          ultimoFin: new Date(fechaFuturo.getTime() + (55 * 60 * 1000)),
          proximoDesbloqueo: calcularProximoDesbloqueo(fechaFuturo),
          duracionMinutos: 55,
          notas: 'Góndola dulce y salada.'
        })
      ];

      this._guardar(KEY_LOTES, semillas);
    }
  }

  async obtenerLotes() {
    const lista = this._leer(KEY_LOTES, []);
    return lista.filter(l => l.activo !== false);
  }

  async guardarLote(datos) {
    const lote = crearLote(datos);
    const lista = this._leer(KEY_LOTES, []);
    const idx = lista.findIndex(item => item.id === lote.id);

    if (idx >= 0) {
      lista[idx] = { ...lista[idx], ...lote, updatedAt: new Date().toISOString() };
    } else {
      lista.unshift(lote);
    }

    this._guardar(KEY_LOTES, lista);
    return lote;
  }

  async eliminarLote(id) {
    const lista = this._leer(KEY_LOTES, []);
    const filtrada = lista.filter(item => item.id !== id);
    this._guardar(KEY_LOTES, filtrada);
    return true;
  }

  async obtenerRegistros(filtros = {}) {
    let lista = this._leer(KEY_REGISTROS, []);
    if (filtros.loteId) {
      lista = lista.filter(r => r.loteId === filtros.loteId);
    }
    if (filtros.supermercado) {
      lista = lista.filter(r => r.supermercado === filtros.supermercado);
    }
    // Orden descendente por fecha de inicio
    return lista.sort((a, b) => new Date(b.fechaHoraInicio) - new Date(a.fechaHoraInicio));
  }

  async registrarSesionTrabajo(datosSesion) {
    const registro = crearRegistroTrabajo(datosSesion);
    const listaRegistros = this._leer(KEY_REGISTROS, []);
    listaRegistros.unshift(registro);
    this._guardar(KEY_REGISTROS, listaRegistros);

    // Actualizar o crear el Lote vinculado
    const listaLotes = this._leer(KEY_LOTES, []);
    let loteActualizado = null;

    const idx = listaLotes.findIndex(l => 
      (registro.loteId && l.id === registro.loteId) ||
      (l.supermercado.toLowerCase() === registro.supermercado.toLowerCase() &&
       l.area.toLowerCase() === registro.area.toLowerCase())
    );

    const proximoDesbloqueo = registro.desbloqueoCalculado;
    const duracion = calcularHorasTrabajadas(registro.fechaHoraInicio, registro.fechaHoraFin);

    if (idx >= 0) {
      listaLotes[idx] = {
        ...listaLotes[idx],
        cantidadProductos: registro.cantidadProductos || listaLotes[idx].cantidadProductos,
        ultimoInicio: registro.fechaHoraInicio,
        ultimoFin: registro.fechaHoraFin,
        duracionMinutos: duracion.minutos,
        proximoDesbloqueo: proximoDesbloqueo,
        updatedAt: new Date().toISOString()
      };
      loteActualizado = listaLotes[idx];
    } else {
      loteActualizado = crearLote({
        supermercado: registro.supermercado,
        area: registro.area,
        cantidadProductos: registro.cantidadProductos,
        ultimoInicio: registro.fechaHoraInicio,
        ultimoFin: registro.fechaHoraFin,
        duracionMinutos: duracion.minutos,
        proximoDesbloqueo: proximoDesbloqueo
      });
      listaLotes.unshift(loteActualizado);
    }

    this._guardar(KEY_LOTES, listaLotes);
    return { lote: loteActualizado, registro };
  }

  exportarBackup() {
    return {
      version: 1,
      fechaExportacion: new Date().toISOString(),
      lotes: this._leer(KEY_LOTES, []),
      registros: this._leer(KEY_REGISTROS, [])
    };
  }

  importarBackup(backup) {
    if (!backup || !Array.isArray(backup.lotes)) {
      throw new Error('Formato de backup inválido');
    }
    this._guardar(KEY_LOTES, backup.lotes);
    this._guardar(KEY_REGISTROS, backup.registros || []);
    return true;
  }
}
