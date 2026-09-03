import { useState, useEffect, useCallback, type ReactNode } from "react";
import pb from "../../lib/pocketbase";

interface Article {
  id: string; title: string; summary: string; content: string; category: string;
  reading_time: string; min_age_months: number; max_age_months: number;
  is_pregnancy: boolean; created: string; youtube_url: string;
  title_ms: string; summary_ms: string; content_ms: string;
  title_zh: string; summary_zh: string; content_zh: string;
}

const CATEGORIES = ["growth","nutrition","activity","wellbeing","immunisation","pregnancy","general"];
const CAT_COLORS: Record<string, string> = {
  growth: "text-blue-400 bg-blue-500/10",
  nutrition: "text-orange-400 bg-orange-500/10",
  activity: "text-emerald-400 bg-emerald-500/10",
  wellbeing: "text-violet-400 bg-violet-500/10",
  immunisation: "text-rose-400 bg-rose-500/10",
  pregnancy: "text-pink-400 bg-pink-500/10",
  general: "text-gray-400 bg-gray-500/10",
};

const empty: Omit<Article, "id" | "created"> = {
  title: "", summary: "", content: "", category: "general", reading_time: "3 min read",
  min_age_months: 0, max_age_months: 60, is_pregnancy: false,
  title_ms: "", summary_ms: "", content_ms: "",
  title_zh: "", summary_zh: "", content_zh: "",
  youtube_url: "",
};

