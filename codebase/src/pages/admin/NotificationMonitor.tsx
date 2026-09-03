import { useState, useEffect, useCallback } from "react";
import pb from "../../lib/pocketbase";

interface QueueItem {
  id: string; channel: string; type: string; status: string;
  phone: string; title: string; message: string;
  scheduled_at: string; sent_at: string; created: string;
  error_message: string; expand?: { user?: { name: string; email: string } };
}

const statusStyle: Record<string, string> = {
  pending: "bg-amber-500/15 text-amber-300 border-amber-500/20",
  sent: "bg-emerald-500/15 text-emerald-300 border-emerald-500/20",
  failed: "bg-rose-500/15 text-rose-300 border-rose-500/20",
  cancelled: "bg-gray-500/15 text-gray-400 border-gray-500/20",
};
const channelIcon: Record<string, string> = { sms: "💬", whatsapp: "📱", in_app: "🔔" };
const typeIcon: Record<string, string> = {
  vaccine_reminder: "💉", content_update: "📰",
  growth_reminder: "📏", feeding_reminder: "🍼", otp: "🔑",
};

export default function AdminNotifications() {
  const [items, setItems] = useState<QueueItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState("all");
  const [channelFilter, setChannelFilter] = useState("all");
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState<string | null>(null);

  const fetch_ = useCallback(async () => {
    setLoading(true);
    try {
      const filters: string[] = [];
      if (statusFilter !== "all") filters.push(`status = "${statusFilter}"`);
      if (channelFilter !== "all") filters.push(`channel = "${channelFilter}"`);
      const result = await pb.collection("notification_queue").getList(page, 25, {
        filter: filters.join(" && ") || "",
        sort: "-created",
        expand: "user",
        requestKey: null,
      });
      setItems(result.items.map(r => ({
        id: String(r.id), channel: String(r.channel ?? ""), type: String(r.type ?? ""),
        status: String(r.status ?? ""), phone: String(r.phone ?? ""),
        title: String(r.title ?? ""), message: String(r.message ?? ""),
        scheduled_at: String(r.scheduled_at ?? ""), sent_at: String(r.sent_at ?? ""),
        created: String(r.created ?? ""), error_message: String(r.error_message ?? ""),
        expand: r.expand as QueueItem["expand"],
      })));
      setTotal(result.totalItems);
    } finally { setLoading(false); }
  }, [page, statusFilter, channelFilter]);

  useEffect(() => { fetch_(); }, [fetch_]);

  const formatDate = (d: string) => d ? new Date(d).toLocaleString(undefined, { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" }) : "—";
  const totalPages = Math.ceil(total / 25);

  const summary = [
    { label: "All", value: "all", count: null },
    { label: "Pending ⏳", value: "pending", count: null },
    { label: "Sent ✅", value: "sent", count: null },
    { label: "Failed ❌", value: "failed", count: null },
  ];

  return (
    <div className="space-y-5 fade-up">
      <div>
        <h1 className="text-white text-2xl font-bold">Notification Queue</h1>
        <p className="text-white/40 text-sm mt-0.5">{total} total entries · Brevo worker monitor</p>
      </div>

      {/* Filters */}
      <div className="flex gap-2 flex-wrap">
        <div className="flex gap-1 rounded-xl p-1 border border-white/10" style={{ background: "rgba(255,255,255,0.03)" }}>
          {summary.map(s => (
            <button key={s.value} onClick={() => { setStatusFilter(s.value); setPage(1); }}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${statusFilter === s.value ? "bg-violet-600/40 text-violet-300" : "text-white/30 hover:text-white/50"}`}>
              {s.label}
            </button>
          ))}
        </div>
        <select value={channelFilter} onChange={e => { setChannelFilter(e.target.value); setPage(1); }}
          className="px-3 py-2 rounded-xl text-xs text-white/60 outline-none border border-white/10 bg-white/[0.04]">
          <option value="all">All channels</option>
          <option value="sms">💬 SMS</option>
          <option value="whatsapp">📱 WhatsApp</option>
          <option value="in_app">🔔 In-App</option>
        </select>
        <button onClick={() => fetch_()}
          className="px-3 py-2 rounded-xl text-xs text-white/40 border border-white/10 hover:border-white/20 hover:text-white/60 transition-all">
          ↻ Refresh
        </button>
      </div>

      {/* Queue list */}
      <div className="rounded-2xl border border-white/5 overflow-hidden" style={{ background: "rgba(255,255,255,0.02)" }}>
        {loading ? (
          <div className="flex justify-center py-12"><div className="animate-spin rounded-full h-6 w-6 border-2 border-violet-500 border-t-transparent" /></div>
        ) : items.length === 0 ? (
          <div className="text-center py-12">
            <p className="text-4xl mb-3">📭</p>
            <p className="text-white/30 text-sm">No notifications in queue</p>
          </div>
        ) : (
          <div className="divide-y divide-white/5">
            {items.map(item => (
              <div key={item.id}>
                <button className="w-full flex items-start gap-4 px-5 py-4 hover:bg-white/[0.02] transition-colors text-left"
                  onClick={() => setExpanded(expanded === item.id ? null : item.id)}>
                  {/* Channel icon */}
                  <div className="w-9 h-9 rounded-xl flex items-center justify-center text-lg shrink-0 bg-white/5">
                    {channelIcon[item.channel] ?? "📌"}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap mb-0.5">
                      <span className="text-white/70 text-sm font-semibold">{item.title || item.type}</span>
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full border ${statusStyle[item.status] ?? ""}`}>
                        {item.status}
                      </span>
                      <span className="text-white/25 text-[10px]">{typeIcon[item.type] ?? "📌"} {item.type}</span>
                    </div>
                    <p className="text-white/30 text-xs line-clamp-1">{item.message}</p>
                    <div className="flex gap-3 mt-1 text-[10px] text-white/20">
                      {item.expand?.user && <span>👤 {item.expand.user.name || item.expand.user.email}</span>}
                      {item.phone && <span>🇲🇾 {item.phone}</span>}
                      <span>📅 {formatDate(item.created)}</span>
                      {item.sent_at && <span>✅ {formatDate(item.sent_at)}</span>}
                    </div>
                  </div>
                  <span className="text-white/20 text-sm shrink-0 mt-1">{expanded === item.id ? "▲" : "▼"}</span>
                </button>

                {/* Expanded detail */}
                {expanded === item.id && (
                  <div className="px-5 pb-4 ml-13 space-y-2 border-t border-white/5 pt-3">
                    <div className="rounded-xl p-3 space-y-2 text-xs" style={{ background: "rgba(255,255,255,0.03)" }}>
                      <div className="grid grid-cols-2 gap-x-6 gap-y-1">
                        <p><span className="text-white/30">Channel:</span> <span className="text-white/60">{item.channel}</span></p>
                        <p><span className="text-white/30">Type:</span> <span className="text-white/60">{item.type}</span></p>
                        <p><span className="text-white/30">Status:</span> <span className="text-white/60">{item.status}</span></p>
                        <p><span className="text-white/30">Phone:</span> <span className="text-white/60">{item.phone || "—"}</span></p>
                        {item.scheduled_at && <p><span className="text-white/30">Scheduled:</span> <span className="text-white/60">{formatDate(item.scheduled_at)}</span></p>}
                        {item.sent_at && <p><span className="text-white/30">Sent at:</span> <span className="text-white/60">{formatDate(item.sent_at)}</span></p>}
                      </div>
                      <div>
                        <p className="text-white/30 mb-1">Message:</p>
                        <p className="text-white/50 leading-relaxed">{item.message}</p>
                      </div>
                      {item.error_message && (
                        <div className="rounded-lg p-2 bg-rose-500/10 border border-rose-500/20">
                          <p className="text-rose-400 text-[10px]">⚠️ Error: {item.error_message}</p>
                        </div>
                      )}
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-2">
          <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
            className="px-3 py-1.5 rounded-lg text-xs text-white/40 border border-white/10 disabled:opacity-30">← Prev</button>
          <span className="text-white/30 text-xs">{page} / {totalPages}</span>
          <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages}
            className="px-3 py-1.5 rounded-lg text-xs text-white/40 border border-white/10 disabled:opacity-30">Next →</button>
        </div>
      )}
    </div>
  );
}
