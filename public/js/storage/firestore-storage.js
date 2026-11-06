/**
 * Adaptador de Persistencia Cloud Firestore (FirestoreAdapter)
 * 100% compatible con Firebase Spark Plan.
 * Utiliza persistencia local (IndexedDB) para minimizar lecturas y funcionar sin señal dentro del súper.
 */

import { StorageInterface } from './storage-interface.js';
import { crearLote, crearRegistroTrabajo } from '../domain/models.js';
import { calcularProximoDesbloqueo, calcularHorasTrabajadas } from '../domain/time.js';

export class FirestoreAdapter extends StorageInterface {
  constructor(firebaseConfig) {
    super();
    this.config = firebaseConfig;
    this.db = null;
    this.app = null;
    this.initialized = false;
  }

  async _init() {
    if (this.initialized) return;

    if (!this.config || !this.config.projectId || this.config.projectId === 'TU_PROJECT_ID') {
      throw new Error('Configuración de Firebase no válida. Define las credenciales en public/js/config.js');
    }

    try {
      // Importación dinámica del SDK modular v11 desde CDN oficial de Google
      const { initializeApp } = await import('https://www.gstatic.com/firebasejs/11.0.1/firebase-app.js');
      const {
        initializeFirestore,
        persistentLocalCache,
        persistentMultipleTabManager,
        collection,
        doc,
        getDocs,
        setDoc,
        addDoc,
        deleteDoc,
        query,
        where,
        orderBy
      } = await import('https://www.gstatic.com/firebasejs/11.0.1/firebase-firestore.js');

      this.app = initializeApp(this.config);
      
      // Inicializar Firestore con persistencia IndexedDB multi-pestaña para 0 lecturas innecesarias en Spark
      this.db = initializeFirestore(this.app, {
        localCache: persistentLocalCache({
          tabManager: persistentMultipleTabManager()
        })
      });

      this._firestore = {
        collection,
        doc,
        getDocs,
        setDoc,
        addDoc,
        deleteDoc,
        query,
        where,
        orderBy
      };

      this.initialized = true;
    } catch (err) {
      console.error('Error al inicializar Firebase Firestore SDK:', err);
      throw err;
    }
  }

  async obtenerLotes() {
    await this._init();
    const { collection, getDocs, query, where } = this._firestore;
    const ref = collection(this.db, 'lotes');
    const q = query(ref, where('activo', '==', true));
    const snapshot = await getDocs(q);

    const lotes = [];
    snapshot.forEach(docSnap => {
      lotes.push({ id: docSnap.id, ...docSnap.data() });
    });
    return lotes;
  }

  async guardarLote(datos) {
    await this._init();
    const lote = crearLote(datos);
    const { doc, setDoc } = this._firestore;
    const ref = doc(this.db, 'lotes', lote.id);
    await setDoc(ref, lote, { merge: true });
    return lote;
  }

  async eliminarLote(id) {
    await this._init();
    const { doc, updateDoc, setDoc } = this._firestore;
    const ref = doc(this.db, 'lotes', id);
    // Borrado lógico para conservar historial
    await setDoc(ref, { activo: false, updatedAt: new Date().toISOString() }, { merge: true });
    return true;
  }

  async obtenerRegistros(filtros = {}) {
    await this._init();
    const { collection, getDocs, query, orderBy } = this._firestore;
    const ref = collection(this.db, 'registros_trabajo');
    const q = query(ref, orderBy('fechaHoraInicio', 'desc'));
    const snapshot = await getDocs(q);

    const registros = [];
    snapshot.forEach(docSnap => {
      const data = docSnap.data();
      if (filtros.loteId && data.loteId !== filtros.loteId) return;
      if (filtros.supermercado && data.supermercado !== filtros.supermercado) return;
      registros.push({ id: docSnap.id, ...data });
    });
    return registros;
  }

  async registrarSesionTrabajo(datosSesion) {
    await this._init();
    const registro = crearRegistroTrabajo(datosSesion);
    const { collection, addDoc, doc, setDoc, getDocs, query, where } = this._firestore;

    // 1. Guardar en colección de registros
    const regRef = collection(this.db, 'registros_trabajo');
    const docCreated = await addDoc(regRef, registro);
    registro.id = docCreated.id;

    // 2. Actualizar o crear lote
    const lotesRef = collection(this.db, 'lotes');
    let loteId = registro.loteId;
    let loteActual = null;

    if (!loteId) {
      // Buscar si ya existe por combinación supermercado + área
      const q = query(lotesRef, 
        where('supermercado', '==', registro.supermercado),
        where('area', '==', registro.area)
      );
      const snap = await getDocs(q);
      if (!snap.empty) {
        loteId = snap.docs[0].id;
        loteActual = snap.docs[0].data();
      }
    }

    const proximoDesbloqueo = registro.desbloqueoCalculado;
    const duracion = calcularHorasTrabajadas(registro.fechaHoraInicio, registro.fechaHoraFin);

    if (loteId) {
      const loteDocRef = doc(this.db, 'lotes', loteId);
      const payload = {
        cantidadProductos: registro.cantidadProductos,
        ultimoInicio: registro.fechaHoraInicio,
        ultimoFin: registro.fechaHoraFin,
        duracionMinutos: duracion.minutos,
        proximoDesbloqueo,
        updatedAt: new Date().toISOString()
      };
      await setDoc(loteDocRef, payload, { merge: true });
      loteActual = { id: loteId, ...loteActual, ...payload };
    } else {
      const nuevoLote = crearLote({
        supermercado: registro.supermercado,
        area: registro.area,
        cantidadProductos: registro.cantidadProductos,
        ultimoInicio: registro.fechaHoraInicio,
        ultimoFin: registro.fechaHoraFin,
        duracionMinutos: duracion.minutos,
        proximoDesbloqueo
      });
      const nuevoRef = doc(this.db, 'lotes', nuevoLote.id);
      await setDoc(nuevoRef, nuevoLote);
      loteActual = nuevoLote;
    }

    return { lote: loteActual, registro };
  }
}
