import { useState, useEffect } from "react";
import pb from "../../lib/pocketbase";
import { useAuth } from "../../contexts/AuthContext";
import {
  ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid,
  LineChart, Line, PieChart, Pie, Cell,
} from "recharts";

interface Stats {
  totalUsers: number;
  newUsersThisMonth: number;
  totalChildren: number;
  totalArticles: number;
  notifPending: number;
  notifSent: number;
  notifFailed: number;
  usersByLang: { name: string; value: number }[];
  articlesByCategory: { name: string; count: number }[];
  recentUsers: { id: string; name: string; email: string; role: string; created: string }[];
}

const LANG_COLORS: Record<string, string> = { en: "#8b5cf6", ms: "#3b82f6", zh: "#f472b6", "": "#6b7280" };
const CAT_COLORS = ["#8b5cf6","#3b82f6","#10b981","#f59e0b","#ef4444","#ec4899","#6b7280"];

const StatCard = ({ icon, label, value, sub, color }: { icon: string; label: string; value: number | string; sub?: string; color: string }) => (
  <div className="rounded-2xl p-4 border border-white/5 flex items-start gap-4" style={{ background: "rgba(255,255,255,0.03)" }}>
    <div className="w-10 h-10 rounded-xl flex items-center justify-center text-xl shrink-0" style={{ background: `${color}20` }}>{icon}</div>
    <div>
      <p className="text-white/40 text-xs font-medium">{label}</p>
      <p className="text-white text-2xl font-bold mt-0.5">{value}</p>
      {sub && <p className="text-white/30 text-xs mt-0.5">{sub}</p>}
    </div>
  </div>
);

const CustomTooltipDark = ({ active, payload, label }: { active?: boolean; payload?: { value: number; name: string }[]; label?: string }) => {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl px-3 py-2 text-xs border border-white/10" style={{ background: "rgba(20,10,40,0.95)" }}>
      {label && <p className="text-white/50 mb-1">{label}</p>}
      {payload.map((p, i) => (
        <p key={i} className="text-white font-semibold">{p.value}</p>
      ))}
    </div>
  );
};

