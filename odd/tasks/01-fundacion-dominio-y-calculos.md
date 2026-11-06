# Tarea ODD 01: Fundación de Dominio, Lógica de 120 Días y Persistencia Local-First

## Objetivo
Implementar el núcleo del sistema de control de fotoperiodos para fotógrafos de góndola:
1. Módulo de cálculo temporal exacto a 120 días calendario sensible a la hora y clasificador de estados (disponibles/acumulados, próximos 7 días, futuros).
2. Modelos de datos para Lotes y Registros con validaciones.
3. Adaptador de almacenamiento local (`LocalStorageAdapter`) para funcionamiento local inmediato.
4. Adaptador de almacenamiento Firestore (`FirestoreAdapter`) listo para cuando se configure Firebase Spark.
5. Suite de pruebas unitarias ejecutadas con `node --test` que validen los cálculos y acumulaciones de días.

---

## Slices de Trabajo

### Slice 1: Dominio de Tiempo y Pruebas Unitarias
- [x] Crear `DOMAIN.md` y `ARCHITECTURE.md`.
- [x] Implementar `public/js/domain/time.js` con:
  - `calcularProximoDesbloqueo(fechaHoraInicio, dias = 120)`
  - `clasificarEstadoLote(lote, ahora = new Date())`
  - `calcularHorasTrabajadas(inicio, fin)`
  - Formateadores de fecha y hora local con nombres de días y cuentas regresivas amigables.
- [x] Implementar `tests/time.test.js` y verificar con `node --test`.

### Slice 2: Modelos, Contratos de Almacenamiento y Adaptadores
- [x] Implementar `public/js/domain/models.js` (Creación y normalización de lotes y registros).
- [x] Implementar `public/js/storage/storage-interface.js`.
- [x] Implementar `public/js/storage/local-storage.js` (persistencia local con soporte de import/export y datos semilla).
- [x] Implementar `public/js/storage/firestore-storage.js` (esqueleto compatible con Firebase Web SDK).
- [x] Implementar `public/js/config.js` para alternar almacenamiento.

### Slice 3: Interfaz Móvil y Tablero Inteligente
- [x] Diseñar `public/index.html` con layout mobile-first:
  - Header con resumen de horas y lotes activos.
  - Tablero de Lotes Habilitados y Acumulados (urgentes / disponibles hoy).
  - Itinerario de los Próximos 7 Días.
  - Modal de Registro rápido de sesión de fotos (con cronómetro en vivo o ingreso manual).
  - Modal de nuevo lote / supermercado.
- [x] Estilos CSS en `public/css/styles.css` (variables CSS, modo oscuro/claro, tipografía clara para uso con una mano en supermercado).
- [x] Controlador `public/js/app.js` conectando eventos y persistencia.

### Slice 4: Verificación Visual, Firebase Config y Sync
- [x] Archivos de configuración Firebase: `firebase.json` y `firestore.rules` (con subagente firestore-rules-author).
- [x] Verificación visual con Playwright MCP en emulación móvil.
- [x] Sincronización en memoria con Engram MCP (`mem_save`, `engram sync`).
