# Tarea ODD 02: Migración de Interfaz Gráfica a Flutter Material Design 3

## 1. Objetivo
Migrar la interfaz gráfica y experiencia de usuario de la aplicación web SPA actual a **Flutter (Material Design 3)**, manteniendo:
1. **La misma distribución funcional y experiencia ágil de 1 toque**:
   - KPIs superiores de horas y lotes (Horas Hoy, Listos Hoy, Próximos 7D).
   - Selector de vistas / pestañas ("Tablero & Itinerario" / "Historial & Horas").
   - Sección de "Listos para Fotografiar" con botón de acción dinámico (`▶️ Iniciar Fotos` -> `⏱️ En Curso (MM:SS)` -> `⏹️ Terminar Fotos`).
   - Sección de "Itinerario Próximos 7 Días" agrupado por fecha de desbloqueo exacto.
   - Hojas modales / BottomSheets M3 para:
     - Registro/Finalización de sesión con cálculo en vivo de horas trabajadas y preview exacto del próximo desbloqueo a los 120 días calendario.
     - Creación y edición de Lotes.
     - Ficha interactiva de lotes futuros con botón de desbloqueo manual anticipado.
     - Diálogo de confirmación con diseño M3.
2. **Identidad visual extraída de la app de trabajo del usuario**:
   - Paleta de colores exacta muestreada de las capturas de la app de auditoría fotográfica:
     - **Púrpura Corporativo Principal (Header & Brand)**: `#612680` (RGB: 97, 38, 128).
     - **Fondo de Pantalla / Canvas**: `#F4F3F8` / `#EFEFF7` (Superficie lavanda ultra-suave y limpia).
     - **Superficie de Tarjetas (Cards)**: `#FFFFFF` con esquinas redondeadas M3 (`BorderRadius.circular(16)`).
     - **Verde Acción Primaria (Botón Añadir Fotos / Listo)**: `#0EBD6E` (RGB: 14, 189, 110) con texto/ícono en blanco.
     - **Ámbar / Warning (Lotes Acumulados / Alertas)**: `#EAB308` / `#D97706` con contenedor `#FEF9E7`.
     - **Rojo / Descarte / Peligro**: `#E11D48` / `#DC2626` con contenedor `#FEEBEF`.
     - **Contenedores de Acento Lavanda**: `#EDE7F6` para íconos de categorías/sectores.
     - **Tipografía y Textos**: Títulos en `#1E1B26` y textos secundarios en `#6B7280`.

---

## 2. Arquitectura de Código en Flutter (Clean Architecture + MVVM)
Siguiendo las directrices oficiales de Flutter (`flutter-apply-architecture-best-practices`):

```text
flutter_app/
├── lib/
│   ├── core/
│   │   ├── theme/
│   │   │   ├── app_colors.dart        # Tokens de color exactos extraídos
│   │   │   └── app_theme.dart         # ThemeData M3 con ColorScheme personalizado
│   │   └── utils/
│   │       ├── date_formatter.dart    # Formateo de fechas, cronómetros y días en español
│   │       └── result.dart
│   ├── domain/
│   │   ├── models/
│   │   │   ├── lote.dart              # Entidad Lote con validaciones
│   │   │   ├── registro_trabajo.dart  # Entidad RegistroTrabajo
│   │   │   └── estado_lote.dart       # Enum y clasificador (Habilitado, Acumulado, Próximo, Futuro)
│   │   └── logic/
│   │       └── time_calculator.dart   # Lógica matemática de 120 días exactos y cálculo de horas
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── local_storage_service.dart # SharedPreferences / Hive para persistencia local
│   │   │   └── seed_data.dart             # Lotes iniciales de ejemplo
│   │   └── repositories/
│   │       └── ots_repository.dart        # Contrato e implementación de almacenamiento
│   └── ui/
│       ├── viewmodels/
│       │   └── tablero_viewmodel.dart     # Gestión de estado (ChangeNotifier) y cronómetro en vivo
│       ├── widgets/
│       │   ├── kpi_header_widget.dart     # Tarjetas superiores de resumen
│       │   ├── lote_card_widget.dart      # Tarjeta de lote con botón dinámico
│       │   ├── itinerary_group_widget.dart# Agrupación de días del itinerario
│       │   └── quick_duration_chips.dart  # Chips de duración rápida (+30m, +45m, +1h, +1.5h)
│       └── views/
│           ├── home_screen.dart           # Pantalla principal con pestañas y FAB
│           ├── modal_sesion_sheet.dart    # BottomSheet M3 para terminar/registrar fotos
│           ├── modal_lote_sheet.dart      # BottomSheet M3 para crear/editar lote
│           └── dialog_confirmacion.dart   # Diálogo M3 de confirmación
└── test/
    ├── domain_test.dart                   # Pruebas unitarias de cálculo de 120 días en Dart
    └── repository_test.dart               # Pruebas de persistencia y flujo de datos
```

---

## 3. Plan de Slices ODD

### [x] Slice 1: Inicialización de Flutter, Tokens de Color e Infraestructura de Dominio
- [x] Inicializar el subproyecto Flutter (`flutter_app`) configurado para Web, Android y Windows con `useMaterial3: true`.
- [x] Implementar `AppColors` y `AppTheme` con la paleta exacta `#612680`, `#0EBD6E`, `#F4F3F8`, etc.
- [x] Portar a Dart la lógica de dominio: `Lote`, `RegistroTrabajo`, `TimeCalculator` (regla matemática de $120 \times 86400000\text{ ms}$).
- [x] Escribir pruebas unitarias en Dart (`flutter test`) para asegurar equivalencia matemática con la versión Web actual (10/10 tests pasados).

### [x] Slice 2: Persistencia de Datos y ViewModel Central
- [x] Implementar el repositorio de datos local con persistencia y datos semilla.
- [x] Implementar `TableroViewModel` con gestión de sesión activa y cronómetro segundo a segundo.
- [x] Pruebas unitarias del ViewModel y repositorio (14/14 tests pasando).

### [x] Slice 3: Interfaz Gráfica M3 (Pantalla Principal y Tarjetas de Lotes)
- [x] Header con AppBar púrpura estilizado (`#612680`) con el logo/título y KPIs en tarjetas elevadas.
- [x] Pestañas M3 (`TabBar`) para alternar entre "Tablero & Itinerario" e "Historial & Horas".
- [x] Lista de "Listos para Fotografiar" con tarjetas blancas, borde izquierdo de estado y botón verde esmeralda dinámico (`#0EBD6E`).
- [x] Lista de "Itinerario Próximos 7 Días" con tarjetas agrupadas por fecha.

### [x] Slice 4: BottomSheets M3 de Acción (Registro de Sesión, Creación y Ficha de Lote)
- [x] BottomSheet modal M3 de "Registrar Sesión de Fotos" con cronómetro, campos `DateTime`, atajos de duración y cálculo en vivo del próximo desbloqueo a los 120 días.
- [x] BottomSheet de nuevo lote / edición.
- [x] Ficha interactiva de detalle de lote futuro con acción rápida de habilitación.
- [x] Diálogo de confirmación M3 para cancelar cronómetros o eliminar lotes.

### [x] Slice 5: Compilación Web, Pruebas y Despliegue
- [x] Verificar compilación en Flutter Web (`flutter build web --release`).
- [x] Probar ejecución interactiva en navegador (puerto 4174).
- [x] Respaldar observaciones en Engram MCP y exportar chunks con `engram sync`.
