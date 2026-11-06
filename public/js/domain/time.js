/**
 * Módulo de Lógica Temporal: OTS 120 Días
 * Cálculos exactos de fotoperiodos, horas trabajadas y clasificación de estados.
 */

export const DIAS_CICLO = 120;
export const MS_POR_SEGUNDO = 1000;
export const MS_POR_MINUTO = 60 * MS_POR_SEGUNDO;
export const MS_POR_HORA = 60 * MS_POR_MINUTO;
export const MS_POR_DIA = 24 * MS_POR_HORA;
export const MS_7_DIAS = 7 * MS_POR_DIA;

export const ESTADOS = {
  HABILITADO: 'HABILITADO',           // Listo para fotografiar hoy o acumulado
  PROXIMO_7_DIAS: 'PROXIMO_7_DIAS',   // Se habilitará dentro de los próximos 7 días
  FUTURO: 'FUTURO'                    // Desbloqueo a más de 7 días
};

/**
 * Normaliza cualquier entrada de fecha (Date, ISO string, timestamp numérico o Firestore Timestamp)
 * a un objeto Date nativo.
 */
export function normalizarFecha(fecha) {
  if (!fecha) return null;
  if (fecha instanceof Date) return isNaN(fecha.getTime()) ? null : fecha;
  if (typeof fecha.toDate === 'function') return fecha.toDate(); // Firestore Timestamp
  if (typeof fecha === 'number') return new Date(fecha);
  if (typeof fecha === 'string') {
    const d = new Date(fecha);
    return isNaN(d.getTime()) ? null : d;
  }
  return null;
}

/**
 * Calcula la fecha y hora exacta de desbloqueo sumando exactamente N días calendario (por defecto 120).
 * Preserva exactamente la hora, minuto y segundo de inicio.
 *
 * @param {Date|string|number} fechaHoraInicio 
 * @param {number} dias - Cantidad de días calendario (default 120)
 * @returns {Date} Fecha exacta de desbloqueo
 */
export function calcularProximoDesbloqueo(fechaHoraInicio, dias = DIAS_CICLO) {
  const inicio = normalizarFecha(fechaHoraInicio);
  if (!inicio) throw new Error('Fecha de inicio inválida para calcular desbloqueo');
  return new Date(inicio.getTime() + (dias * MS_POR_DIA));
}

/**
 * Calcula la duración entre hora de inicio y fin.
 * @param {Date|string|number} inicio 
 * @param {Date|string|number} fin 
 * @returns {{ minutos: number, horasDecimal: number, texto: string }}
 */
export function calcularHorasTrabajadas(inicio, fin) {
  const fInicio = normalizarFecha(inicio);
  const fFin = normalizarFecha(fin);
  if (!fInicio || !fFin) {
    return { minutos: 0, horasDecimal: 0, texto: '0h 0m' };
  }

  const diffMs = Math.max(0, fFin.getTime() - fInicio.getTime());
  const minutos = Math.floor(diffMs / MS_POR_MINUTO);
  const horas = Math.floor(minutos / 60);
  const minsRestantes = minutos % 60;
  const horasDecimal = Number((minutos / 60).toFixed(2));

  return {
    minutos,
    horasDecimal,
    texto: `${horas}h ${minsRestantes}m`
  };
}

/**
 * Evalúa el estado actual de un lote en relación a un instante temporal (por defecto ahora).
 * 
 * @param {Object} lote - Objeto Lote con propiedad proximoDesbloqueo
 * @param {Date|string|number} [ahoraRef=new Date()]
 * @returns {{
 *   estado: string,
 *   esAcumulado: boolean,
 *   diasDiferencia: number,
 *   horasDiferencia: number,
 *   etiqueta: string,
 *   subtitulo: string
 * }}
 */
