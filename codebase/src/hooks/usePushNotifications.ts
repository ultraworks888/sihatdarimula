import { useState, useEffect } from "react";
import pb from "../lib/pocketbase";
import { useAuth } from "../contexts/AuthContext";

/* ─────────────────────────────────────────────────────────────────────────────
   VAPID public key — safe to embed in client code (it is public by design).
   Only the private key must remain secret (it lives in push-server/.env only).
───────────────────────────────────────────────────────────────────────────── */
const VAPID_PUBLIC_KEY =
  import.meta.env.VITE_VAPID_PUBLIC_KEY ||
  "BMOTABcGz7YRycc2rhwpONmjHD3N6VbxO1j2HrK2VmbfPf5ZPHpXIYI9ePkTK-hls028Z4WKpJEP_oWiIXalhT0";

function urlBase64ToUint8Array(base64: string): Uint8Array {
  const padding = "=".repeat((4 - (base64.length % 4)) % 4);
  const b64 = (base64 + padding).replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(b64);
  return Uint8Array.from(raw, (c) => c.charCodeAt(0));
}

function detectPlatform(): "android" | "ios" | "desktop" | "unknown" {
  const ua = navigator.userAgent;
  if (/android/i.test(ua)) return "android";
  if (/ipad|iphone|ipod/i.test(ua)) return "ios";
  if (/macintosh|windows|linux/i.test(ua)) return "desktop";
  return "unknown";
}

export type PushState =
  | "unsupported"   // browser has no Push API
  | "needs_vapid"   // VAPID key not configured yet
  | "default"       // supported, permission not yet asked
  | "denied"        // user blocked notifications
  | "subscribed"    // actively subscribed
  | "loading";      // async operation in progress

export function usePushNotifications() {
  const { user } = useAuth();
  const [state, setState] = useState<PushState>("loading");
  const [existingSubId, setExistingSubId] = useState<string | null>(null);

  /* ── Detect initial support & permission on mount ── */
  useEffect(() => {
    if (!("serviceWorker" in navigator) || !("PushManager" in window) || !("Notification" in window)) {
      setState("unsupported");
      return;
    }
    if (Notification.permission === "denied") {
      setState("denied");
      return;
    }

    /* Check if already subscribed */
    navigator.serviceWorker.ready.then(async (reg) => {
      const sub = await reg.pushManager.getSubscription();
      if (sub) {
        setState("subscribed");
        /* Try to find the matching DB record for later deletion */
        if (user) {
          try {
            const record = await pb.collection("push_subscriptions").getFirstListItem(
              pb.filter("user = {:uid} && endpoint = {:ep}", { uid: user.id, ep: sub.endpoint }),
              { requestKey: null }
            );
            setExistingSubId(record.id);
          } catch { /* not in DB yet — that's fine */ }
        }
      } else {
        setState(Notification.permission === "granted" ? "default" : "default");
      }
    }).catch(() => setState("default"));
  }, [user]);

  /* ── Subscribe ── */
  const subscribe = async (): Promise<boolean> => {
    if (!user || state === "unsupported" || state === "needs_vapid") return false;
    setState("loading");
    try {
      const permission = await Notification.requestPermission();
      if (permission !== "granted") {
        setState("denied");
        return false;
      }

      const reg = await navigator.serviceWorker.ready;
      let sub = await reg.pushManager.getSubscription();
      if (!sub) {
        sub = await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
        });
      }

      const json = sub.toJSON() as {
        endpoint: string;
        keys?: { p256dh?: string; auth?: string };
      };

      const record = await pb.collection("push_subscriptions").create({
        user:       user.id,
        endpoint:   json.endpoint,
        p256dh:     json.keys?.p256dh   ?? "",
        auth:       json.keys?.auth     ?? "",
        user_agent: navigator.userAgent,
        platform:   detectPlatform(),
      });
      setExistingSubId(record.id);
      setState("subscribed");
      return true;
    } catch (e) {
      console.error("Push subscribe failed:", e);
      setState("default");
      return false;
    }
  };

  /* ── Unsubscribe ── */
  const unsubscribe = async (): Promise<void> => {
    setState("loading");
    try {
      const reg = await navigator.serviceWorker.ready;
      const sub = await reg.pushManager.getSubscription();
      if (sub) await sub.unsubscribe();
      if (existingSubId) {
        await pb.collection("push_subscriptions").delete(existingSubId);
        setExistingSubId(null);
      }
      setState("default");
    } catch (e) {
      console.error("Push unsubscribe failed:", e);
      setState("subscribed");
    }
  };

  return { state, subscribe, unsubscribe };
}
