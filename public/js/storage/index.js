/**
 * Factoría de Almacenamiento
 * Instancia y expone el almacenamiento configurado (Local o Firebase).
 */

import { CONFIG } from '../config.js';
import { LocalStorageAdapter } from './local-storage.js';
import { FirestoreAdapter } from './firestore-storage.js';

let storageInstancia = null;

export function getStorage() {
  if (!storageInstancia) {
    if (CONFIG.STORAGE_BACKEND === 'firebase') {
      console.log('🔌 Conectando a Firebase Cloud Firestore (Plan Spark)...');
      storageInstancia = new FirestoreAdapter(CONFIG.FIREBASE_CONFIG);
    } else {
      console.log('💾 Usando almacenamiento Local (LocalStorageAdapter)');
      storageInstancia = new LocalStorageAdapter();
    }
  }
  return storageInstancia;
}
