import test from 'node:test';
import assert from 'node:assert/strict';
import { crearLote, crearRegistroTrabajo } from '../public/js/domain/models.js';
import { LocalStorageAdapter } from '../public/js/storage/local-storage.js';

test('crearLote - valida datos obligatorios y calcula proximoDesbloqueo si tiene fecha inicio', () => {
  assert.throws(() => crearLote({ supermercado: '' }), /supermercado es obligatorio/);
  assert.throws(() => crearLote({ supermercado: 'Coto', area: '' }), /área.*obligatoria/);

  const inicio = new Date('2026-11-05T08:30:00Z');
  const lote = crearLote({
    supermercado: 'Coto Belgrano',
    area: 'Perfumería',
    cantidadProductos: 120,
    ultimoInicio: inicio
  });

  assert.equal(lote.supermercado, 'Coto Belgrano');
  assert.equal(lote.area, 'Perfumería');
  assert.equal(lote.cantidadProductos, 120);
  assert.ok(lote.proximoDesbloqueo, 'Debe calcular automáticamente el próximo desbloqueo');
});

test('crearRegistroTrabajo - calcula horas trabajadas y nuevo desbloqueo', () => {
  const inicio = new Date('2026-11-05T09:00:00Z');
  const fin = new Date('2026-11-05T10:30:00Z'); // 90 min (1.5 horas)

  const reg = crearRegistroTrabajo({
    supermercado: 'Jumbo',
    area: 'Lácteos',
    cantidadProductos: 80,
    fechaHoraInicio: inicio,
    fechaHoraFin: fin
  });

  assert.equal(reg.duracionMinutos, 90);
  assert.equal(reg.horasDecimal, 1.5);
  assert.ok(reg.desbloqueoCalculado);
});

test('LocalStorageAdapter - registra sesión de fotos y reinicia el ciclo del lote', async () => {
  const storage = new LocalStorageAdapter();
  const lotesIniciales = await storage.obtenerLotes();
  assert.ok(lotesIniciales.length > 0, 'Debe contener semillas de prueba');

  const loteExistente = lotesIniciales[0];
  const ahora = new Date();
  const fin = new Date(ahora.getTime() + (40 * 60 * 1000));

  const { lote, registro } = await storage.registrarSesionTrabajo({
    loteId: loteExistente.id,
    supermercado: loteExistente.supermercado,
    area: loteExistente.area,
    cantidadProductos: 100,
    fechaHoraInicio: ahora,
    fechaHoraFin: fin,
    observaciones: 'Trabajo completado con éxito'
  });

  assert.equal(lote.id, loteExistente.id);
  assert.equal(lote.duracionMinutos, 40);
  assert.ok(new Date(lote.proximoDesbloqueo) > ahora);

  const registros = await storage.obtenerRegistros({ loteId: loteExistente.id });
  assert.ok(registros.length >= 1);
  assert.equal(registros[0].observaciones, 'Trabajo completado con éxito');
});
