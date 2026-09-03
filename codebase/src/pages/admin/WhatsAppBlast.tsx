import { useState } from "react";
import pb from "../../lib/pocketbase";
import { Send, Plus, Trash2, Info } from "lucide-react";

interface BlastResult {
  total_users: number;
  sent: number;
  failed: number;
  skipped: number;
  failures: { phone: string; status?: number; error?: string }[];
}

export default function WhatsAppBlast() {
  const [templateId, setTemplateId] = useState("");
  const [language, setLanguage] = useState("en");
  const [templateValues, setTemplateValues] = useState<string[]>([""]);
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<BlastResult | null>(null);
  const [error, setError] = useState("");
  const [showConfirm, setShowConfirm] = useState(false);

  const addValue = () => setTemplateValues(prev => [...prev, ""]);
  const removeValue = (i: number) => setTemplateValues(prev => prev.filter((_, idx) => idx !== i));
  const updateValue = (i: number, val: string) => setTemplateValues(prev => prev.map((v, idx) => idx === i ? val : v));

  const handleSend = async () => {
    if (!templateId || isNaN(Number(templateId))) {
      setError("Please enter a valid Brevo template ID (a number)."); return;
    }
    setShowConfirm(false);
    setSending(true);
    setError("");
    setResult(null);
    try {
      const data = await pb.send("/api/admin/whatsapp-blast", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          templateId: Number(templateId),
          language,
          templateValues: templateValues.filter(v => v.trim() !== ""),
        }),
      });
      setResult(data as BlastResult);
    } catch (err: unknown) {
      const e = err as { data?: { message?: string }; message?: string };
      setError(e?.data?.message ?? e?.message ?? "Failed to send. Check Brevo configuration in lms_settings.");
    } finally { setSending(false); }
  };

  return (
    <div className="max-w-2xl space-y-6">
      <div>
        <h2 className="text-white font-bold text-xl">WhatsApp Blast</h2>
        <p className="text-white/40 text-sm mt-0.5">Send a pre-approved template message to all registered users with a phone number.</p>
      </div>

      {/* Setup note */}
      <div className="flex gap-3 bg-amber-500/10 border border-amber-500/20 rounded-2xl p-4">
        <Info size={16} className="text-amber-400 shrink-0 mt-0.5" />
        <div className="text-amber-300 text-xs leading-relaxed space-y-1">
          <p className="font-semibold">Before using this feature:</p>
          <p>1. Create and get your WhatsApp template approved in your <strong>Brevo dashboard</strong>.</p>
          <p>2. Add <code className="bg-amber-500/20 px-1 rounded">brevo_api_key</code> and <code className="bg-amber-500/20 px-1 rounded">whatsapp_sender_number</code> to the <strong>lms_settings</strong> collection in PocketBase admin.</p>
          <p>{'3. Enter the numeric template ID below and the positional template values ({{1}}, {{2}}, etc.).'}</p>
          <p>{'Use {{user.name}} in any value to personalise it with the recipient\'s name.'}</p>
        </div>
      </div>

      <div className="bg-white/5 border border-white/10 rounded-2xl p-5 space-y-4">
        {/* Template ID */}
        <div>
          <label className="text-white/60 text-sm font-semibold block mb-1.5">Brevo Template ID *</label>
          <input type="number" value={templateId} onChange={e => setTemplateId(e.target.value)} placeholder="e.g. 42"
            className="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none placeholder-white/20 focus:border-amber-500/40 transition-colors" />
        </div>

        {/* Language */}
        <div>
          <label className="text-white/60 text-sm font-semibold block mb-1.5">Template Language</label>
          <select value={language} onChange={e => setLanguage(e.target.value)}
            className="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none">
            <option value="en" className="bg-slate-900">English (en)</option>
            <option value="ms" className="bg-slate-900">Bahasa Malaysia (ms)</option>
            <option value="zh" className="bg-slate-900">Chinese (zh)</option>
          </select>
        </div>

        {/* Template body values */}
        <div>
          <label className="text-white/60 text-sm font-semibold block mb-1.5">Template Body Values</label>
          <p className="text-white/30 text-xs mb-2.5">
            {'Values for {{1}}, {{2}}, ... in order. Use '}
            <span className="text-amber-400">{'{{user.name}}'}</span>
            {' to personalise with the recipient\'s name.'}
          </p>
          <div className="space-y-2">
            {templateValues.map((val, i) => (
              <div key={i} className="flex items-center gap-2">
                <span className="text-white/30 text-xs w-6 text-right shrink-0">{"{{"}{i + 1}{"}}"}</span>
                <input value={val} onChange={e => updateValue(i, e.target.value)}
                  placeholder={`Value for {{${i + 1}}} — e.g. {{user.name}}`}
                  className="flex-1 px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none placeholder-white/20 focus:border-amber-500/40 transition-colors" />
                {templateValues.length > 1 && (
                  <button onClick={() => removeValue(i)} className="text-rose-400/60 hover:text-rose-400 transition-colors shrink-0">
                    <Trash2 size={14} />
                  </button>
                )}
              </div>
            ))}
          </div>
          <button onClick={addValue} className="mt-2 flex items-center gap-1.5 text-white/40 hover:text-white/70 text-xs transition-colors">
            <Plus size={13} /> Add another value
          </button>
        </div>
      </div>

      {error && (
        <div className="px-4 py-3 bg-rose-500/10 border border-rose-500/20 rounded-xl text-rose-300 text-sm">{error}</div>
      )}

      {/* Result */}
      {result && (
        <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-2xl p-5 space-y-3">
          <p className="text-emerald-400 font-bold">Blast sent!</p>
          <div className="grid grid-cols-4 gap-3">
            {[
              ["Total", result.total_users],
              ["Sent", result.sent],
              ["Failed", result.failed],
              ["Skipped", result.skipped],
            ].map(([label, val]) => (
              <div key={label as string} className="text-center">
                <p className="text-2xl font-bold text-white">{val}</p>
                <p className="text-white/40 text-xs">{label}</p>
              </div>
            ))}
          </div>
          {result.failures.length > 0 && (
            <div className="mt-2">
              <p className="text-white/50 text-xs font-semibold mb-1">Failed deliveries:</p>
              <div className="space-y-1">
                {result.failures.map((f, i) => (
                  <p key={i} className="text-white/30 text-[11px] font-mono">
                    {f.phone} — {f.status ? `HTTP ${f.status}` : f.error ?? "error"}
                  </p>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Send button */}
      {!result && (
        <button onClick={() => setShowConfirm(true)} disabled={sending || !templateId}
          className="flex items-center gap-2 px-6 py-3 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-2xl text-sm disabled:opacity-40 transition-all">
          <Send size={16} /> {sending ? "Sending..." : "Send to All Users"}
        </button>
      )}
      {result && (
        <button onClick={() => { setResult(null); setTemplateId(""); setTemplateValues([""]); }}
          className="text-sm text-white/40 hover:text-white/70 transition-colors">
          ← Send another blast
        </button>
      )}

      {/* Confirmation dialog */}
      {showConfirm && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-white/10 rounded-3xl p-6 max-w-sm w-full space-y-4">
            <h3 className="text-white font-bold text-lg">Confirm Blast</h3>
            <p className="text-white/60 text-sm leading-relaxed">
              This will send a WhatsApp message to <strong className="text-white">all registered users</strong> who have a phone number. This action cannot be undone.
            </p>
            <p className="text-amber-400 text-xs">Template ID: <strong>{templateId}</strong> · Language: <strong>{language}</strong></p>
            <div className="flex gap-3">
              <button onClick={() => setShowConfirm(false)} className="flex-1 py-2.5 bg-white/10 hover:bg-white/15 text-white rounded-xl text-sm font-semibold transition-all">Cancel</button>
              <button onClick={handleSend} className="flex-1 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-sm font-bold transition-all">Send Now</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
