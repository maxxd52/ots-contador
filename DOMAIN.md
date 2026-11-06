# Constitución de Dominio: OTS 120 Días

Este documento define las entidades, invariantes, reglas de negocio y lógica temporal de la aplicación de control de fotoperiodos y horas trabajadas en supermercados.

---

## 1. Entidades del Dominio

### 1.1. `Lote` (Estación de Trabajo / Góndola)
Representa un sector específico dentro de un supermercado que requiere actualización fotográfica periódica.
- **`id`** (`string`): Identificador único (UUID o slug).
- **`supermercado`** (`string`): Nombre del establecimiento (ej: *"Carrefour San Martín"*, *"Coto Belgrano"*).
- **`area`** (`string`): Sector o categoría (ej: *"Lácteos"*, *"Perfumería"*, *"Bebidas"*).
- **`cantidadProductos`** (`number`): Cantidad estimada o habitual de productos a fotografiar.
- **`ultimoInicio`** (`ISOString` / `Date`): Momento exacto en que inició la última sesión de fotos.
- **`ultimoFin`** (`ISOString` / `Date`): Momento en que finalizó la última sesión.
- **`proximoDesbloqueo`** (`ISOString` / `Date`): Momento exacto en que se vuelve a habilitar para fotos (`ultimoInicio + 120 días calendario`).
- **`duracionMinutos`** (`number`): Duración calculada de la última sesión en minutos.
- **`activo`** (`boolean`): Estado lógico (true = en rotación activa).
- **`createdAt`** / **`updatedAt`** (`ISOString` / `Date`).

### 1.2. `RegistroTrabajo` (Historial / Sesión OTS)
Representa el registro inmutable de una sesión de fotos completada.
- **`id`** (`string`): Identificador único.
- **`loteId`** (`string`): Referencia al lote de trabajo.
- **`supermercado`** (`string`): Supermercado fotografiado.
- **`area`** (`string`): Área trabajada.
- **`cantidadProductos`** (`number`): Productos fotografiados en la sesión.
- **`fechaHoraInicio`** (`ISOString` / `Date`): Marca de tiempo sensible al minuto/segundo.
- **`fechaHoraFin`** (`ISOString` / `Date`): Marca de tiempo de fin de sesión.
- **`duracionMinutos`** (`number`): Minutos trabajados en este lote.
- **`desbloqueoCalculado`** (`ISOString` / `Date`): Desbloqueo generado a 120 días.
- **`observaciones`** (`string`, opcional): Comentarios sobre faltantes o novedades de góndola.
- **`createdAt`** (`ISOString` / `Date`).

---

## 2. Reglas de Negocio Inmutables

### 2.1. Regla de los 120 Días Calendario Exactos
- El período de actualización **NO es de 4 meses fijos**, sino de **exactamente 120 días calendario corridos** ($120 \times 24\text{ horas} = 2.880\text{ horas} = 10.368.000.000\text{ ms}$).
- **Sensibilidad horaria:** La hora y minuto de desbloqueo futuro son idénticos a la hora y minuto del inicio de la sesión anterior:
  $$\text{Desbloqueo} = \text{Inicio} + 120\text{ días}$$
  *Ejemplo:* Si una sesión inició el `2026-11-05 08:30:00`, se desbloquea exactamente el `2027-03-05 08:30:00`.

### 2.2. Regla de Disponibilidad y Backlog Acumulado
- En cualquier instante temporal $T_{\text{ahora}}$:
  - **`HABILITADO` (Listo hoy o acumulado):** Si $T_{\text{ahora}} \ge \text{proximoDesbloqueo}$.
    - **Invariante de Acumulación:** Si el lote se desbloqueó en un día no laborable (ej: martes libre, fin de semana, feriado), **no desaparece ni expira**. Permanece en el tablero principal como pendiente y disponible con su badge de antigüedad (ej. *"Habilitado hace 2 días"*).
  - **`PRÓXIMOS 7 DÍAS`:** Si $T_{\text{ahora}} < \text{proximoDesbloqueo} \le T_{\text{ahora}} + 7\text{ días}$.
    - Muestra la fecha exacta y un contador de tiempo restante en cuenta regresiva.
  - **`FUTURO`:** Si $\text{proximoDesbloqueo} > T_{\text{ahora}} + 7\text{ días}$.

### 2.3. Regla del Contador de Horas OTS
- Toda sesión de trabajo registra `fechaHoraInicio` y `fechaHoraFin`.
- La duración en minutos es $\lfloor(\text{Fin} - \text{Inicio}) / 60000\rfloor$.
- Las horas se acumulan por:
  - Horas trabajadas Hoy.
  - Horas trabajadas en la Semana en curso (Lunes a Domingo).
  - Horas trabajadas en el Mes calendario.

---

## 3. Estados Dinámicos en Cliente (Spark Compatible)
Dado que el Plan Spark no cuenta con tareas programadas en servidor (cron/Cloud Functions), los estados **nunca se escriben de forma estática en la base de datos**. Se deducen al vuelo en memoria en el navegador comparando `proximoDesbloqueo` con el reloj del cliente, evitando lecturas o escrituras innecesarias en Firestore.
