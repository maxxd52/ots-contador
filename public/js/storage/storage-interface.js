/**
 * Contrato de Almacenamiento (Storage Interface)
 * Define las operaciones requeridas para cualquier backend (LocalStorage o Firebase Firestore).
 */

export class StorageInterface {
  /**
   * Obtiene la lista completa de lotes activos.
   * @returns {Promise<Array<Object>>}
   */
  async obtenerLotes() {
    throw new Error('Método obtenerLotes() no implementado');
  }

  /**
   * Guarda o actualiza un lote.
   * @param {Object} lote
   * @returns {Promise<Object>}
   */
  async guardarLote(lote) {
    throw new Error('Método guardarLote() no implementado');
  }

  /**
   * Elimina un lote por ID (baja lógica o física).
   * @param {string} id
   * @returns {Promise<boolean>}
   */
  async eliminarLote(id) {
    throw new Error('Método eliminarLote() no implementado');
  }

  /**
   * Obtiene la lista de registros de trabajo (historial).
   * @param {Object} [filtros]
   * @returns {Promise<Array<Object>>}
   */
  async obtenerRegistros(filtros = {}) {
    throw new Error('Método obtenerRegistros() no implementado');
  }

  /**
   * Guarda un nuevo registro de trabajo e inmediatamente actualiza el lote correspondiente
   * reiniciando su ciclo de 120 días exactos y las horas registradas.
   * 
   * @param {Object} datosSesion
   * @returns {Promise<{ lote: Object, registro: Object }>}
   */
  async registrarSesionTrabajo(datosSesion) {
    throw new Error('Método registrarSesionTrabajo() no implementado');
  }
}
