import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'

/**
 * Suppress the benign "ResizeObserver loop completed with undelivered notifications"
 * browser warning. This fires when react-player (or any dynamically-sized element)
 * triggers a layout change mid-observation cycle. It is harmless and does not
 * affect functionality — suppressing it prevents noise in the error overlay.
 */
const _nativeError = window.onerror;
window.onerror = (msg, src, line, col, err) => {
  if (typeof msg === 'string' && msg.includes('ResizeObserver loop')) return true;
  return _nativeError ? _nativeError(msg, src, line, col, err) : false;
};
window.addEventListener('error', (e) => {
  if (e.message?.includes('ResizeObserver loop')) e.stopImmediatePropagation();
}, true);

/* ── Register Service Worker (push notifications + offline) ── */
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker
      .register("/sw.js", { scope: "/" })
      .catch((err) => console.warn("SW registration failed:", err));
  });
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
