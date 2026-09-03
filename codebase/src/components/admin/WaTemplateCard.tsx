import { useState } from "react";
import { ChevronDown, ChevronUp, Copy, Check, Save, X, Smartphone } from "lucide-react";
import pb from "../../lib/pocketbase";

// ── Types ─────────────────────────────────────────────────────────────────────

export interface TemplateVar {
  index: number;
  name: string;
  description: string;
  example: string;
}

export interface WaButton {
  type: "URL" | "PHONE_NUMBER" | "QUICK_REPLY";
  text: string;
  url?: string;
  phone?: string;
}

export interface WaTemplate {
  id: string;
  display_name: string;
  trigger_event: string;
  trigger_description: string;
  meta_template_name: string;
  category: "UTILITY" | "MARKETING" | "AUTHENTICATION";
  language_code: "en" | "ms" | "zh_CN";
  header_type: "NONE" | "TEXT" | "IMAGE";
  header_text: string;
  body: string;
  footer_text: string;
  buttons: WaButton[];
  variables: TemplateVar[];
  approval_status: "draft" | "submitted" | "approved" | "rejected";
  rejection_reason: string;
  is_active: boolean;
  sort_order: number;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const STATUS_META: Record<WaTemplate["approval_status"], { label: string; color: string; bg: string }> = {
  draft:     { label: "Draft",     color: "#94a3b8", bg: "rgba(148,163,184,0.12)" },
  submitted: { label: "Submitted", color: "#f59e0b", bg: "rgba(245,158,11,0.12)"  },
  approved:  { label: "Approved",  color: "#10b981", bg: "rgba(16,185,129,0.12)"  },
  rejected:  { label: "Rejected",  color: "#f43f5e", bg: "rgba(244,63,94,0.12)"   },
};

const TRIGGER_COLORS: Record<string, string> = {
  "user.registered":    "#8b5cf6",
  "user.enrolled":      "#3b82f6",
  "cron.weekly_nudge":  "#f59e0b",
  "user.completed_course": "#10b981",
  "admin.published_course":"#6366f1",
  "cron.baby_milestone":"#ec4899",
};

function renderBody(body: string, vars: TemplateVar[]): string {
  let t = body;
  // Named variables first: {{first_name}}, {{app_link}}, etc.
  for (const v of vars) {
    t = t.replace(new RegExp(`\\{\\{${v.name}\\}\\}`, "g"),
      `<span class="wa-var">${v.example}</span>`);
  }
  // Positional variables fallback: {{1}}, {{2}}, etc.
  for (const v of vars) {
    t = t.replace(new RegExp(`\\{\\{${v.index}\\}\\}`, "g"),
      `<span class="wa-var">${v.example}</span>`);
  }
  return t
    .replace(/\*([^*\n]+)\*/g, "<strong>$1</strong>")
    .replace(/_([^_\n]+)_/g,   "<em>$1</em>")
    .replace(/\n/g, "<br/>");
}

function buildMetaCopy(t: WaTemplate): string {
  const lines: string[] = [
    `Template Name : ${t.meta_template_name}`,
    `Category      : ${t.category}`,
    `Language      : ${t.language_code === "en" ? "English (en)" : t.language_code === "ms" ? "Malay (ms)" : "Chinese Simplified (zh_CN)"}`,
    "",
  ];
  if (t.header_type !== "NONE") {
    lines.push("[Header]");
    lines.push(`Type : ${t.header_type}`);
    if (t.header_text) lines.push(`Text : ${t.header_text}`);
    lines.push("");
  }
  lines.push("[Body]");
  lines.push(t.body);
  lines.push("");
  if (t.variables.length) {
    lines.push("[Variable Samples]");
    for (const v of t.variables) {
      lines.push(`  {{${v.name}}} — ${v.description}`);
      lines.push(`         Sample value: ${v.example}`);
    }
    lines.push("");
  }
  if (t.footer_text) {
    lines.push("[Footer]");
    lines.push(t.footer_text);
    lines.push("");
  }
  if (Array.isArray(t.buttons) && t.buttons.length) {
    lines.push("[Buttons]");
    t.buttons.forEach((b, i) => {
      lines.push(`  Button ${i + 1} (${b.type}): ${b.text}${b.url ? " → " + b.url : ""}`);
    });
  }
  return lines.join("\n");
}

// ── Component ─────────────────────────────────────────────────────────────────

interface Props {
  template: WaTemplate;
  onSaved: (updated: WaTemplate) => void;
}

export default function WaTemplateCard({ template, onSaved }: Props) {
  const [editing,  setEditing]  = useState(false);
  const [preview,  setPreview]  = useState(false);
  const [copying,  setCopying]  = useState(false);
  const [saving,   setSaving]   = useState(false);
  const [saveErr,  setSaveErr]  = useState<string | null>(null);
  const [form,     setForm]     = useState<WaTemplate>(template);

  const statusMeta  = STATUS_META[form.approval_status];
  const accentColor = TRIGGER_COLORS[template.trigger_event] ?? "#8b5cf6";

  const patch = (k: keyof WaTemplate, v: unknown) =>
    setForm(prev => ({ ...prev, [k]: v }));

  const handleSave = async () => {
    setSaving(true);
    setSaveErr(null);
    try {
      const updated = await pb.collection("whatsapp_templates").update(form.id, {
        display_name:       form.display_name,
        meta_template_name: form.meta_template_name,
        category:           form.category,
        language_code:      form.language_code,
        header_type:        form.header_type,
        header_text:        form.header_text,
        body:               form.body,
        footer_text:        form.footer_text,
        approval_status:    form.approval_status,
        rejection_reason:   form.rejection_reason,
        is_active:          form.is_active,
      }, { requestKey: null });
      onSaved({ ...form, ...updated });
      setEditing(false);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Save failed — please try again.";
      setSaveErr(msg);
    } finally {
      setSaving(false);
    }
  };

  const handleCopy = async () => {
    await navigator.clipboard.writeText(buildMetaCopy(form));
    setCopying(true);
    setTimeout(() => setCopying(false), 2000);
  };

  const handleCancel = () => {
    setForm(template);
    setEditing(false);
    setSaveErr(null);
  };

  return (
    <div className="rounded-2xl border border-white/5 overflow-hidden flex flex-col"
      style={{ background: "rgba(255,255,255,0.025)" }}>

      {/* Accent bar */}
      <div className="h-0.5" style={{ background: accentColor }} />

      {/* Header */}
      <div className="p-5 pb-4">
        <div className="flex items-start justify-between gap-3 mb-2">
          <div className="flex flex-wrap gap-1.5">
            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wide"
              style={{ background: `${accentColor}18`, color: accentColor }}>
              {form.trigger_event}
            </span>
            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wide"
              style={{ background: statusMeta.bg, color: statusMeta.color }}>
              {statusMeta.label}
            </span>
            {form.is_active && (
              <span className="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wide bg-emerald-500/15 text-emerald-400">
                Active
              </span>
            )}
          </div>
          <span className="text-white/20 text-xs shrink-0">{form.category}</span>
        </div>
        <h3 className="text-white font-semibold text-sm">{form.display_name}</h3>
        <p className="text-white/35 text-xs mt-0.5 leading-relaxed">{form.trigger_description}</p>
      </div>

      {/* WhatsApp preview toggle */}
      <button
        onClick={() => setPreview(p => !p)}
        className="mx-5 mb-3 flex items-center gap-2 text-xs text-white/35 hover:text-white/60 transition-colors"
      >
        <Smartphone size={12}/>
        {preview ? "Hide preview" : "Show message preview"}
        {preview ? <ChevronUp size={12}/> : <ChevronDown size={12}/>}
      </button>

      {preview && (
        <div className="mx-5 mb-4 rounded-xl overflow-hidden"
          style={{ background: "rgba(18,140,126,0.06)", border: "1px solid rgba(18,140,126,0.15)" }}>
          {/* WA-style bubble */}
          <div className="p-3">
            {form.header_type === "TEXT" && form.header_text && (
              <p className="text-white/80 text-xs font-bold mb-2">{form.header_text}</p>
            )}
            <p className="text-white/70 text-xs leading-relaxed"
              dangerouslySetInnerHTML={{ __html: renderBody(form.body, form.variables) }}/>
            {form.footer_text && (
              <p className="text-white/30 text-[10px] mt-2 italic">{form.footer_text}</p>
            )}
          </div>
          {Array.isArray(form.buttons) && form.buttons.length > 0 && (
            <div className="border-t border-white/5 divide-y divide-white/5">
              {form.buttons.map((b, i) => (
                <div key={i} className="px-3 py-2 text-xs text-center"
                  style={{ color: accentColor }}>{b.text}</div>
              ))}
            </div>
          )}
          <style>{`.wa-var{color:${accentColor};font-weight:600;}`}</style>
        </div>
      )}

      {/* Variables quick reference */}
      {form.variables.length > 0 && (
        <div className="mx-5 mb-4">
          <p className="text-white/20 text-[10px] font-bold uppercase tracking-wide mb-1.5">Variables</p>
          <div className="space-y-1">
            {form.variables.map(v => (
              <div key={v.index} className="flex items-baseline gap-2">
                 <span className="text-[10px] font-mono font-bold shrink-0"
                   style={{ color: accentColor }}>{`{{${v.name}}}`}</span>
                 <span className="text-white/40 text-[10px]">{v.description}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ── Edit form ──────────────────────────────────────────────────────── */}
      {editing && (
        <div className="mx-5 mb-4 space-y-3 p-4 rounded-xl border border-white/8"
          style={{ background: "rgba(0,0,0,0.2)" }}>

          {/* Display name + meta name */}
          <div className="grid grid-cols-2 gap-2">
            <label className="space-y-1">
              <span className="text-white/30 text-[10px] font-bold uppercase tracking-wide">Display Name</span>
              <input value={form.display_name}
                onChange={e => patch("display_name", e.target.value)}
                className="w-full px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs outline-none focus:border-white/25"/>
            </label>
            <label className="space-y-1">
              <span className="text-white/30 text-[10px] font-bold uppercase tracking-wide">Meta Template Name</span>
              <input value={form.meta_template_name}
                onChange={e => patch("meta_template_name", e.target.value.toLowerCase().replace(/[^a-z0-9_]/g,"_"))}
                className="w-full px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs outline-none focus:border-white/25 font-mono"/>
            </label>
          </div>

          {/* Category / Language / Header */}
          <div className="grid grid-cols-3 gap-2">
            <label className="space-y-1">
              <span className="text-white/30 text-[10px] font-bold uppercase tracking-wide">Category</span>
              <select value={form.category} onChange={e => patch("category", e.target.value)}
                className="w-full px-2 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs outline-none focus:border-white/25">
                <option value="UTILITY" className="bg-slate-900">UTILITY</option>
                <option value="MARKETING" className="bg-slate-900">MARKETING</option>
                <option value="AUTHENTICATION" className="bg-slate-900">AUTHENTICATION</option>
              </select>
            </label>
            <label className="space-y-1">
              <span className="text-white/30 text-[10px] font-bold uppercase tracking-wide">Language</span>
              <select value={form.language_code} onChange={e => patch("language_code", e.target.value)}
              className="w-full px-2 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs outline-none focus:border-white/25">
                 <option value="en"    className="bg-slate-900">English (en)</option>
                 <option value="ms"    className="bg-slate-900">Malay (ms)</option>
                 <option value="zh_CN" className="bg-slate-900">Chinese Simplified (zh_CN)</option>
               </select>
            </label>
            <label className="space-y-1">
              <span className="text-white/30 text-[10px] font-bold uppercase tracking-wide">Header</span>
              <select value={form.header_type} onChange={e => patch("header_type", e.target.value)}
                className="w-full px-2 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs outline-none focus:border-white/25">
                <option value="NONE" className="bg-slate-900">None</option>
                <option value="TEXT" className="bg-slate-900">Text</option>
                <option value="IMAGE" className="bg-slate-900">Image</option>
              </select>
            </label>
          </div>

          {/* Header text */}
          {form.header_type === "TEXT" && (
            <label className="space-y-1 block">
              <span className="text-white/30 text-[10px] font-bold uppercase tracking-wide">Header Text</span>
              <input value={form.header_text}
                onChange={e => patch("header_text", e.target.value)}
                placeholder="Header text (max 60 chars recommended)"
                className="w-full px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs outline-none focus:border-white/25"/>
            </label>
          )}

          {/* Body */}
          <label className="space-y-1 block">
            <span className="text-white/30 text-[10px] font-bold uppercase tracking-wide">
              Message Body
              <span className="ml-1 text-white/20 normal-case font-normal">
                — use *bold*, _italic_, {"{{first_name}}"} for named variables
              </span>
            </span>
            <textarea value={form.body}
              onChange={e => patch("body", e.target.value)}
              rows={7}
              className="w-full px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs outline-none focus:border-white/25 resize-y font-mono leading-relaxed"/>
          </label>

          {/* Footer */}
          <label className="space-y-1 block">
            <span className="text-white/30 text-[10px] font-bold uppercase tracking-wide">Footer Text</span>
            <input value={form.footer_text}
              onChange={e => patch("footer_text", e.target.value)}
              placeholder="Optional footer (often used for opt-out instructions)"
              className="w-full px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs outline-none focus:border-white/25"/>
          </label>

          {/* Approval status */}
          <div className="grid grid-cols-2 gap-2">
            <label className="space-y-1">
              <span className="text-white/30 text-[10px] font-bold uppercase tracking-wide">Approval Status</span>
              <select value={form.approval_status} onChange={e => patch("approval_status", e.target.value)}
                className="w-full px-2 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs outline-none focus:border-white/25">
                <option value="draft"     className="bg-slate-900">Draft</option>
                <option value="submitted" className="bg-slate-900">Submitted to Meta</option>
                <option value="approved"  className="bg-slate-900">Approved by Meta</option>
                <option value="rejected"  className="bg-slate-900">Rejected by Meta</option>
              </select>
            </label>
            <label className="space-y-1 flex flex-col justify-end">
              <span className="text-white/30 text-[10px] font-bold uppercase tracking-wide">Active (auto-send)</span>
              <div className="flex items-center gap-2 h-8">
                <button type="button"
                  onClick={() => patch("is_active", !form.is_active)}
                  className="relative w-9 h-5 rounded-full transition-colors"
                  style={{ background: form.is_active ? "#10b981" : "rgba(255,255,255,0.1)" }}>
                  <span className="absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white transition-transform"
                    style={{ transform: form.is_active ? "translateX(16px)" : "translateX(0)" }}/>
                </button>
                <span className="text-xs text-white/40">{form.is_active ? "On" : "Off"}</span>
              </div>
            </label>
          </div>

          {/* Rejection reason */}
          {form.approval_status === "rejected" && (
            <label className="space-y-1 block">
              <span className="text-white/30 text-[10px] font-bold uppercase tracking-wide">Rejection Reason</span>
              <input value={form.rejection_reason}
                onChange={e => patch("rejection_reason", e.target.value)}
                placeholder="Note the rejection reason from Meta Business Manager"
                className="w-full px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs outline-none focus:border-white/25"/>
            </label>
          )}

        </div>
      )}

      {/* Footer actions */}
      <div className="px-5 pb-5 mt-auto flex flex-col gap-2">
        {saveErr && (
          <p className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg px-3 py-2">
            {saveErr}
          </p>
        )}
        <div className="flex items-center gap-2 flex-wrap">
        {editing ? (
          <>
            <button onClick={handleSave} disabled={saving}
              className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold text-white transition-all disabled:opacity-50"
              style={{ background: "linear-gradient(135deg,#7c3aed,#6366f1)" }}>
              {saving ? <div className="w-3.5 h-3.5 border-2 border-white/30 border-t-white rounded-full animate-spin"/> : <Save size={12}/>}
              Save Changes
            </button>
            <button onClick={handleCancel}
              className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold text-white/50 border border-white/10 hover:text-white/70 transition-colors">
              <X size={12}/> Cancel
            </button>
          </>
        ) : (
          <button onClick={() => setEditing(true)}
            className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold text-white border border-white/10 hover:border-white/20 transition-colors">
            Edit Template
          </button>
        )}

        <button onClick={handleCopy}
          className="ml-auto flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold transition-all"
          style={{ color: copying ? "#10b981" : accentColor, border: `1px solid ${accentColor}30`, background: `${accentColor}0d` }}>
          {copying ? <Check size={12}/> : <Copy size={12}/>}
          {copying ? "Copied!" : "Copy for Meta"}
        </button>
        </div>
      </div>
    </div>
  );
}
