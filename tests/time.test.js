import test from 'node:test';
import assert from 'node:assert/strict';
import {
  DIAS_CICLO,
  MS_POR_DIA,
  calcularProximoDesbloqueo,
  calcularHorasTrabajadas,
  clasificarEstadoLote,
  ESTADOS,
  normalizarFecha,
  esMismoDia,
  aInputDateTimeLocal,
  claveDia,
  formatearCronometro
} from '../public/js/domain/time.js';

test('calcularProximoDesbloqueo - suma exactamente 120 días calendario y preserva la hora exacta', () => {
  // Inicio: 5 de Noviembre de 2026 a las 08:30:15
  const inicio = new Date('2026-11-05T08:30:15.000Z');
  const desbloqueo = calcularProximoDesbloqueo(inicio);

  // Diferencia exacta en milisegundos debe ser 120 * 24 * 3600 * 1000
  const diffMs = desbloqueo.getTime() - inicio.getTime();
  assert.equal(diffMs, 120 * MS_POR_DIA);

  // La hora, minuto y segundo UTC deben ser idénticos
  assert.equal(desbloqueo.getUTCHours(), 8);
  assert.equal(desbloqueo.getUTCMinutes(), 30);
  assert.equal(desbloqueo.getUTCSeconds(), 15);

  // En días calendario: Noviembre tiene 30 días, Diciembre 31, Enero 31, Febrero 28
  // 25 días restantes en Nov + 31 en Dic + 31 en Ene + 28 en Feb = 115 días al fin de Febrero
  // Por lo tanto, 120 días cae el 5 de Marzo de 2027
  assert.equal(desbloqueo.getUTCFullYear(), 2027);
  assert.equal(desbloqueo.getUTCMonth(), 2); // Mes 2 es Marzo (0-indexed)
  assert.equal(desbloqueo.getUTCDate(), 5);
});

test('calcularHorasTrabajadas - calcula minutos, decimales y formato legible', () => {
  const inicio = new Date('2026-11-05T09:00:00');
  const fin = new Date('2026-11-05T10:45:00'); // 1 hora y 45 minutos (105 min)

  const resultado = calcularHorasTrabajadas(inicio, fin);
  assert.equal(resultado.minutos, 105);
  assert.equal(resultado.horasDecimal, 1.75);
  assert.equal(resultado.texto, '1h 45m');
});

test('clasificarEstadoLote - lote sin registro previo aparece como HABILITADO', () => {
  const lote = { proximoDesbloqueo: null };
  const clasificacion = clasificarEstadoLote(lote);

  assert.equal(clasificacion.estado, ESTADOS.HABILITADO);
  assert.equal(clasificacion.esAcumulado, false);
});

test('clasificarEstadoLote - lote desbloqueado hoy se marca como HABILITADO no acumulado', () => {
  const ahora = new Date('2026-11-05T14:00:00');
  // Se desbloqueó hoy a las 08:30 (hace 5 horas y media)
  const desbloqueo = new Date('2026-11-05T08:30:00');
  const lote = { proximoDesbloqueo: desbloqueo };

  const res = clasificarEstadoLote(lote, ahora);
  assert.equal(res.estado, ESTADOS.HABILITADO);
  assert.equal(res.esAcumulado, false);
  assert.match(res.etiqueta, /Habilitado hoy/);
});

test('clasificarEstadoLote - lote desbloqueado hace 2 días (acumulado) se marca como HABILITADO acumulado', () => {
  const ahora = new Date('2026-11-05T10:00:00');
  // Se desbloqueó hace 2 días (por ej. martes no trabajado o fin de semana)
  const desbloqueo = new Date('2026-11-03T10:00:00');
  const lote = { proximoDesbloqueo: desbloqueo };

  const res = clasificarEstadoLote(lote, ahora);
  assert.equal(res.estado, ESTADOS.HABILITADO);
  assert.equal(res.esAcumulado, true);
  assert.equal(res.diasDiferencia, 2);
  assert.match(res.etiqueta, /Acumulado hace 2 días/);
});

test('clasificarEstadoLote - lote con desbloqueo en 3 días entra en PROXIMO_7_DIAS', () => {
  const ahora = new Date('2026-11-05T10:00:00');
  const desbloqueo = new Date('2026-11-08T15:30:00'); // 3 días y pico
  const lote = { proximoDesbloqueo: desbloqueo };

  const res = clasificarEstadoLote(lote, ahora);
  assert.equal(res.estado, ESTADOS.PROXIMO_7_DIAS);
  assert.equal(res.esAcumulado, false);
  assert.match(res.etiqueta, /en 3d/);
});

test('clasificarEstadoLote - lote con desbloqueo en 30 días entra en FUTURO', () => {
  const ahora = new Date('2026-11-05T10:00:00');
  const desbloqueo = new Date('2026-12-05T10:00:00');
  const lote = { proximoDesbloqueo: desbloqueo };

  const res = clasificarEstadoLote(lote, ahora);
  assert.equal(res.estado, ESTADOS.FUTURO);
  assert.equal(res.esAcumulado, false);
  assert.match(res.etiqueta, /En 30 días/);
});

test('normalizarFecha y utilidades de formato', () => {
  const fecha = new Date('2026-11-05T09:15:00');
  assert.equal(esMismoDia(fecha, new Date('2026-11-05T23:59:59')), true);
  assert.equal(esMismoDia(fecha, new Date('2026-11-06T00:00:01')), false);
  assert.equal(claveDia(fecha), '2026-11-05');
  assert.equal(aInputDateTimeLocal(fecha), '2026-11-05T09:15');
});

test('formatearCronometro - formatea MM:SS y HH:MM:SS', () => {
  assert.equal(formatearCronometro(0), '00:00');
  assert.equal(formatearCronometro(65), '01:05');
  assert.equal(formatearCronometro(3665), '01:01:05');
});

