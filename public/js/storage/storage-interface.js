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

  /**
   * Elimina un registro de trabajo del historial.
   * @param {string} id
   * @returns {Promise<boolean>}
   */
  async eliminarRegistro(id) {
    throw new Error('Método eliminarRegistro() no implementado');
  }

  /**
   * Fuerza el desbloqueo inmediato de un lote fijando su fecha a ahora.
   * @param {string} id
   * @returns {Promise<Object>}
   */
  async adelantarLote(id) {
    throw new Error('Método adelantarLote() no implementado');
  }

  /**
   * Obtiene la sesión de trabajo actualmente en curso (si existe).
   * @returns {Promise<Object|null>}
   */
  async obtenerSesionActiva() {
    throw new Error('Método obtenerSesionActiva() no implementado');
  }

  /**
   * Persiste la sesión en curso para resistir recargas o cierres de navegador.
   * @param {Object} sesion
   * @returns {Promise<boolean>}
   */
  async guardarSesionActiva(sesion) {
    throw new Error('Método guardarSesionActiva() no implementado');
  }

  /**
   * Limpia la sesión en curso una vez completada o cancelada.
   * @returns {Promise<boolean>}
   */
  async limpiarSesionActiva() {
    throw new Error('Método limpiarSesionActiva() no implementado');
  }
}
