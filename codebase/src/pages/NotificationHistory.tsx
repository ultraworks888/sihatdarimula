import { useState, useEffect, useCallback } from "react";
import { useAuth } from "../contexts/AuthContext";
import { useLang } from "../contexts/LanguageContext";
import pb from "../lib/pocketbase";

interface HistoryItem {
  id: string;
  channel: string;
  type: string;
  status: string;
  phone: string;
  title: string;
  message: string;
  sent_at: string;
  created: string;
}

export default function NotificationHistory() {
  const { user } = useAuth();
  const { t } = useLang();
  const [items, setItems] = useState<HistoryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<"all" | "sms" | "whatsapp" | "in_app">("all");

  const fetchHistory = useCallback(async () => {
    if (!user) return;
    try {
      const filterStr = filter === "all"
        ? pb.filter("user = {:uid}", { uid: user.id })
        : pb.filter("user = {:uid} && channel = {:ch}", { uid: user.id, ch: filter });

      const result = await pb.collection("notification_queue").getList(1, 50, {
        filter: filterStr,
        sort: "-created",
        requestKey: null,
      });
      setItems(result.items.map(r => ({
        id: r.id,
        channel: String(r["channel"]),
        type: String(r["type"]),
        status: String(r["status"]),
        phone: String(r["phone"] ?? ""),
        title: String(r["title"] ?? ""),
        message: String(r["message"] ?? ""),
        sent_at: String(r["sent_at"] ?? ""),
        created: String(r["created"] ?? ""),
      })));
    } catch {
      // May be empty
    } finally {
      setLoading(false);
    }
  }, [user, filter]);

  useEffect(() => { fetchHistory(); }, [fetchHistory]);

  const channelIcon = (ch: string) => {
    if (ch === "sms") return "💬";
    if (ch === "whatsapp") return "📱";
    return "🔔";
  };

  const channelLabel = (ch: string) => {
    if (ch === "sms") return "SMS";
    if (ch === "whatsapp") return "WhatsApp";
    return t("inAppNotifications");
  };

  const statusStyle = (s: string) => {
    if (s === "sent") return { bg: "bg-emerald-500/15", text: "text-emerald-700", label: t("statusSent") };
    if (s === "failed") return { bg: "bg-rose-500/15", text: "text-rose-700", label: t("statusFailed") };
    if (s === "pending") return { bg: "bg-amber-500/15", text: "text-amber-700", label: t("statusPending") };
    return { bg: "bg-gray-500/15", text: "text-gray-700", label: t("statusCancelled") };
  };

  const typeLabel = (tp: string) => {
    const map: Record<string, string> = {
      vaccine_reminder: t("notifVaccineReminders"),
      content_update: t("notifContentUpdates"),
      growth_reminder: t("notifGrowthReminders"),
      feeding_reminder: t("notifFeedingReminders"),
      otp: "OTP",
    };
    return map[tp] || tp;
  };

  const formatDate = (dateStr: string) => {
    if (!dateStr) return "—";
    const d = new Date(dateStr);
    return d.toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });
  };

  const filters: { key: typeof filter; icon: string; label: string }[] = [
    { key: "all", icon: "📋", label: t("all") },
    { key: "sms", icon: "💬", label: "SMS" },
    { key: "whatsapp", icon: "📱", label: "WhatsApp" },
    { key: "in_app", icon: "🔔", label: t("inAppNotifications") },
  ];

  if (loading) return (
    <div className="flex items-center justify-center py-16">
      <div className="animate-spin rounded-full h-6 w-6 border-2 border-violet-500 border-t-transparent" />
    </div>
  );

  return (
    <div className="p-4 space-y-4 fade-up">
      {/* Header */}
      <div className="glass-strong rounded-3xl p-4">
        <h2 className="font-bold text-gray-800 text-lg">{t("messageHistory")}</h2>
        <p className="text-gray-500 text-xs mt-0.5">{t("messageHistoryDesc")}</p>
      </div>

      {/* Filter tabs */}
      <div className="flex gap-1.5 overflow-x-auto pb-1 -mx-1 px-1">
        {filters.map(f => (
          <button key={f.key} onClick={() => setFilter(f.key)}
            className={`flex items-center gap-1.5 px-3 py-2 rounded-2xl text-xs font-semibold whitespace-nowrap transition-all duration-200 ${
              filter === f.key ? "glass-btn text-white" : "glass text-gray-500 hover:text-gray-700"
            }`}>
            <span>{f.icon}</span> {f.label}
          </button>
        ))}
      </div>

      {/* List */}
      {items.length === 0 ? (
        <div className="glass rounded-3xl p-8 text-center">
          <span className="text-4xl">📭</span>
          <p className="text-gray-500 text-sm mt-3">{t("noMessageHistory")}</p>
          <p className="text-gray-400 text-xs mt-1">{t("noMessageHistoryDesc")}</p>
        </div>
      ) : (
        <div className="space-y-2">
          {items.map(item => {
            const st = statusStyle(item.status);
            return (
              <div key={item.id} className="glass rounded-2xl p-4 transition-all hover:scale-[1.01] duration-200">
                <div className="flex items-start gap-3">
                  {/* Channel icon */}
                  <div className="w-10 h-10 glass-strong rounded-xl flex items-center justify-center text-lg shrink-0">
                    {channelIcon(item.channel)}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-sm font-bold text-gray-800">{item.title || typeLabel(item.type)}</span>
                      <span className={`${st.bg} ${st.text} text-[10px] font-bold px-2 py-0.5 rounded-full`}>
                        {st.label}
                      </span>
                    </div>
                    <p className="text-xs text-gray-600 mt-1 line-clamp-2">{item.message}</p>
                    <div className="flex items-center gap-3 mt-2 text-[10px] text-gray-400">
                      <span>{channelLabel(item.channel)}</span>
                      {item.phone && <span>🇲🇾 {item.phone}</span>}
                      <span>{formatDate(item.sent_at || item.created)}</span>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
