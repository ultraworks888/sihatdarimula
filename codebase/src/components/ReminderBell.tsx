import { useState, useEffect, useCallback, useRef } from "react";
import pb from "../lib/pocketbase";
import { useChild } from "../contexts/ChildContext";
import { useAuth } from "../contexts/AuthContext";
import { useLang } from "../contexts/LanguageContext";
import { useVaccineReminders, type ChildForReminder } from "../hooks/useVaccineReminders";

interface InAppNotif {
  id: string;
  type: string;
  title: string;
  message: string;
  is_read: boolean;
  created: string;
}

export default function ReminderBell() {
  const { user } = useAuth();
  const { children } = useChild();
  const { t } = useLang();
  const [completedMap, setCompletedMap] = useState<Record<string, Set<string>>>({});
  const [inAppNotifs, setInAppNotifs] = useState<InAppNotif[]>([]);
  const [open, setOpen] = useState(false);
  const [tab, setTab] = useState<"reminders" | "notifications">("reminders");
  const panelRef = useRef<HTMLDivElement>(null);

  const fetchCompleted = useCallback(async () => {
    if (!user || children.length === 0) return;
    const result = await pb.collection("immunisations").getFullList({
      filter: pb.filter("user = {:uid} && is_completed = true", { uid: user.id }),
      fields: "child,vaccine_name",
      requestKey: null,
    });
    const map: Record<string, Set<string>> = {};
    for (const r of result) {
      const cid = String(r["child"]);
      if (!map[cid]) map[cid] = new Set();
      map[cid].add(String(r["vaccine_name"]));
    }
    setCompletedMap(map);
  }, [user, children]);

  const fetchNotifs = useCallback(async () => {
    if (!user) return;
    try {
      const result = await pb.collection("notifications").getList(1, 20, {
        filter: pb.filter("user = {:uid}", { uid: user.id }),
        sort: "-created",
        requestKey: null,
      });
      setInAppNotifs(result.items.map(r => ({
        id: r.id,
        type: String(r["type"]),
        title: String(r["title"]),
        message: String(r["message"]),
        is_read: Boolean(r["is_read"]),
        created: String(r["created"]),
      })));
    } catch {}
  }, [user]);

  useEffect(() => { fetchCompleted(); fetchNotifs(); }, [fetchCompleted, fetchNotifs]);

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (panelRef.current && !panelRef.current.contains(e.target as Node)) setOpen(false);
    };
    if (open) document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [open]);

  const markAllRead = async () => {
    const unread = inAppNotifs.filter(n => !n.is_read);
    for (const n of unread) {
      await pb.collection("notifications").update(n.id, { is_read: true });
    }
    setInAppNotifs(prev => prev.map(n => ({ ...n, is_read: true })));
  };

  const childrenForReminder: ChildForReminder[] = children.map(c => ({
    id: c.id, name: c.name, date_of_birth: c.date_of_birth, is_born: c.is_born,
  }));

  const reminders = useVaccineReminders(childrenForReminder, completedMap);
  const urgentCount = reminders.filter(r => r.status === "overdue" || r.status === "due_soon").length;
  const unreadCount = inAppNotifs.filter(n => !n.is_read).length;
  const totalBadge = urgentCount + unreadCount;

  const statusColors = {
    overdue: { bg: "bg-rose-500/10", text: "text-rose-700", badge: "bg-rose-500", label: t("overdueLabel") },
    due_soon: { bg: "bg-amber-500/10", text: "text-amber-700", badge: "bg-amber-500", label: t("dueSoonLabel") },
    upcoming: { bg: "bg-blue-500/10", text: "text-blue-700", badge: "bg-blue-500", label: t("upcomingLabel") },
  };

  const typeIcons: Record<string, string> = {
    vaccine_reminder: "💉", content_update: "📰", growth_reminder: "📏",
    feeding_reminder: "🍼", system: "ℹ️",
  };

  return (
    <div className="relative" ref={panelRef}>
      <button onClick={() => setOpen(!open)}
        className="relative w-9 h-9 flex items-center justify-center rounded-xl bg-white/60 backdrop-blur-md hover:bg-pink-50 transition-all border border-pink-200/50">
        <span className="text-lg">🔔</span>
        {totalBadge > 0 && (
          <span className="absolute -top-1 -right-1 w-5 h-5 bg-rose-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center animate-pulse shadow-md">
            {totalBadge > 9 ? "9+" : totalBadge}
          </span>
        )}
      </button>

      {open && (
        <div className="absolute right-0 top-11 w-80 max-h-[28rem] glass-strong rounded-3xl overflow-hidden z-50 animate-in shadow-2xl">
          {/* Tabs */}
          <div className="flex border-b border-white/20">
            <button onClick={() => setTab("reminders")}
              className={`flex-1 py-3 text-xs font-bold transition-all ${tab === "reminders" ? "text-violet-600 border-b-2 border-violet-500" : "text-gray-400"}`}>
              💉 {t("vaccineReminders")} {urgentCount > 0 && <span className="bg-rose-500 text-white text-[10px] px-1.5 py-0.5 rounded-full ml-1">{urgentCount}</span>}
            </button>
            <button onClick={() => setTab("notifications")}
              className={`flex-1 py-3 text-xs font-bold transition-all ${tab === "notifications" ? "text-violet-600 border-b-2 border-violet-500" : "text-gray-400"}`}>
              📬 {t("notifications")} {unreadCount > 0 && <span className="bg-violet-500 text-white text-[10px] px-1.5 py-0.5 rounded-full ml-1">{unreadCount}</span>}
            </button>
          </div>

          <div className="overflow-y-auto max-h-80">
            {tab === "reminders" && (
              <div className="p-2.5 space-y-2">
                {reminders.length === 0 ? (
                  <div className="text-center py-6">
                    <span className="text-3xl">🎉</span>
                    <p className="text-gray-500 text-sm mt-2">{t("allVaccinesUpToDate")}</p>
                  </div>
                ) : reminders.map((r, i) => {
                  const s = statusColors[r.status];
                  return (
                    <div key={`${r.childId}-${r.name}-${i}`} className={`${s.bg} rounded-2xl p-3 backdrop-blur-sm`}>
                      <div className="flex items-start justify-between gap-2">
                        <div className="min-w-0">
                          <p className={`text-sm font-bold ${s.text}`}>{r.name}</p>
                          <p className="text-xs text-gray-500 mt-0.5">{r.childName} · {r.description}</p>
                        </div>
                        <span className={`${s.badge} text-white text-[10px] font-bold px-2 py-0.5 rounded-full shrink-0`}>{s.label}</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}

            {tab === "notifications" && (
              <div className="p-2.5 space-y-2">
                {inAppNotifs.length > 0 && unreadCount > 0 && (
                  <button onClick={markAllRead} className="text-xs text-violet-600 font-semibold px-2 py-1 hover:underline">
                    {t("markAllRead")}
                  </button>
                )}
                {inAppNotifs.length === 0 ? (
                  <div className="text-center py-6">
                    <span className="text-3xl">📭</span>
                    <p className="text-gray-500 text-sm mt-2">{t("noNotifications")}</p>
                  </div>
                ) : inAppNotifs.map(n => (
                  <div key={n.id} className={`rounded-2xl p-3 ${n.is_read ? "bg-gray-500/5" : "bg-violet-500/10"}`}>
                    <div className="flex items-start gap-2">
                      <span className="text-lg shrink-0">{typeIcons[n.type] || "📌"}</span>
                      <div className="min-w-0">
                        <p className={`text-sm font-semibold ${n.is_read ? "text-gray-600" : "text-gray-800"}`}>{n.title}</p>
                        <p className="text-xs text-gray-500 mt-0.5 line-clamp-2">{n.message}</p>
                        <p className="text-[10px] text-gray-400 mt-1">{new Date(n.created).toLocaleDateString()}</p>
                      </div>
                      {!n.is_read && <span className="w-2 h-2 bg-violet-500 rounded-full shrink-0 mt-1.5" />}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
