import { useState, useEffect } from "react";
import pb from "../../lib/pocketbase";
import { BarChart, RefreshCw, Download } from "lucide-react";

interface Statement {
  id: string; created: string;
  verb: string; object_type: string; object_id: string;
  result_completion: boolean; result_success: boolean;
  result_score: number; result_duration: number; result_progress: number;
  synced_offline: boolean;
  expand?: { user?: { name: string; email: string } };
}

const VERBS = ["", "initialized","progressed","completed","paused","resumed","passed","failed","abandoned"];

export default function LRS() {
  const [statements, setStatements] = useState<Statement[]>([]);
  const [loading, setLoading] = useState(true);
  const [verbFilter, setVerbFilter] = useState("");
  const [typeFilter, setTypeFilter] = useState("");
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const PER_PAGE = 25;

  const [stats, setStats] = useState({ total: 0, completed: 0, passed: 0, avgScore: 0, offlineSynced: 0 });

  const load = async () => {
    setLoading(true);
    const filters: string[] = [];
    if (verbFilter) filters.push(`verb = "${verbFilter}"`);
    if (typeFilter) filters.push(`object_type = "${typeFilter}"`);
    const filter = filters.join(" && ");
    const result = await pb.collection("xapi_statements").getList(page, PER_PAGE, {
      filter, sort: "-created", expand: "user", requestKey: null,
    });
    setStatements(result.items as unknown as Statement[]);
    setTotal(result.totalItems);

    if (page === 1) {
      const all = await pb.collection("xapi_statements").getFullList({ fields: "verb,result_completion,result_success,result_score,synced_offline", requestKey: null });
      const completed = all.filter(s => s.result_completion).length;
      const passed = all.filter(s => s.result_success).length;
      const scores = all.filter(s => (s.result_score as number) > 0).map(s => s.result_score as number);
      const avgScore = scores.length > 0 ? Math.round(scores.reduce((a, b) => a + b, 0) / scores.length) : 0;
      const offlineSynced = all.filter(s => s.synced_offline).length;
      setStats({ total: all.length, completed, passed, avgScore, offlineSynced });
    }
    setLoading(false);
  };

  useEffect(() => { load(); }, [page, verbFilter, typeFilter]);

  const exportCSV = () => {
    const headers = ["id","created","verb","object_type","object_id","completion","success","score","duration","progress","offline"];
    const rows = statements.map(s => [s.id, s.created, s.verb, s.object_type, s.object_id, s.result_completion, s.result_success, s.result_score, s.result_duration, s.result_progress, s.synced_offline].join(","));
    const csv = [headers.join(","), ...rows].join("\n");
    const blob = new Blob([csv], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a"); a.href = url; a.download = `lrs_export_${Date.now()}.csv`; a.click();
    URL.revokeObjectURL(url);
  };

  const verbColors: Record<string, string> = {
    initialized: "bg-blue-500/20 text-blue-400", progressed: "bg-amber-500/20 text-amber-400",
    completed: "bg-emerald-500/20 text-emerald-400", passed: "bg-emerald-500/20 text-emerald-400",
    paused: "bg-gray-500/20 text-gray-400", resumed: "bg-violet-500/20 text-violet-400",
    failed: "bg-rose-500/20 text-rose-400", abandoned: "bg-rose-500/20 text-rose-400",
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div><h2 className="text-white font-bold text-xl">Learning Records</h2><p className="text-white/40 text-sm">xAPI Statement Store</p></div>
        <div className="flex gap-2">
          <button onClick={exportCSV} className="flex items-center gap-2 px-3 py-2 bg-white/10 hover:bg-white/15 text-white/70 hover:text-white rounded-xl text-xs font-semibold transition-all">
            <Download size={14} /> Export CSV
          </button>
          <button onClick={load} disabled={loading} className="flex items-center gap-2 px-3 py-2 bg-white/10 hover:bg-white/15 text-white/70 hover:text-white rounded-xl text-xs font-semibold transition-all disabled:opacity-50">
            <RefreshCw size={14} className={loading ? "animate-spin" : ""} /> Refresh
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-3">
        {[
          { label: "Total Statements", value: stats.total },
          { label: "Completions", value: stats.completed },
          { label: "Quizzes Passed", value: stats.passed },
          { label: "Avg Quiz Score", value: `${stats.avgScore}%` },
          { label: "Offline Synced", value: stats.offlineSynced },
        ].map(s => (
          <div key={s.label} className="bg-white/5 border border-white/10 rounded-2xl p-3 text-center">
            <p className="text-2xl font-bold text-white">{s.value}</p>
            <p className="text-white/40 text-[11px] mt-0.5">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div className="flex gap-3 flex-wrap">
        <select value={verbFilter} onChange={e => { setVerbFilter(e.target.value); setPage(1); }}
          className="px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none">
          {VERBS.map(v => <option key={v} value={v} className="bg-slate-900">{v || "All Verbs"}</option>)}
        </select>
        <select value={typeFilter} onChange={e => { setTypeFilter(e.target.value); setPage(1); }}
          className="px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none">
          <option value="" className="bg-slate-900">All Types</option>
          {["lesson","course","quiz"].map(v => <option key={v} value={v} className="bg-slate-900">{v}</option>)}
        </select>
        <div className="flex items-center gap-1 text-white/30 text-sm ml-auto">
          <BarChart size={14} className="text-amber-400" />
          {total} records
        </div>
      </div>

      {/* Table */}
      <div className="bg-white/5 border border-white/10 rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/10">
                {["Time","User","Verb","Object","Score","Progress","Offline"].map(h => (
                  <th key={h} className="px-4 py-3 text-left text-white/40 font-semibold text-[11px] uppercase tracking-wide whitespace-nowrap">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {loading ? (
                <tr><td colSpan={7} className="text-center py-8 text-white/30">Loading...</td></tr>
              ) : statements.length === 0 ? (
                <tr><td colSpan={7} className="text-center py-8 text-white/30">No statements yet</td></tr>
              ) : statements.map(s => (
                <tr key={s.id} className="hover:bg-white/5 transition-colors">
                  <td className="px-4 py-3 text-white/40 text-[11px] whitespace-nowrap">{new Date(s.created).toLocaleDateString()}</td>
                  <td className="px-4 py-3 text-white/70 text-[12px] max-w-[120px] truncate">{s.expand?.user?.name ?? "—"}</td>
                  <td className="px-4 py-3">
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${verbColors[s.verb] ?? "bg-white/10 text-white/40"}`}>{s.verb}</span>
                  </td>
                  <td className="px-4 py-3 text-white/50 text-[11px]">
                    <span className="text-white/30 mr-1">{s.object_type}</span>
                    <span className="font-mono">{s.object_id.slice(0, 8)}</span>
                  </td>
                  <td className="px-4 py-3 text-white/70 text-[12px]">{s.result_score > 0 ? `${s.result_score}%` : "—"}</td>
                  <td className="px-4 py-3 text-white/70 text-[12px]">{s.result_progress > 0 ? `${s.result_progress}%` : "—"}</td>
                  <td className="px-4 py-3">{s.synced_offline && <span className="text-[10px] text-amber-400 bg-amber-500/10 px-1.5 py-0.5 rounded font-bold">offline</span>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {total > PER_PAGE && (
          <div className="flex items-center justify-between px-4 py-3 border-t border-white/10">
            <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1} className="text-white/40 hover:text-white disabled:opacity-30 text-sm">← Prev</button>
            <span className="text-white/30 text-xs">Page {page} of {Math.ceil(total / PER_PAGE)}</span>
            <button onClick={() => setPage(p => p + 1)} disabled={page >= Math.ceil(total / PER_PAGE)} className="text-white/40 hover:text-white disabled:opacity-30 text-sm">Next →</button>
          </div>
        )}
      </div>
    </div>
  );
}
