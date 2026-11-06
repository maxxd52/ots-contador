# Constitución de Arquitectura: OTS 120 Días

Este documento describe la arquitectura del sistema, el patrón de persistencia desacoplado y la estrategia de compatibilidad con Firebase Spark.

---

## 1. Principios de Diseño

1. **Local-First & Spark-Compliant:**
   - Desarrollo y pruebas 100% operativos en local mediante `LocalStorageAdapter` sin requerir conexión a internet ni cuenta de Firebase configurada.
   - Migración instantánea a Firebase Spark cambiando únicamente el adaptador a `FirestoreAdapter`.
2. **Offline-Ready:**
   - La aplicación debe funcionar sin conexión a internet dentro del supermercado. En modo Firebase, utiliza `persistentLocalCache` (IndexedDB).
3. **Cero Dependencias de Construcción:**
   - SPA en JavaScript ES6 modular nativo (módulos ES `.js`), HTML5 semántico y CSS3 moderno.
   - Se puede servir con cualquier servidor estático local (`npx serve`, Python `http.server`, o extensión Live Server) y directamente con Firebase Hosting.

---

## 2. Diagrama de Arquitectura de Capas

```
┌────────────────────────────────────────────────────────┐
│                   UI / DOM Layer                       │
│    (public/index.html + public/css/styles.css)         │
└───────────────────────────▲────────────────────────────┘
                            │ DOM Events / Render
┌───────────────────────────┴────────────────────────────┐
│                  App Coordinator                       │
│                 (public/js/app.js)                     │
└───────────────▲──────────────────────────▲─────────────┘
                │                          │
┌───────────────┴───────────────┐ ┌────────┴─────────────┐
│         Domain Logic          │ │     Storage Contract │
│   (public/js/domain/time.js   │ │  (storage-interface) │
│    public/js/domain/models.js)│ └──────────▲───────────┘
└───────────────────────────────┘            │
                           ┌─────────────────┴─────────────────┐
                           │                                   │
              ┌────────────┴────────────┐         ┌────────────┴────────────┐
              │   LocalStorageAdapter   │         │    FirestoreAdapter     │
              │   (Desarrollo Local)    │         │  (Firebase Spark Prod)  │
              └─────────────────────────┘         └─────────────────────────┘
```

---

## 3. Estructura del Proyecto

```
poryecto contador de horas ots/
├── .engram/                  # Memoria persistente sincronizada
├── .gitignore
├── DOMAIN.md                 # Definición del dominio e invariantes
├── ARCHITECTURE.md           # Estructura y arquitectura del sistema
├── firebase.json             # Configuración de Firebase Hosting
├── firestore.rules           # Reglas declarativas de seguridad Firestore
├── odd/
│   └── tasks/
│       └── 01-fundacion-dominio-y-calculos.md
├── public/                   # Raíz de despliegue para Firebase Hosting
│   ├── index.html            # SPA Entry point móvil
│   ├── css/
│   │   └── styles.css        # Diseño responsivo mobile-first
│   └── js/
│       ├── domain/
│       │   ├── time.js       # Algoritmo de 120 días y cálculo de estados
│       │   └── models.js     # Fábricas y validación de Lotes y Registros
│       ├── storage/
│       │   ├── storage-interface.js  # Contrato abstracto
│       │   ├── local-storage.js      # Implementación LocalStorage
│       │   └── firestore-storage.js  # Implementación Firestore SDK
│       ├── config.js         # Selector de backend ('local' o 'firebase')
│       └── app.js            # Controlador principal de la UI
└── tests/
    └── time.test.js          # Pruebas unitarias de cálculo temporal
```

---

## 4. Estrategia de Persistencia Desacoplada (Adapter Pattern)

El archivo `public/js/config.js` expone la configuración activa:
```javascript
export const CONFIG = {
  // 'local' para desarrollo sin cuenta; 'firebase' cuando se configuren credenciales
  STORAGE_BACKEND: 'local',
  FIREBASE_CONFIG: {
    // Pegar credenciales del proyecto de Firebase aquí cuando se cree
    apiKey: "",
    authDomain: "",
    projectId: "",
    storageBucket: "",
    messagingSenderId: "",
    appId: ""
  }
};
```
Esto permite al usuario probar la aplicación al 100% en su máquina hoy mismo y, cuando cree el proyecto en la consola de Firebase, bastará con pegar las credenciales y cambiar `STORAGE_BACKEND: 'firebase'`.
