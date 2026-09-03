import { useEffect, useState } from "react";
import pb from "../lib/pocketbase";
import { useAuth } from "../contexts/AuthContext";

const DB_NAME = "sdm-lms";
const STORE = "xapi_queue";
const DB_VERSION = 1;

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      req.result.createObjectStore(STORE, { keyPath: "_qid", autoIncrement: true });
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function addToOfflineQueue(statement: Record<string, unknown>): Promise<void> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.objectStore(STORE).add(statement);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

export async function getOfflineQueueCount(): Promise<number> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, "readonly");
    const req = tx.objectStore(STORE).count();
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export function useOfflineSync() {
  const { user } = useAuth();
  const [pendingCount, setPendingCount] = useState(0);
  const [isSyncing, setIsSyncing] = useState(false);

  const syncPending = async () => {
    if (!navigator.onLine || !user || isSyncing) return;
    setIsSyncing(true);
    try {
      const db = await openDB();
      const tx = db.transaction(STORE, "readwrite");
      const store = tx.objectStore(STORE);
      const keys: IDBValidKey[] = await new Promise((res, rej) => {
        const r = store.getAllKeys(); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error);
      });
      const records: Record<string, unknown>[] = await new Promise((res, rej) => {
        const r = store.getAll(); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error);
      });
      let synced = 0;
      for (let i = 0; i < records.length; i++) {
        try {
          const { _qid, ...stmt } = records[i];
          await pb.collection("xapi_statements").create(stmt);
          await new Promise<void>((res, rej) => {
            const delTx = db.transaction(STORE, "readwrite");
            const delReq = delTx.objectStore(STORE).delete(keys[i]);
            delReq.onsuccess = () => res();
            delReq.onerror = () => rej(delReq.error);
          });
          synced++;
        } catch { /* keep in queue */ }
      }
      setPendingCount(prev => Math.max(0, prev - synced));
    } finally {
      setIsSyncing(false);
    }
  };

  useEffect(() => {
    getOfflineQueueCount().then(setPendingCount).catch(() => {});
    window.addEventListener("online", syncPending);
    if (navigator.onLine) syncPending();
    return () => window.removeEventListener("online", syncPending);
  }, [user]);

  return { pendingCount, isSyncing, syncPending };
}