export default function AdminContent() {
  const [articles, setArticles] = useState<Article[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [catFilter, setCatFilter] = useState("all");
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<Partial<Article> | null>(null);
  const [saving, setSaving] = useState(false);
  const [editorTab, setEditorTab] = useState<"en" | "ms" | "zh">("en");
  const [toast, setToast] = useState("");

  const fetch_ = useCallback(async () => {
    setLoading(true);
    try {
      const filters: string[] = [];
      if (search) filters.push(`(title ~ "${search}" || summary ~ "${search}")`);
      if (catFilter !== "all") filters.push(`category = "${catFilter}"`);
      const result = await pb.collection("articles").getList(page, 15, {
        filter: filters.join(" && ") || "",
        sort: "-created", requestKey: null,
      });
        setArticles(result.items.map(a => ({
        id: String(a.id), title: String(a.title ?? ""), summary: String(a.summary ?? ""),
        content: String(a.content ?? ""), category: String(a.category ?? "general"),
        reading_time: String(a.reading_time ?? "3 min read"),
        min_age_months: Number(a.min_age_months ?? 0), max_age_months: Number(a.max_age_months ?? 60),
        is_pregnancy: Boolean(a.is_pregnancy), youtube_url: String(a.youtube_url ?? ""),
        title_ms: String(a.title_ms ?? ""), summary_ms: String(a.summary_ms ?? ""), content_ms: String(a.content_ms ?? ""),
        title_zh: String(a.title_zh ?? ""), summary_zh: String(a.summary_zh ?? ""), content_zh: String(a.content_zh ?? ""),
        created: String(a.created ?? ""),
      })));
      setTotal(result.totalItems);
    } finally { setLoading(false); }
  }, [page, search, catFilter]);

  useEffect(() => { fetch_(); }, [fetch_]);

  const save = async () => {
    if (!editing) return;
    setSaving(true);
    try {
      if (editing.id) {
        await pb.collection("articles").update(editing.id, editing);
      } else {
        await pb.collection("articles").create(editing);
      }
      setEditing(null);
      await fetch_();
      setToast(editing.id ? "Article updated" : "Article created");
      setTimeout(() => setToast(""), 2500);
    } finally { setSaving(false); }
  };

  const remove = async (id: string, title: string) => {
    if (!confirm(`Delete "${title}"? This cannot be undone.`)) return;
    await pb.collection("articles").delete(id);
    setArticles(prev => prev.filter(a => a.id !== id));
    setTotal(t => t - 1);
  };

  const totalPages = Math.ceil(total / 15);

  const Field = ({ label, children }: { label: string; children: ReactNode }) => (
    <div>
      <label className="text-xs text-white/40 font-semibold block mb-1">{label}</label>
      {children}
    </div>
  );

  const inputCls = "w-full px-3 py-2 rounded-xl text-sm text-white/80 placeholder:text-white/20 outline-none border border-white/10 focus:border-violet-500/50 bg-white/[0.04]";
  const textAreaCls = `${inputCls} resize-none font-mono text-xs`;

  return (
    <div className="space-y-5 fade-up">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div>
          <h1 className="text-white text-2xl font-bold">Content</h1>
          <p className="text-white/40 text-sm mt-0.5">{total} articles · trilingual CMS</p>
        </div>
        <button onClick={() => { setEditing({ ...empty }); setEditorTab("en"); }}
          className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold text-white transition-all"
          style={{ background: "linear-gradient(135deg, rgba(139,92,246,0.8), rgba(59,130,246,0.8))", border: "1px solid rgba(255,255,255,0.15)" }}>
          ✚ New Article
        </button>
      </div>

      {/* Filters */}
      <div className="flex gap-2 flex-wrap">
        <div className="relative flex-1 min-w-48">
          <span className="absolute left-3 top-2.5 text-white/25 text-sm">🔍</span>
          <input type="text" value={search} onChange={e => { setSearch(e.target.value); setPage(1); }}
            placeholder="Search articles…" className={`${inputCls} pl-9`} />
        </div>
        <select value={catFilter} onChange={e => { setCatFilter(e.target.value); setPage(1); }}
          className="px-3 py-2 rounded-xl text-sm text-white/60 outline-none border border-white/10 bg-white/[0.04]">
          <option value="all">All categories</option>
          {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
      </div>

      {/* Article list */}
      <div className="rounded-2xl border border-white/5 overflow-hidden" style={{ background: "rgba(255,255,255,0.02)" }}>
        {loading ? (
          <div className="flex justify-center py-12"><div className="animate-spin rounded-full h-6 w-6 border-2 border-violet-500 border-t-transparent" /></div>
        ) : articles.length === 0 ? (
          <div className="text-center py-12 text-white/30 text-sm">No articles found</div>
        ) : (
          <div className="divide-y divide-white/5">
            {articles.map(a => (
              <div key={a.id} className="flex items-start gap-4 px-5 py-4 hover:bg-white/[0.02] transition-colors">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1 flex-wrap">
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full capitalize ${CAT_COLORS[a.category]}`}>
                      {a.category}
                    </span>
                    <span className="text-white/20 text-[10px]">{a.reading_time}</span>
                    {(a.title_ms || a.title_zh) && <span className="text-white/20 text-[10px]">🌐 multilingual</span>}
                  </div>
                  <h3 className="text-white/80 font-semibold text-sm leading-snug">{a.title}</h3>
                  <p className="text-white/30 text-xs mt-0.5 line-clamp-1">{a.summary}</p>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <button onClick={() => { setEditing({ ...a }); setEditorTab("en"); }}
                    className="text-xs text-white/30 hover:text-violet-400 transition-colors px-2 py-1 rounded-lg hover:bg-violet-500/10">
                    Edit
                  </button>
                  <button onClick={() => remove(a.id, a.title)}
                    className="text-xs text-white/20 hover:text-rose-400 transition-colors px-2 py-1 rounded-lg hover:bg-rose-500/10">
                    Delete
                  </button>
                </div>
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

      {/* Editor modal */}
      {editing && (
        <div className="fixed inset-0 z-50 flex items-start justify-center p-4 pt-8 overflow-y-auto"
          style={{ background: "rgba(0,0,0,0.8)", backdropFilter: "blur(8px)" }}>
          <div className="w-full max-w-2xl rounded-3xl border border-white/10 overflow-hidden shadow-2xl"
            style={{ background: "rgba(15,10,30,0.97)" }}>
            {/* Modal header */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-white/10">
              <h2 className="text-white font-bold">{editing.id ? "Edit Article" : "New Article"}</h2>
              <button onClick={() => setEditing(null)} className="text-white/30 hover:text-white/60 text-xl leading-none">×</button>
            </div>

            <div className="p-6 space-y-4 max-h-[75vh] overflow-y-auto">
              {/* Meta row */}
              <div className="grid grid-cols-2 gap-3">
                <Field label="Category">
                  <select value={editing.category || "general"} onChange={e => setEditing(p => ({ ...p, category: e.target.value }))}
                    className={inputCls}>
                    {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
                  </select>
                </Field>
                <Field label="Reading Time">
                  <input type="text" value={editing.reading_time || ""} onChange={e => setEditing(p => ({ ...p, reading_time: e.target.value }))}
                    placeholder="3 min read" className={inputCls} />
                </Field>
                <Field label="Min Age (months)">
                  <input type="number" value={editing.min_age_months ?? 0} onChange={e => setEditing(p => ({ ...p, min_age_months: +e.target.value }))}
                    className={inputCls} />
                </Field>
                <Field label="Max Age (months)">
                  <input type="number" value={editing.max_age_months ?? 60} onChange={e => setEditing(p => ({ ...p, max_age_months: +e.target.value }))}
                    className={inputCls} />
                </Field>
              </div>
              <div className="flex items-center gap-2">
                <input type="checkbox" id="preg" checked={!!editing.is_pregnancy} onChange={e => setEditing(p => ({ ...p, is_pregnancy: e.target.checked }))} className="accent-violet-500" />
                <label htmlFor="preg" className="text-white/50 text-xs font-medium">Pregnancy content</label>
              </div>

              {/* YouTube URL */}
              <Field label="▶ YouTube URL (optional — paste full youtube.com or youtu.be link)">
                <input type="url" value={editing.youtube_url || ""} onChange={e => setEditing(p => ({ ...p, youtube_url: e.target.value }))}
                  placeholder="https://www.youtube.com/watch?v=..." className={inputCls} />
              </Field>

              {/* Language tabs */}
              <div className="flex gap-1 rounded-xl p-1 border border-white/10" style={{ background: "rgba(255,255,255,0.03)" }}>
                {(["en","ms","zh"] as const).map(l => (
                  <button key={l} onClick={() => setEditorTab(l)}
                    className={`flex-1 py-1.5 rounded-lg text-xs font-semibold transition-all ${editorTab === l ? "bg-violet-600/40 text-violet-300" : "text-white/30 hover:text-white/50"}`}>
                    {l === "en" ? "🇬🇧 English" : l === "ms" ? "🇲🇾 Bahasa" : "🇨🇳 中文"}
                  </button>
                ))}
              </div>

              {editorTab === "en" && (
                <div className="space-y-3">
                  <Field label="Title (EN) *">
                    <input type="text" value={editing.title || ""} onChange={e => setEditing(p => ({ ...p, title: e.target.value }))}
                      placeholder="Article title" className={inputCls} />
                  </Field>
                  <Field label="Summary (EN)">
                    <textarea rows={2} value={editing.summary || ""} onChange={e => setEditing(p => ({ ...p, summary: e.target.value }))}
                      placeholder="Brief summary" className={textAreaCls} />
                  </Field>
                  <Field label="Content (EN) — HTML supported">
                    <textarea rows={10} value={editing.content || ""} onChange={e => setEditing(p => ({ ...p, content: e.target.value }))}
                      placeholder="<p>Article content...</p>" className={textAreaCls} />
                  </Field>
                </div>
              )}
              {editorTab === "ms" && (
                <div className="space-y-3">
                  <Field label="Title (Bahasa Malaysia)">
                    <input type="text" value={editing.title_ms || ""} onChange={e => setEditing(p => ({ ...p, title_ms: e.target.value }))}
                      placeholder="Tajuk artikel" className={inputCls} />
                  </Field>
                  <Field label="Summary (Bahasa Malaysia)">
                    <textarea rows={2} value={editing.summary_ms || ""} onChange={e => setEditing(p => ({ ...p, summary_ms: e.target.value }))}
                      placeholder="Ringkasan ringkas" className={textAreaCls} />
                  </Field>
                  <Field label="Content (Bahasa Malaysia) — HTML supported">
                    <textarea rows={10} value={editing.content_ms || ""} onChange={e => setEditing(p => ({ ...p, content_ms: e.target.value }))}
                      placeholder="<p>Kandungan artikel...</p>" className={textAreaCls} />
                  </Field>
                </div>
              )}
              {editorTab === "zh" && (
                <div className="space-y-3">
                  <Field label="标题（中文）">
                    <input type="text" value={editing.title_zh || ""} onChange={e => setEditing(p => ({ ...p, title_zh: e.target.value }))}
                      placeholder="文章标题" className={inputCls} />
                  </Field>
                  <Field label="摘要（中文）">
                    <textarea rows={2} value={editing.summary_zh || ""} onChange={e => setEditing(p => ({ ...p, summary_zh: e.target.value }))}
                      placeholder="简短摘要" className={textAreaCls} />
                  </Field>
                  <Field label="内容（中文）— 支持 HTML">
                    <textarea rows={10} value={editing.content_zh || ""} onChange={e => setEditing(p => ({ ...p, content_zh: e.target.value }))}
                      placeholder="<p>文章内容...</p>" className={textAreaCls} />
                  </Field>
                </div>
              )}
            </div>

            <div className="flex gap-3 px-6 py-4 border-t border-white/10">
              <button onClick={() => setEditing(null)}
                className="flex-1 py-2.5 rounded-xl text-sm text-white/40 border border-white/10 hover:border-white/20 transition-all">
                Cancel
              </button>
              <button onClick={save} disabled={saving || !editing.title}
                className="flex-1 py-2.5 rounded-xl text-sm font-bold text-white disabled:opacity-40 transition-all"
                style={{ background: "linear-gradient(135deg, rgba(139,92,246,0.85), rgba(59,130,246,0.85))" }}>
                {saving ? "Saving…" : editing.id ? "Save Changes" : "Publish Article"}
              </button>
            </div>
          </div>
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