export default function AdminOverview() {
  const { user } = useAuth();
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const now = new Date();
        const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

        const [users, newUsers, children, articles, notifPending, notifSent, notifFailed] = await Promise.all([
          pb.collection("users").getList(1, 1, { requestKey: null }),
          pb.collection("users").getList(1, 1, {
            filter: pb.filter("created >= {:s}", { s: monthStart }), requestKey: null,
          }),
          pb.collection("children").getList(1, 1, { requestKey: null }),
          pb.collection("articles").getList(1, 1, { requestKey: null }),
          pb.collection("notification_queue").getList(1, 1, {
            filter: pb.filter("status = 'pending'"), requestKey: null,
          }),
          pb.collection("notification_queue").getList(1, 1, {
            filter: pb.filter("status = 'sent'"), requestKey: null,
          }),
          pb.collection("notification_queue").getList(1, 1, {
            filter: pb.filter("status = 'failed'"), requestKey: null,
          }),
        ]);

        // Users by language
        const allUsers = await pb.collection("users").getFullList({ requestKey: null, fields: "language,created" });
        const langMap: Record<string, number> = {};
        allUsers.forEach(u => {
          const l = String(u.language || "");
          langMap[l] = (langMap[l] ?? 0) + 1;
        });
        const usersByLang = Object.entries(langMap).map(([name, value]) => ({
          name: name || "—", value,
        }));

        // Articles by category
        const allArticles = await pb.collection("articles").getFullList({ requestKey: null, fields: "category" });
        const catMap: Record<string, number> = {};
        allArticles.forEach(a => {
          const c = String(a.category || "general");
          catMap[c] = (catMap[c] ?? 0) + 1;
        });
        const articlesByCategory = Object.entries(catMap).map(([name, count]) => ({ name, count }));

        // Recent users
        const recentRaw = await pb.collection("users").getList(1, 6, {
          sort: "-created", requestKey: null,
          fields: "id,name,email,role,created",
        });
        const recentUsers = recentRaw.items.map(u => ({
          id: String(u.id), name: String(u.name ?? ""), email: String(u.email ?? ""),
          role: String(u.role ?? "user"), created: String(u.created ?? ""),
        }));

        setStats({
          totalUsers: users.totalItems,
          newUsersThisMonth: newUsers.totalItems,
          totalChildren: children.totalItems,
          totalArticles: articles.totalItems,
          notifPending: notifPending.totalItems,
          notifSent: notifSent.totalItems,
          notifFailed: notifFailed.totalItems,
          usersByLang,
          articlesByCategory,
          recentUsers,
        });
      } catch (e) {
        console.error("Admin stats error:", e);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  if (loading) return (
    <div className="flex items-center justify-center py-24">
      <div className="animate-spin rounded-full h-8 w-8 border-2 border-violet-500 border-t-transparent" />
    </div>
  );

  if (!stats) return null;

  return (
    <div className="space-y-6 fade-up">
      <div>
        <h1 className="text-white text-2xl font-bold">Overview</h1>
        <p className="text-white/40 text-sm mt-0.5">Welcome back, {user?.name} · {new Date().toLocaleDateString(undefined, { weekday: "long", day: "numeric", month: "long" })}</p>
      </div>

      {/* KPI cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <StatCard icon="👥" label="Total Users" value={stats.totalUsers} sub={`+${stats.newUsersThisMonth} this month`} color="#8b5cf6" />
        <StatCard icon="👶" label="Children Tracked" value={stats.totalChildren} color="#3b82f6" />
        <StatCard icon="📖" label="Articles" value={stats.totalArticles} color="#10b981" />
        <StatCard icon="📨" label="Notif Sent" value={stats.notifSent} sub={`${stats.notifPending} pending · ${stats.notifFailed} failed`} color="#f59e0b" />
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Users by language */}
        <div className="rounded-2xl p-5 border border-white/5" style={{ background: "rgba(255,255,255,0.03)" }}>
          <h3 className="text-white/70 text-sm font-semibold mb-4">Users by Language</h3>
          <ResponsiveContainer width="100%" height={160}>
            <PieChart>
              <Pie data={stats.usersByLang} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={60} innerRadius={35}>
                {stats.usersByLang.map((entry, i) => (
                  <Cell key={i} fill={LANG_COLORS[entry.name] ?? CAT_COLORS[i % CAT_COLORS.length]} />
                ))}
              </Pie>
              <Tooltip content={<CustomTooltipDark />} />
            </PieChart>
          </ResponsiveContainer>
          <div className="flex flex-wrap gap-2 mt-2">
            {stats.usersByLang.map((l, i) => (
              <span key={l.name} className="flex items-center gap-1 text-[11px] text-white/50">
                <span className="w-2 h-2 rounded-full" style={{ background: LANG_COLORS[l.name] ?? CAT_COLORS[i] }} />
                {l.name === "en" ? "English" : l.name === "ms" ? "Bahasa" : l.name === "zh" ? "中文" : "—"} ({l.value})
              </span>
            ))}
          </div>
        </div>

        {/* Articles by category */}
        <div className="lg:col-span-2 rounded-2xl p-5 border border-white/5" style={{ background: "rgba(255,255,255,0.03)" }}>
          <h3 className="text-white/70 text-sm font-semibold mb-4">Articles by Category</h3>
          <ResponsiveContainer width="100%" height={160}>
            <BarChart data={stats.articlesByCategory} margin={{ left: -20, right: 4, top: 4, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" vertical={false} />
              <XAxis dataKey="name" tick={{ fill: "rgba(255,255,255,0.35)", fontSize: 10 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: "rgba(255,255,255,0.35)", fontSize: 10 }} axisLine={false} tickLine={false} />
              <Tooltip content={<CustomTooltipDark />} />
              <Bar dataKey="count" radius={[4, 4, 0, 0]}>
                {stats.articlesByCategory.map((_, i) => (
                  <Cell key={i} fill={CAT_COLORS[i % CAT_COLORS.length]} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Notification queue status */}
      <div className="rounded-2xl p-5 border border-white/5" style={{ background: "rgba(255,255,255,0.03)" }}>
        <h3 className="text-white/70 text-sm font-semibold mb-4">Notification Queue Status</h3>
        <div className="grid grid-cols-3 gap-3">
          {[
            { label: "Pending", value: stats.notifPending, color: "#f59e0b", icon: "⏳" },
            { label: "Sent", value: stats.notifSent, color: "#10b981", icon: "✅" },
            { label: "Failed", value: stats.notifFailed, color: "#ef4444", icon: "❌" },
          ].map(s => (
            <div key={s.label} className="rounded-xl p-3 text-center border border-white/5" style={{ background: `${s.color}10` }}>
              <p className="text-xl">{s.icon}</p>
              <p className="text-white text-xl font-bold mt-1">{s.value}</p>
              <p className="text-white/40 text-xs">{s.label}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Recent users */}
      <div className="rounded-2xl border border-white/5 overflow-hidden" style={{ background: "rgba(255,255,255,0.03)" }}>
        <div className="px-5 py-4 border-b border-white/5">
          <h3 className="text-white/70 text-sm font-semibold">Recent Registrations</h3>
        </div>
        <div className="divide-y divide-white/5">
          {stats.recentUsers.map(u => (
            <div key={u.id} className="flex items-center gap-3 px-5 py-3">
              <div className="w-8 h-8 rounded-full bg-violet-600/20 flex items-center justify-center text-sm text-violet-300 font-bold shrink-0">
                {(u.name || u.email)[0]?.toUpperCase()}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-white/80 text-sm font-medium truncate">{u.name || "—"}</p>
                <p className="text-white/30 text-xs truncate">{u.email}</p>
              </div>
              <div className="text-right shrink-0">
                <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                  u.role === "superadmin" ? "bg-rose-500/20 text-rose-300" :
                  u.role === "admin" ? "bg-violet-500/20 text-violet-300" :
                  "bg-white/5 text-white/30"
                }`}>{u.role || "user"}</span>
                <p className="text-white/25 text-[10px] mt-0.5">{new Date(u.created).toLocaleDateString()}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
