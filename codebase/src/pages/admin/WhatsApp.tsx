import { useEffect, useState } from "react";
import {
  MessageCircle, ShieldCheck, AlertTriangle, Eye, EyeOff,
  ChevronDown, ChevronUp, CheckCircle, Loader2, Trash2,
} from "lucide-react";
import pb from "../../lib/pocketbase";
import WaTemplateCard, { type WaTemplate } from "../../components/admin/WaTemplateCard";

// ── Types ─────────────────────────────────────────────────────────────────────

interface ConfigStatus {
  configured: boolean;
  has_phone_id: boolean;
  has_token: boolean;
  api_version: string;
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function AdminWhatsApp() {
  const [templates,     setTemplates]     = useState<WaTemplate[]>([]);
  const [configStatus,  setConfigStatus]  = useState<ConfigStatus | null>(null);
  const [loadingAll,    setLoadingAll]    = useState(true);

  // Config panel state
  const [configOpen,    setConfigOpen]    = useState(false);
  const [phoneId,       setPhoneId]       = useState("");
  const [token,         setToken]         = useState("");
  const [apiVersion,    setApiVersion]    = useState("v20.0");
  const [showToken,     setShowToken]     = useState(false);
  const [savingConfig,  setSavingConfig]  = useState(false);
  const [configMsg,     setConfigMsg]     = useState<{ok:boolean;text:string}|null>(null);
  const [clearing,      setClearing]      = useState(false);

  // ── Load ────────────────────────────────────────────────────────────────────

  const loadAll = async () => {
    try {
      const [tpls, status] = await Promise.all([
        pb.collection("whatsapp_templates").getFullList<WaTemplate>({
          sort: "sort_order", requestKey: null,
        }),
        pb.send("/api/admin/whatsapp/config", {
          method: "GET", requestKey: null,
        }) as Promise<ConfigStatus>,
      ]);
      setTemplates(tpls);
      setConfigStatus(status);
      if (status.api_version) setApiVersion(status.api_version);
    } finally {
      setLoadingAll(false);
    }
  };

  useEffect(() => { loadAll(); }, []);

  // ── Config save ─────────────────────────────────────────────────────────────

  const saveConfig = async () => {
    if (!phoneId && !token) return;
    setSavingConfig(true);
    setConfigMsg(null);
    try {
      await pb.send("/api/admin/whatsapp/config", {
        method: "POST",
        body: { phone_number_id: phoneId, access_token: token, api_version: apiVersion },
        requestKey: null,
      });
      await loadAll();
      setPhoneId(""); setToken("");
      setConfigMsg({ ok: true, text: "Credentials saved. They are stored server-side and never exposed to the browser." });
      setTimeout(() => setConfigMsg(null), 5000);
    } catch {
      setConfigMsg({ ok: false, text: "Failed to save credentials. Please try again." });
    } finally {
      setSavingConfig(false);
    }
  };

  const clearConfig = async () => {
    if (!confirm("Remove all WhatsApp credentials? This cannot be undone from the UI.")) return;
    setClearing(true);
    try {
      await pb.send("/api/admin/whatsapp/config", { method: "DELETE", requestKey: null });
      await loadAll();
    } finally {
      setClearing(false);
    }
  };

  // ── Template update ─────────────────────────────────────────────────────────

  const handleTemplateSaved = (updated: WaTemplate) => {
    setTemplates(prev => prev.map(t => t.id === updated.id ? updated : t));
  };

  // ── Language filter ──────────────────────────────────────────────────────────

  const [langFilter, setLangFilter] = useState<"all" | "en" | "ms" | "zh_CN">("all");
  const filteredTemplates = langFilter === "all"
    ? templates
    : templates.filter(t => t.language_code === langFilter);

  // ── Derived stats ───────────────────────────────────────────────────────────

  const approved  = templates.filter(t => t.approval_status === "approved").length;
  const submitted = templates.filter(t => t.approval_status === "submitted").length;
  const active    = templates.filter(t => t.is_active).length;

  // ── Render ──────────────────────────────────────────────────────────────────

  return (
    <div className="space-y-6">

      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl flex items-center justify-center"
            style={{ background: "rgba(37,211,102,0.12)" }}>
            <MessageCircle size={20} style={{ color: "#25d366" }}/>
          </div>
          <div>
            <h1 className="text-white font-bold text-xl">WhatsApp Templates</h1>
            <p className="text-white/40 text-sm">Manage, edit and submit your WhatsApp Business message templates</p>
          </div>
        </div>

        {/* Status pill */}
        {configStatus && (
          <div className="flex items-center gap-2 px-4 py-2 rounded-2xl border"
            style={{
              background: configStatus.configured ? "rgba(16,185,129,0.08)" : "rgba(245,158,11,0.08)",
              borderColor: configStatus.configured ? "rgba(16,185,129,0.2)" : "rgba(245,158,11,0.2)",
            }}>
            {configStatus.configured
              ? <CheckCircle size={14} className="text-emerald-400"/>
              : <AlertTriangle size={14} className="text-amber-400"/>}
            <span className="text-sm font-semibold"
              style={{ color: configStatus.configured ? "#10b981" : "#f59e0b" }}>
              {configStatus.configured ? "Connected" : "Not configured"}
            </span>
          </div>
        )}
      </div>

      {/* ── Stats row ────────────────────────────────────────────────────── */}
      {!loadingAll && (
        <div className="grid grid-cols-3 gap-3">
          {[
            { label: "Total Templates",   value: templates.length, color: "#8b5cf6" },
            { label: "Approved by Meta",  value: approved,         color: "#10b981" },
            { label: "Currently Active",  value: active,           color: "#25d366" },
          ].map(s => (
            <div key={s.label}
              className="rounded-2xl border border-white/5 p-4 text-center"
              style={{ background: "rgba(255,255,255,0.025)" }}>
              <p className="text-2xl font-black" style={{ color: s.color }}>{s.value}</p>
              <p className="text-white/35 text-xs mt-0.5">{s.label}</p>
            </div>
          ))}
        </div>
      )}

      {/* ── Credentials panel ────────────────────────────────────────────── */}
      <div className="rounded-2xl border border-white/5 overflow-hidden"
        style={{ background: "rgba(255,255,255,0.025)" }}>
        <button
          onClick={() => setConfigOpen(o => !o)}
          className="w-full flex items-center justify-between px-5 py-4 text-left hover:bg-white/2 transition-colors">
          <div className="flex items-center gap-3">
            <ShieldCheck size={16} className="text-white/40"/>
            <div>
              <p className="text-white text-sm font-semibold">API Credentials</p>
              <p className="text-white/35 text-xs">
                Stored server-side only — the token is never sent to your browser
              </p>
            </div>
          </div>
          {configOpen ? <ChevronUp size={16} className="text-white/30"/> : <ChevronDown size={16} className="text-white/30"/>}
        </button>

        {configOpen && (
          <div className="px-5 pb-5 border-t border-white/5 pt-5 space-y-4">

            {/* Security note */}
            <div className="rounded-xl px-4 py-3 text-xs leading-relaxed"
              style={{ background: "rgba(37,211,102,0.06)", border: "1px solid rgba(37,211,102,0.15)", color: "rgba(255,255,255,0.55)" }}>
              <strong className="text-emerald-400">How the workaround works:</strong> Your Meta access token is saved
              into this app's own database (the <code className="text-white/70">lms_settings</code> table)
              via a secure server-side hook. It is <strong>never returned to the browser</strong> — only a
              "configured / not configured" flag is. The token is read at runtime purely by server-side code
              when it calls the WhatsApp Cloud API.
            </div>

            <div className="grid md:grid-cols-3 gap-3">
              {/* Phone Number ID */}
              <label className="space-y-1">
                <span className="text-white/30 text-[11px] font-bold uppercase tracking-wide">
                  Phone Number ID
                  {configStatus?.has_phone_id && <span className="ml-1 text-emerald-400">✓ set</span>}
                </span>
                <input
                  type="text"
                  value={phoneId}
                  onChange={e => setPhoneId(e.target.value)}
                  placeholder={configStatus?.has_phone_id ? "Enter to update…" : "From Meta Business Manager"}
                  className="w-full px-3 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white text-sm outline-none focus:border-white/25 transition-colors font-mono placeholder:text-white/20"/>
              </label>

              {/* Access Token */}
              <label className="space-y-1 md:col-span-1">
                <span className="text-white/30 text-[11px] font-bold uppercase tracking-wide">
                  Permanent Access Token
                  {configStatus?.has_token && <span className="ml-1 text-emerald-400">✓ set</span>}
                </span>
                <div className="relative">
                  <input
                    type={showToken ? "text" : "password"}
                    value={token}
                    onChange={e => setToken(e.target.value)}
                    placeholder={configStatus?.has_token ? "Enter to update…" : "EAABsb..."}
                    className="w-full pl-3 pr-10 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white text-sm outline-none focus:border-white/25 transition-colors font-mono placeholder:text-white/20"/>
                  <button type="button" onClick={() => setShowToken(s => !s)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-white/25 hover:text-white/50 transition-colors">
                    {showToken ? <EyeOff size={14}/> : <Eye size={14}/>}
                  </button>
                </div>
              </label>

              {/* API Version */}
              <label className="space-y-1">
                <span className="text-white/30 text-[11px] font-bold uppercase tracking-wide">API Version</span>
                <select value={apiVersion} onChange={e => setApiVersion(e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white text-sm outline-none focus:border-white/25 transition-colors">
                  {["v20.0","v19.0","v18.0","v17.0"].map(v =>
                    <option key={v} value={v} className="bg-slate-900">{v}</option>)}
                </select>
              </label>
            </div>

            <div className="flex items-center gap-3">
              <button onClick={saveConfig}
                disabled={savingConfig || (!phoneId && !token)}
                className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-bold text-white transition-all disabled:opacity-40"
                style={{ background: "linear-gradient(135deg,#25d366,#128c7e)" }}>
                {savingConfig
                  ? <Loader2 size={14} className="animate-spin"/>
                  : <ShieldCheck size={14}/>}
                Save Credentials
              </button>

              {configStatus?.configured && (
                <button onClick={clearConfig} disabled={clearing}
                  className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-bold text-rose-400 border border-rose-500/20 hover:border-rose-500/40 transition-colors">
                  {clearing ? <Loader2 size={14} className="animate-spin"/> : <Trash2 size={14}/>}
                  Clear Credentials
                </button>
              )}
            </div>

            {configMsg && (
              <div className={`rounded-xl px-4 py-3 text-sm ${
                configMsg.ok
                  ? "bg-emerald-500/10 border border-emerald-500/20 text-emerald-300"
                  : "bg-rose-500/10 border border-rose-500/20 text-rose-300"
              }`}>
                {configMsg.text}
              </div>
            )}
          </div>
        )}
      </div>

      {/* ── How to submit to Meta ─────────────────────────────────────────── */}
      <div className="rounded-2xl border border-white/5 p-5"
        style={{ background: "rgba(255,255,255,0.02)" }}>
        <p className="text-white/60 text-sm font-semibold mb-3">How to submit a template to Meta for approval</p>
        <ol className="space-y-2">
          {[
            "Edit the template below to match your exact wording, then click \"Copy for Meta\".",
            "In Meta Business Manager, go to WhatsApp → Message Templates → Create Template.",
            "Fill in the form using the copied details (name, category, language, body, variables, buttons).",
            "Submit for review. Utility templates are typically approved within minutes; Marketing may take a few hours.",
            "Once approved, come back here, open the template, and set its status to \"Approved\" and toggle \"Active\" on.",
          ].map((step, i) => (
            <li key={i} className="flex items-start gap-3 text-xs text-white/40 leading-relaxed">
              <span className="shrink-0 w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold"
                style={{ background: "rgba(37,211,102,0.12)", color: "#25d366" }}>{i + 1}</span>
              {step}
            </li>
          ))}
        </ol>
      </div>

      {/* ── Templates ────────────────────────────────────────────────────── */}
      <div>
        <div className="flex items-start justify-between gap-4 mb-4 flex-wrap">
          <div>
            <h2 className="text-white font-bold">Message Templates</h2>
            <p className="text-white/35 text-sm mt-0.5">
              {submitted > 0 && `${submitted} awaiting Meta approval · `}
              {approved > 0 && `${approved} approved · `}
              {`${templates.length} total across 3 languages`}
            </p>
          </div>

          {/* Language filter tabs */}
          <div className="flex items-center gap-1 p-1 rounded-xl border border-white/8"
            style={{ background: "rgba(0,0,0,0.2)" }}>
            {([
              { key: "all",   label: "All",     count: templates.length },
              { key: "en",    label: "English",  count: templates.filter(t => t.language_code === "en").length },
              { key: "ms",    label: "Malay",    count: templates.filter(t => t.language_code === "ms").length },
              { key: "zh_CN", label: "Chinese",  count: templates.filter(t => t.language_code === "zh_CN").length },
            ] as const).map(tab => (
              <button
                key={tab.key}
                onClick={() => setLangFilter(tab.key)}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all"
                style={langFilter === tab.key
                  ? { background: "rgba(139,92,246,0.2)", color: "#a78bfa" }
                  : { color: "rgba(255,255,255,0.35)" }}>
                {tab.label}
                <span className="text-[10px] px-1 rounded-full"
                  style={{ background: "rgba(255,255,255,0.07)" }}>{tab.count}</span>
              </button>
            ))}
          </div>
        </div>

        {loadingAll ? (
          <div className="flex items-center justify-center py-16">
            <Loader2 size={24} className="text-white/20 animate-spin"/>
          </div>
        ) : (
          <div className="grid md:grid-cols-2 gap-4">
            {filteredTemplates.map(t => (
              <WaTemplateCard key={t.id} template={t} onSaved={handleTemplateSaved}/>
            ))}
          </div>
        )}
      </div>

    </div>
  );
}
