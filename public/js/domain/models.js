/**
 * Modelos y Fábricas de Datos: OTS 120 Días
 */

import { calcularProximoDesbloqueo, calcularHorasTrabajadas, normalizarFecha } from './time.js';

/**
 * Genera un ID único (UUID v4 o fallback criptográfico).
 */
export function generarId() {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'ots_' + Date.now().toString(36) + '_' + Math.random().toString(36).substring(2, 9);
}

/**
 * Fábrica y sanitizador para la entidad Lote.
 */
export function crearLote(datos = {}) {
  const supermercado = String(datos.supermercado || '').trim();
  const area = String(datos.area || '').trim();
  const cantidadProductos = Math.max(0, parseInt(datos.cantidadProductos, 10) || 0);

  if (!supermercado) throw new Error('El nombre del supermercado es obligatorio');
  if (!area) throw new Error('El área o sector de trabajo es obligatoria');

  const ahora = new Date();
  const ultimoInicio = datos.ultimoInicio ? normalizarFecha(datos.ultimoInicio) : null;
  const ultimoFin = datos.ultimoFin ? normalizarFecha(datos.ultimoFin) : null;

  // Si tiene último inicio pero no tiene proximoDesbloqueo, se calcula con la regla de 120 días
  let proximoDesbloqueo = datos.proximoDesbloqueo ? normalizarFecha(datos.proximoDesbloqueo) : null;
  if (ultimoInicio && !proximoDesbloqueo) {
    proximoDesbloqueo = calcularProximoDesbloqueo(ultimoInicio);
  }

  let duracionMinutos = datos.duracionMinutos || 0;
  if (ultimoInicio && ultimoFin && !duracionMinutos) {
    duracionMinutos = calcularHorasTrabajadas(ultimoInicio, ultimoFin).minutos;
  }

  return {
    id: datos.id || generarId(),
    supermercado,
    area,
    cantidadProductos,
    ultimoInicio: ultimoInicio ? ultimoInicio.toISOString() : null,
    ultimoFin: ultimoFin ? ultimoFin.toISOString() : null,
    proximoDesbloqueo: proximoDesbloqueo ? proximoDesbloqueo.toISOString() : null,
    duracionMinutos,
    activo: datos.activo !== undefined ? Boolean(datos.activo) : true,
    notas: String(datos.notas || '').trim(),
    createdAt: datos.createdAt ? normalizarFecha(datos.createdAt).toISOString() : ahora.toISOString(),
    updatedAt: ahora.toISOString()
  };
}

/**
 * Fábrica y sanitizador para la entidad RegistroTrabajo.
 */
export function crearRegistroTrabajo(datos = {}) {
  const loteId = String(datos.loteId || '').trim();
  const supermercado = String(datos.supermercado || '').trim();
  const area = String(datos.area || '').trim();
  const cantidadProductos = Math.max(0, parseInt(datos.cantidadProductos, 10) || 0);

  if (!supermercado) throw new Error('El supermercado es obligatorio para registrar la sesión');
  if (!area) throw new Error('El área es obligatoria para registrar la sesión');

  const inicio = normalizarFecha(datos.fechaHoraInicio) || new Date();
  const fin = normalizarFecha(datos.fechaHoraFin) || new Date(inicio.getTime() + (30 * 60 * 1000)); // Default +30 min

  const duracion = calcularHorasTrabajadas(inicio, fin);
  const desbloqueoCalculado = calcularProximoDesbloqueo(inicio);

  return {
    id: datos.id || generarId(),
    loteId: loteId || null,
    supermercado,
    area,
    cantidadProductos,
    fechaHoraInicio: inicio.toISOString(),
    fechaHoraFin: fin.toISOString(),
    duracionMinutos: duracion.minutos,
    horasDecimal: duracion.horasDecimal,
    duracionTexto: duracion.texto,
    desbloqueoCalculado: desbloqueoCalculado.toISOString(),
    observaciones: String(datos.observaciones || '').trim(),
    createdAt: new Date().toISOString()
  };
}
