import { Outlet, NavLink, Navigate } from "react-router-dom";
import { useState } from "react";
import { useChild } from "../contexts/ChildContext";
import { useLang } from "../contexts/LanguageContext";
import { useAuth } from "../contexts/AuthContext";
import ReminderBell from "./ReminderBell";
import AppLogo from "./AppLogo";
import ChatBot from "./ChatBot";
import pb from "../lib/pocketbase";

export default function Layout() {
  const { children, selectedChild, selectChild, loading } = useChild();
  const { user } = useAuth();
  const { t } = useLang();
  const [verifyDismissed, setVerifyDismissed] = useState(false);
  const [resendingVerify, setResendingVerify] = useState(false);
  const [verifySent, setVerifySent] = useState(false);
  const isUnverified = user && !user.verified && !verifyDismissed;

  const resendVerification = async () => {
    if (!user?.email) return;
    setResendingVerify(true);
    try {
      await pb.collection("users").requestVerification(String(user.email));
      setVerifySent(true);
      setTimeout(() => setVerifySent(false), 4000);
    } catch { /* ignore */ }
    finally { setResendingVerify(false); }
  };

  if (loading) return (
    <div className="flex items-center justify-center h-[100dvh] bg-cream bg-mesh">
      <div className="animate-spin rounded-full h-8 w-8 border-2 border-violet-500 border-t-transparent" />
    </div>
  );

  if (children.length === 0) return <Navigate to="/onboarding" replace />;

  const tabs = [
    { to: "/", icon: "🏠", label: t("navHome") },
    { to: "/track", icon: "📊", label: t("navTrack") },
    { to: "/content", icon: "📖", label: t("navLearn") },
    { to: "/profile", icon: "👤", label: t("navProfile") },
  ];

  return (
    <div className="h-[100dvh] bg-cream bg-mesh flex flex-col max-w-lg mx-auto relative overflow-hidden">
      {/* Header */}
      <header className="glass-header px-4 flex items-center justify-between shrink-0 z-30">
        <div className="flex items-center gap-2">
          <AppLogo size={36} className="drop-shadow-sm" />
          <div className="leading-none">
            <p className="text-gray-600 font-bold text-sm leading-tight">{t("appName")}</p>
            <p className="text-gray-400 text-[10px] leading-tight">{t("appNameAlt")}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <ReminderBell />
          {children.length > 1 ? (
            <select
              value={selectedChild?.id || ""}
              onChange={e => selectChild(e.target.value)}
              className="bg-white/60 text-gray-600 rounded-full px-3 py-1 text-sm border border-pink-200/60 outline-none">
              {children.map(c => (
                <option key={c.id} value={c.id} className="text-gray-700">{c.name}</option>
              ))}
            </select>
          ) : (
            <span className="text-gray-600 text-sm font-medium">{selectedChild?.name}</span>
          )}
        </div>
      </header>

      {/* Email verification banner */}
      {isUnverified && (
        <div className="shrink-0 flex items-center gap-2 px-4 py-2 bg-amber-50 border-b border-amber-100 z-20">
          <div className="flex-1 min-w-0">
            <p className="text-amber-800 text-xs font-semibold">Please verify your email</p>
            <button onClick={resendVerification} disabled={resendingVerify || verifySent}
              className="text-amber-600 text-[11px] underline underline-offset-1 disabled:no-underline transition-colors">
              {verifySent ? "Sent! Check your inbox" : resendingVerify ? "Sending..." : "Resend verification email"}
            </button>
          </div>
          <button onClick={() => setVerifyDismissed(true)} className="text-amber-400 hover:text-amber-600 text-lg shrink-0 leading-none">×</button>
        </div>
      )}

      {/* Scrollable content */}
      <main className="flex-1 overflow-y-auto min-h-0">
        <Outlet />
      </main>

      {/* AI Chatbot — floats above bottom nav */}
      <ChatBot />

      {/* Bottom nav — part of flex flow, no fixed positioning */}
      <nav className="glass-nav shrink-0 z-30">
        <div className="flex justify-around py-2">
          {tabs.map(tab => (
            <NavLink
              key={tab.to} to={tab.to} end={tab.to === "/"}
              className={({ isActive }) =>
                `flex flex-col items-center px-3 py-1 transition-all duration-200 ${
                  isActive ? "text-violet-600 scale-105" : "text-gray-400 hover:text-gray-600"
                }`
              }>
              <span className="text-xl">{tab.icon}</span>
              <span className="text-[11px] mt-0.5 font-semibold">{tab.label}</span>
            </NavLink>
          ))}
        </div>
      </nav>
    </div>
  );
}
