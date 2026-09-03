import { useState, useEffect, useCallback } from "react";
import { useAuth } from "../contexts/AuthContext";
import { useLang } from "../contexts/LanguageContext";
import pb from "../lib/pocketbase";
import { usePushNotifications } from "../hooks/usePushNotifications";

interface Prefs {
  id?: string;
  sms_enabled: boolean;
  whatsapp_enabled: boolean;
  in_app_enabled: boolean;
  vaccine_reminders: boolean;
  content_updates: boolean;
  growth_reminders: boolean;
  feeding_reminders: boolean;
}

const defaults: Prefs = {
  sms_enabled: true,
  whatsapp_enabled: true,
  in_app_enabled: true,
  vaccine_reminders: true,
  content_updates: true,
  growth_reminders: true,
  feeding_reminders: false,
};

export default function NotificationSettings() {
  const { user } = useAuth();
  const { t } = useLang();
  const push = usePushNotifications();
  const [prefs, setPrefs] = useState<Prefs>(defaults);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  const fetchPrefs = useCallback(async () => {
    if (!user) return;
    try {
      const result = await pb.collection("notification_preferences").getFirstListItem(
        pb.filter("user = {:uid}", { uid: user.id }),
        { requestKey: null }
      );
      setPrefs({
        id: result.id,
        sms_enabled: Boolean(result["sms_enabled"]),
        whatsapp_enabled: Boolean(result["whatsapp_enabled"]),
        in_app_enabled: Boolean(result["in_app_enabled"]),
        vaccine_reminders: Boolean(result["vaccine_reminders"]),
        content_updates: Boolean(result["content_updates"]),
        growth_reminders: Boolean(result["growth_reminders"]),
        feeding_reminders: Boolean(result["feeding_reminders"]),
      });
    } catch {
      // defaults
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => { fetchPrefs(); }, [fetchPrefs]);

  const savePrefs = async (updated: Prefs) => {
    if (!user) return;
    setSaving(true);
    setSaved(false);
    try {
      const data = {
        user: user.id,
        sms_enabled: updated.sms_enabled,
        whatsapp_enabled: updated.whatsapp_enabled,
        in_app_enabled: updated.in_app_enabled,
        vaccine_reminders: updated.vaccine_reminders,
        content_updates: updated.content_updates,
        growth_reminders: updated.growth_reminders,
        feeding_reminders: updated.feeding_reminders,
      };
      if (updated.id) {
        await pb.collection("notification_preferences").update(updated.id, data);
      } else {
        const created = await pb.collection("notification_preferences").create(data);
        setPrefs(prev => ({ ...prev, id: created.id }));
      }
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    } catch {} finally {
      setSaving(false);
    }
  };

  const toggle = (key: keyof Prefs) => {
    const updated = { ...prefs, [key]: !prefs[key] };
    setPrefs(updated);
    savePrefs(updated);
  };

  if (loading) return (
    <div className="flex items-center justify-center py-12">
      <div className="animate-spin rounded-full h-6 w-6 border-2 border-violet-500 border-t-transparent" />
    </div>
  );

  const channels: { key: keyof Prefs; icon: string; label: string; desc: string }[] = [
    { key: "sms_enabled", icon: "💬", label: t("smsNotifications"), desc: t("smsDesc") },
    { key: "whatsapp_enabled", icon: "📱", label: t("whatsappNotifications"), desc: t("whatsappDesc") },
    { key: "in_app_enabled", icon: "🔔", label: t("inAppNotifications"), desc: t("inAppDesc") },
  ];

  const types: { key: keyof Prefs; icon: string; label: string; desc: string }[] = [
    { key: "vaccine_reminders", icon: "💉", label: t("notifVaccineReminders"), desc: t("notifVaccineDesc") },
    { key: "content_updates", icon: "📰", label: t("notifContentUpdates"), desc: t("notifContentDesc") },
    { key: "growth_reminders", icon: "📏", label: t("notifGrowthReminders"), desc: t("notifGrowthDesc") },
    { key: "feeding_reminders", icon: "🍼", label: t("notifFeedingReminders"), desc: t("notifFeedingDesc") },
  ];

  const Toggle = ({ active, onToggle }: { active: boolean; onToggle: () => void }) => (
    <button onClick={onToggle} disabled={saving}
      className={`glass-toggle w-12 h-7 rounded-full p-0.5 shrink-0 ${active ? "active" : ""}`}>
      <div className={`knob w-6 h-6 rounded-full ${active ? "translate-x-5" : "translate-x-0"}`} />
    </button>
  );

  return (
    <div className="p-4 space-y-5 fade-up">
      {/* Channels */}
      <div className="glass-strong rounded-3xl p-4">
        <h3 className="font-bold text-gray-800 mb-1">{t("notifChannels")}</h3>
        <p className="text-xs text-gray-400 mb-3">{user?.phone ? `🇲🇾 ${user.phone}` : ""}</p>
        <div className="space-y-4">
          {channels.map(ch => (
            <div key={ch.key} className="flex items-center justify-between gap-3">
              <div className="flex items-start gap-3 min-w-0">
                <span className="text-xl shrink-0 mt-0.5">{ch.icon}</span>
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-gray-800">{ch.label}</p>
                  <p className="text-xs text-gray-400">{ch.desc}</p>
                </div>
              </div>
              <Toggle active={!!prefs[ch.key]} onToggle={() => toggle(ch.key)} />
            </div>
          ))}
        </div>
      </div>

      {/* Push notifications */}
      <div className="glass-strong rounded-3xl p-4 space-y-3">
        <div className="flex items-start gap-3">
          <span className="text-2xl shrink-0">📲</span>
          <div className="flex-1 min-w-0">
            <h3 className="font-bold text-gray-800 text-sm">Native Push Notifications</h3>
            <p className="text-xs text-gray-400 mt-0.5 leading-relaxed">
              Receive alerts directly on your phone screen — even when the app is closed. Works on Android and iOS 16.4+.
            </p>
          </div>
        </div>

        {push.state === "unsupported" && (
          <div className="rounded-2xl bg-gray-100 px-3 py-2 text-xs text-gray-500">
            ⚠️ Your browser does not support push notifications. Try Chrome on Android or Safari on iOS 16.4+.
          </div>
        )}

        {push.state === "needs_vapid" && (
          <div className="rounded-2xl bg-amber-50 border border-amber-200/60 px-3 py-2 text-xs text-amber-700 leading-relaxed">
            🔑 Push notifications require a VAPID key to be configured by your admin. Generate one with{" "}
            <code className="font-mono bg-amber-100 px-1 rounded">npx web-push generate-vapid-keys</code> and add the public key as{" "}
            <code className="font-mono bg-amber-100 px-1 rounded">VITE_VAPID_PUBLIC_KEY</code> in your environment.
          </div>
        )}

        {push.state === "denied" && (
          <div className="rounded-2xl bg-rose-50 border border-rose-200/60 px-3 py-2 text-xs text-rose-700">
            🚫 Notifications are blocked. Go to your browser or phone Settings → Notifications to re-enable them for this app.
          </div>
        )}

        {(push.state === "default" || push.state === "subscribed") && (
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-xs text-gray-500">
                {push.state === "subscribed"
                  ? "✅ This device is receiving push notifications"
                  : "Enable to receive alerts on this device"}
              </span>
              <button
                onClick={push.state === "subscribed" ? push.unsubscribe : push.subscribe}
                className={`px-4 py-1.5 rounded-full text-xs font-bold transition-all ${
                  push.state === "subscribed"
                    ? "bg-gray-100 text-gray-500 hover:bg-rose-50 hover:text-rose-600"
                    : "glass-btn text-white"
                }`}>
                {push.state === "subscribed" ? "Disable" : "Enable"}
              </button>
            </div>
            {push.state === "default" && /iphone|ipad|ipod/i.test(navigator.userAgent) && (
              <p className="text-[11px] text-amber-600 bg-amber-50 rounded-xl px-3 py-2 leading-relaxed">
                📌 <strong>iOS tip:</strong> For push notifications to work, first tap <strong>Share → Add to Home Screen</strong> in Safari, then open the app from your home screen and enable notifications here.
              </p>
            )}
          </div>
        )}

        {push.state === "loading" && (
          <div className="flex items-center gap-2 text-xs text-gray-400">
            <div className="animate-spin rounded-full h-4 w-4 border-2 border-violet-400 border-t-transparent" />
            Setting up push notifications…
          </div>
        )}
      </div>

      {/* Types — 2×2 grid */}
      <div className="glass rounded-3xl p-4">
        <h3 className="font-bold text-gray-800 mb-3">{t("notifTypes")}</h3>
        <div className="grid grid-cols-2 gap-3">
          {types.map(tp => (
            <div key={tp.key} className="rounded-2xl bg-white/60 border border-gray-100 p-3 flex flex-col gap-2">
              <div className="flex items-center justify-between">
                <span className="text-xl">{tp.icon}</span>
                <Toggle active={!!prefs[tp.key]} onToggle={() => toggle(tp.key)} />
              </div>
              <div>
                <p className="text-sm font-semibold text-gray-800 leading-tight">{tp.label}</p>
                <p className="text-[11px] text-gray-400 leading-snug mt-0.5">{tp.desc}</p>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Brevo status */}
      <div className="glass rounded-3xl p-4 !border-emerald-200/40">
        <div className="flex items-start gap-3">
          <span className="text-xl shrink-0">🔗</span>
          <div>
            <h4 className="font-bold text-emerald-800 text-sm">{t("brevoIntegration")}</h4>
            <p className="text-gray-600 text-xs mt-1 leading-relaxed">{t("brevoReady")}</p>
          </div>
        </div>
      </div>

      {saved && (
        <div className="fixed top-4 left-1/2 -translate-x-1/2 glass-strong px-4 py-2 rounded-full text-sm font-semibold shadow-lg animate-in z-50 text-emerald-700">
          ✓ {t("prefsSaved")}
        </div>
      )}
    </div>
  );
}
