/**
 * Configuración del Entorno de Persistencia
 * 
 * Modos disponibles:
 * - 'local': Almacenamiento en LocalStorage (ideal para desarrollo y uso offline inmediato sin setup).
 * - 'firebase': Conexión con Google Cloud Firestore en Plan Spark.
 */

export const CONFIG = {
  STORAGE_BACKEND: 'local', // Cambiar a 'firebase' una vez configuradas las credenciales de abajo

  // Pega aquí la configuración obtenida desde la Consola de Firebase cuando crees el proyecto:
  FIREBASE_CONFIG: {
    apiKey: "TU_API_KEY",
    authDomain: "TU_PROYECTO.firebaseapp.com",
    projectId: "TU_PROJECT_ID",
    storageBucket: "TU_PROYECTO.firebasestorage.app",
    messagingSenderId: "TU_SENDER_ID",
    appId: "TU_APP_ID"
  }
};
