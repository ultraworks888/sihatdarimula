import { useState, useEffect, useCallback } from "react";
import pb from "../../lib/pocketbase";
import { useAuth } from "../../contexts/AuthContext";

interface UserRow {
  id: string; name: string; email: string; phone: string;
  role: string; language: string; created: string;
}

const roleBadge = (role: string) => {
  if (role === "superadmin") return "bg-rose-500/20 text-rose-300 border-rose-500/30";
  if (role === "admin") return "bg-violet-500/20 text-violet-300 border-violet-500/30";
  return "bg-white/5 text-white/40 border-white/10";
};

const langFlag: Record<string, string> = { en: "🇬🇧", ms: "🇲🇾", zh: "🇨🇳" };

export default function AdminUsers() {
  const { user: me, isSuperAdmin } = useAuth();
  const [users, setUsers] = useState<UserRow[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [updatingId, setUpdatingId] = useState<string | null>(null);
  const [toast, setToast] = useState("");

  const fetchUsers = useCallback(async () => {
    setLoading(true);
    try {
      const filter = search
        ? pb.filter("name ~ {:q} || email ~ {:q}", { q: search })
        : "";
      const result = await pb.collection("users").getList(page, 20, {
        sort: "-created", filter, requestKey: null,
        fields: "id,name,email,phone,role,language,created",
      });
      setUsers(result.items.map(u => ({
        id: String(u.id), name: String(u.name ?? ""), email: String(u.email ?? ""),
        phone: String(u.phone ?? ""), role: String(u.role ?? "user"),
        language: String(u.language ?? ""), created: String(u.created ?? ""),
      })));
      setTotal(result.totalItems);
    } finally { setLoading(false); }
  }, [page, search]);

  useEffect(() => { fetchUsers(); }, [fetchUsers]);

  const changeRole = async (userId: string, newRole: string) => {
    if (!isSuperAdmin) return;
    if (userId === me?.id && newRole !== "superadmin") {
      if (!confirm("Changing your own role will affect your access. Continue?")) return;
    }
    setUpdatingId(userId);
    try {
      await pb.collection("users").update(userId, { role: newRole });
      setUsers(prev => prev.map(u => u.id === userId ? { ...u, role: newRole } : u));
      setToast(`Role updated to ${newRole}`);
      setTimeout(() => setToast(""), 2500);
    } finally { setUpdatingId(null); }
  };

  const deleteUser = async (userId: string, name: string) => {
    if (!isSuperAdmin) return;
    if (!confirm(`Delete user "${name}"? This cannot be undone.`)) return;
    await pb.collection("users").delete(userId);
    setUsers(prev => prev.filter(u => u.id !== userId));
    setTotal(t => t - 1);
  };

  const totalPages = Math.ceil(total / 20);

  return (
    <div className="space-y-5 fade-up">
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <h1 className="text-white text-2xl font-bold">Users</h1>
          <p className="text-white/40 text-sm mt-0.5">{total} registered accounts</p>
        </div>
        {!isSuperAdmin && (
          <div className="rounded-xl px-3 py-2 text-xs text-amber-400/80 bg-amber-500/10 border border-amber-500/20">
            ⚠️ Role changes require Super Admin access
          </div>
        )}
      </div>

      {/* Search */}
      <div className="relative">
        <span className="absolute left-3 top-2.5 text-white/30">🔍</span>
        <input type="text" value={search} onChange={e => { setSearch(e.target.value); setPage(1); }}
          placeholder="Search by name or email…"
          className="w-full pl-9 pr-4 py-2.5 rounded-xl text-sm text-white placeholder:text-white/25 outline-none border border-white/10 focus:border-violet-500/50"
          style={{ background: "rgba(255,255,255,0.04)" }} />
      </div>

      {/* Table */}
      <div className="rounded-2xl border border-white/5 overflow-hidden" style={{ background: "rgba(255,255,255,0.02)" }}>
        {loading ? (
          <div className="flex justify-center py-12">
            <div className="animate-spin rounded-full h-6 w-6 border-2 border-violet-500 border-t-transparent" />
          </div>
        ) : users.length === 0 ? (
          <div className="text-center py-12 text-white/30 text-sm">No users found</div>
        ) : (
          <>
            {/* Desktop table */}
            <div className="hidden lg:block overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-white/5">
                    {["User", "Phone", "Language", "Role", "Joined", "Actions"].map(h => (
                      <th key={h} className="text-left px-5 py-3 text-white/30 text-xs font-semibold uppercase tracking-wider">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-white/5">
                  {users.map(u => (
                    <tr key={u.id} className="hover:bg-white/[0.02] transition-colors">
                      <td className="px-5 py-3">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-full bg-violet-600/20 flex items-center justify-center text-violet-300 font-bold text-xs shrink-0">
                            {(u.name || u.email)[0]?.toUpperCase()}
                          </div>
                          <div>
                            <p className="text-white/80 font-medium">{u.name || "—"}</p>
                            <p className="text-white/30 text-xs">{u.email}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-5 py-3 text-white/50 text-xs">{u.phone || "—"}</td>
                      <td className="px-5 py-3">
                        <span className="text-base">{langFlag[u.language] ?? "—"}</span>
                      </td>
                      <td className="px-5 py-3">
                        {isSuperAdmin ? (
                          <select value={u.role || "user"} disabled={updatingId === u.id}
                            onChange={e => changeRole(u.id, e.target.value)}
                            className={`rounded-lg px-2 py-1 text-xs font-bold border outline-none cursor-pointer ${roleBadge(u.role)}`}
                            style={{ background: "transparent" }}>
                            <option value="user">user</option>
                            <option value="admin">admin</option>
                            <option value="superadmin">superadmin</option>
                          </select>
                        ) : (
                          <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full border ${roleBadge(u.role)}`}>
                            {u.role || "user"}
                          </span>
                        )}
                      </td>
                      <td className="px-5 py-3 text-white/30 text-xs">
                        {new Date(u.created).toLocaleDateString()}
                      </td>
                      <td className="px-5 py-3">
                        {isSuperAdmin && u.id !== me?.id && (
                          <button onClick={() => deleteUser(u.id, u.name)}
                            className="text-rose-500/50 hover:text-rose-400 text-xs transition-colors">
                            Delete
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Mobile cards */}
            <div className="lg:hidden divide-y divide-white/5">
              {users.map(u => (
                <div key={u.id} className="px-4 py-3 space-y-2">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-white/80 text-sm font-medium">{u.name || "—"}</p>
                      <p className="text-white/30 text-xs">{u.email}</p>
                    </div>
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full border ${roleBadge(u.role)}`}>
                      {u.role || "user"}
                    </span>
                  </div>
                  <div className="flex items-center gap-4 text-xs text-white/30">
                    <span>{langFlag[u.language] ?? "—"} {u.language || "—"}</span>
                    <span>📱 {u.phone || "—"}</span>
                    <span>{new Date(u.created).toLocaleDateString()}</span>
                  </div>
                  {isSuperAdmin && (
                    <div className="flex gap-2">
                      {["user","admin","superadmin"].map(r => (
                        <button key={r} onClick={() => changeRole(u.id, r)} disabled={u.role === r}
                          className={`px-2.5 py-1 rounded-lg text-[10px] font-bold border transition-all ${
                            u.role === r ? roleBadge(r) : "border-white/10 text-white/20 hover:border-white/20"
                          }`}>
                          {r}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              ))}
            </div>
          </>
        )}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-2">
          <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
            className="px-3 py-1.5 rounded-lg text-xs text-white/40 border border-white/10 hover:border-white/20 disabled:opacity-30 transition-all">
            ← Prev
          </button>
          <span className="text-white/30 text-xs">{page} / {totalPages}</span>
          <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages}
            className="px-3 py-1.5 rounded-lg text-xs text-white/40 border border-white/10 hover:border-white/20 disabled:opacity-30 transition-all">
            Next →
          </button>
        </div>
      )}

      {toast && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 rounded-full px-4 py-2 text-sm font-semibold text-emerald-300 border border-emerald-500/30 animate-in"
          style={{ background: "rgba(16,185,129,0.15)", backdropFilter: "blur(20px)" }}>
          ✓ {toast}
        </div>
      )}
    </div>
  );
}