export function clasificarEstadoLote(lote, ahoraRef = new Date()) {
  const ahora = normalizarFecha(ahoraRef) || new Date();
  const desbloqueo = normalizarFecha(lote.proximoDesbloqueo);

  if (!desbloqueo) {
    return {
      estado: ESTADOS.HABILITADO,
      esAcumulado: false,
      diasDiferencia: 0,
      horasDiferencia: 0,
      etiqueta: 'Listo para iniciar',
      subtitulo: 'Sin registro previo'
    };
  }

  const diffMs = desbloqueo.getTime() - ahora.getTime();

  // Caso 1: Ya se desbloqueó (Hoy o acumulado de días pasados)
  if (diffMs <= 0) {
    const pasadoMs = Math.abs(diffMs);
    const diasPasados = Math.floor(pasadoMs / MS_POR_DIA);
    const horasPasadas = Math.floor((pasadoMs % MS_POR_DIA) / MS_POR_HORA);
    const mismoDia = esMismoDia(desbloqueo, ahora);

    if (mismoDia) {
      return {
        estado: ESTADOS.HABILITADO,
        esAcumulado: false,
        diasDiferencia: 0,
        horasDiferencia: horasPasadas,
        etiqueta: 'Habilitado hoy',
        subtitulo: `Desbloqueado a las ${formatearHora(desbloqueo)}`
      };
    } else {
      const etiquetaAcumulado = diasPasados === 1 
        ? 'Acumulado de ayer' 
        : `Acumulado hace ${diasPasados} días`;
      return {
        estado: ESTADOS.HABILITADO,
        esAcumulado: true,
        diasDiferencia: diasPasados,
        horasDiferencia: horasPasadas,
        etiqueta: etiquetaAcumulado,
        subtitulo: `Se desbloqueó el ${formatearFechaCorta(desbloqueo)} a las ${formatearHora(desbloqueo)}`
      };
    }
  }

  // Caso 2: Próximos 7 días
  if (diffMs <= MS_7_DIAS) {
    const diasFaltantes = Math.floor(diffMs / MS_POR_DIA);
    const horasFaltantes = Math.floor((diffMs % MS_POR_DIA) / MS_POR_HORA);
    const minsFaltantes = Math.floor((diffMs % MS_POR_HORA) / MS_POR_MINUTO);

    let textoCuentaRegresiva = '';
    if (diasFaltantes > 0) {
      textoCuentaRegresiva = `en ${diasFaltantes}d ${horasFaltantes}h`;
    } else if (horasFaltantes > 0) {
      textoCuentaRegresiva = `en ${horasFaltantes}h ${minsFaltantes}m`;
    } else {
      textoCuentaRegresiva = `en ${minsFaltantes} min`;
    }

    return {
      estado: ESTADOS.PROXIMO_7_DIAS,
      esAcumulado: false,
      diasDiferencia: diasFaltantes,
      horasDiferencia: horasFaltantes,
      etiqueta: textoCuentaRegresiva,
      subtitulo: `${obtenerNombreDia(desbloqueo)} ${formatearFechaCorta(desbloqueo)} a las ${formatearHora(desbloqueo)}`
    };
  }

  // Caso 3: Futuro más allá de 7 días
  const diasFaltantes = Math.floor(diffMs / MS_POR_DIA);
  return {
    estado: ESTADOS.FUTURO,
    esAcumulado: false,
    diasDiferencia: diasFaltantes,
    horasDiferencia: 0,
    etiqueta: `En ${diasFaltantes} días`,
    subtitulo: `${formatearFechaCorta(desbloqueo)} ${formatearHora(desbloqueo)}`
  };
}

/**
 * Comprueba si dos fechas corresponden al mismo día calendario local.
 */
export function esMismoDia(fechaA, fechaB) {
  const a = normalizarFecha(fechaA);
  const b = normalizarFecha(fechaB);
  if (!a || !b) return false;
  return a.getFullYear() === b.getFullYear() &&
         a.getMonth() === b.getMonth() &&
         a.getDate() === b.getDate();
}

/**
 * Retorna la clave 'YYYY-MM-DD' para agrupaciones por día.
 */
export function claveDia(fecha) {
  const d = normalizarFecha(fecha);
  if (!d) return '';
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Formatea fecha y hora en formato legible en español: DD/MM/AAAA HH:MM
 */
export function formatearFechaHora(fecha) {
  const d = normalizarFecha(fecha);
  if (!d) return '--/--/---- --:--';
  const dia = String(d.getDate()).padStart(2, '0');
  const mes = String(d.getMonth() + 1).padStart(2, '0');
  const anio = d.getFullYear();
  const hora = String(d.getHours()).padStart(2, '0');
  const min = String(d.getMinutes()).padStart(2, '0');
  return `${dia}/${mes}/${anio} ${hora}:${min}`;
}

/**
 * Formatea sólo la hora: HH:MM
 */
export function formatearHora(fecha) {
  const d = normalizarFecha(fecha);
  if (!d) return '--:--';
  const hora = String(d.getHours()).padStart(2, '0');
  const min = String(d.getMinutes()).padStart(2, '0');
  return `${hora}:${min}`;
}

/**
 * Formatea sólo la fecha corta: DD/MM/AAAA
 */
export function formatearFechaCorta(fecha) {
  const d = normalizarFecha(fecha);
  if (!d) return '--/--/----';
  const dia = String(d.getDate()).padStart(2, '0');
  const mes = String(d.getMonth() + 1).padStart(2, '0');
  const anio = d.getFullYear();
  return `${dia}/${mes}/${anio}`;
}

/**
 * Retorna el nombre del día en español (ej: "Lunes", "Martes").
 */
export function obtenerNombreDia(fecha) {
  const d = normalizarFecha(fecha);
  if (!d) return '';
  const dias = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
  return dias[d.getDay()];
}

/**
 * Formatea segundos totales a formato de cronómetro: "MM:SS" o "HH:MM:SS"
 */
export function formatearCronometro(segundosTotales) {
  const segs = Math.max(0, Math.floor(segundosTotales));
  const horas = Math.floor(segs / 3600);
  const minutos = Math.floor((segs % 3600) / 60);
  const segundos = segs % 60;

  const mStr = String(minutos).padStart(2, '0');
  const sStr = String(segundos).padStart(2, '0');

  if (horas > 0) {
    const hStr = String(horas).padStart(2, '0');
    return `${hStr}:${mStr}:${sStr}`;
  }
  return `${mStr}:${sStr}`;
}

/**
 * Genera el valor datetime-local para inputs HTML: 'YYYY-MM-DDTHH:MM'
 */
export function aInputDateTimeLocal(fecha = new Date()) {
  const d = normalizarFecha(fecha) || new Date();
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');
  return `${year}-${month}-${day}T${hours}:${minutes}`;
}
