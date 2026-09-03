import { useState, useEffect } from "react";
import { ShieldCheck, AlertTriangle, Eye, EyeOff, RefreshCw } from "lucide-react";
import pb from "../../lib/pocketbase";

interface AiRecord { id: string; gemini_key: string; model_id: string }

const MODEL_SUGGESTIONS = [
  "gemini-3.5-flash-lite",
  "gemini-3.5-flash",
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
];

export default function AISettings() {
  const [record, setRecord]   = useState<AiRecord | null>(null);
  const [apiKey, setApiKey]   = useState("");
  const [modelId, setModelId] = useState("");
  const [showKey, setShowKey] = useState(false);
  const [saving, setSaving]   = useState(false);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg]         = useState<{ ok: boolean; text: string } | null>(null);

  const load = async () => {
    setLoading(true);
    try {
      const r = await pb.collection("ai_settings").getFirstListItem('id != ""', { requestKey: null }) as unknown as AiRecord;
      setRecord(r);
      setModelId(r.model_id || "gemini-3.5-flash-lite");
    } catch {
      setRecord(null);
    }
    setLoading(false);
  };

  useEffect(() => { load(); }, []);

  const save = async () => {
    setSaving(true);
    setMsg(null);
    try {
      const payload = { model_id: modelId.trim() || "gemini-3.5-flash-lite" } as Record<string, string>;
      if (apiKey.trim()) payload.gemini_key = apiKey.trim();

      if (record?.id) {
        await pb.collection("ai_settings").update(record.id, payload);
      } else {
        await pb.collection("ai_settings").create(payload);
      }
      setApiKey("");
      setMsg({ ok: true, text: "Settings saved successfully." });
      await load();
    } catch (err: unknown) {
      const detail = err instanceof Error ? err.message : "Unknown error";
      setMsg({ ok: false, text: `Failed to save: ${detail}` });
    } finally {
      setSaving(false);
    }
  };

  const configured = !!(record?.gemini_key);

  return (
    <div className="max-w-2xl space-y-6">
      <div>
        <h2 className="text-white font-bold text-xl">AI Chatbot Settings</h2>
        <p className="text-white/40 text-sm mt-0.5">
          Configure the Gemini API key and model that power the in-app parenting assistant.
        </p>
      </div>

      {/* Status badge */}
      {loading ? (
        <div className="flex items-center gap-2 text-white/30 text-sm">
          <RefreshCw size={14} className="animate-spin" /> Checking status...
        </div>
      ) : configured ? (
        <div className="flex items-center gap-3 px-4 py-3 rounded-2xl border bg-emerald-500/10 border-emerald-500/20 text-emerald-400">
          <ShieldCheck size={18} />
          <div>
            <p className="text-sm font-semibold">Gemini API key is active — chatbot is live.</p>
            <p className="text-xs text-emerald-400/60 mt-0.5">
              Key starts with: <span className="font-mono">{record?.gemini_key?.slice(0, 8)}...</span>
              &nbsp;·&nbsp;Model: <span className="font-mono">{record?.model_id || "gemini-2.5-flash"}</span>
            </p>
          </div>
        </div>
      ) : (
        <div className="flex items-center gap-3 px-4 py-3 rounded-2xl border bg-amber-500/10 border-amber-500/20 text-amber-400">
          <AlertTriangle size={18} />
          <p className="text-sm font-semibold">No API key found — chatbot is inactive.</p>
        </div>
      )}

      {/* How-to */}
      <div className="bg-white/5 border border-white/10 rounded-2xl p-5 space-y-3">
        <p className="text-white font-semibold text-sm">How to get a free Gemini API key</p>
        <ol className="space-y-1.5 text-white/50 text-sm list-decimal list-inside">
          <li>Go to <span className="text-violet-400 font-medium">aistudio.google.com</span></li>
          <li>Sign in with your Google account</li>
          <li>Click <strong className="text-white/70">Get API key</strong> → <strong className="text-white/70">Create API key</strong></li>
          <li>Copy the key and paste it below</li>
        </ol>
        <p className="text-white/30 text-xs">Free tier: up to 1 million tokens/day.</p>
      </div>

      {/* Settings form */}
      <div className="bg-white/5 border border-white/10 rounded-2xl p-5 space-y-5">
        <p className="text-white/70 text-sm font-semibold">
          {configured ? "Update Settings" : "Enter Settings"}
        </p>

        {/* API key */}
        <div className="space-y-1.5">
          <label className="text-white/50 text-xs">
            Gemini API Key {configured && <span className="text-white/30">(leave blank to keep existing)</span>}
          </label>
          <div className="relative">
            <input
              type={showKey ? "text" : "password"}
              value={apiKey}
              onChange={e => setApiKey(e.target.value)}
              placeholder={configured ? "Leave blank to keep current key" : "Paste your key here..."}
              className="w-full px-4 py-2.5 pr-10 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none placeholder-white/20 focus:border-violet-500/40 transition-colors font-mono"
            />
            <button
              type="button"
              onClick={() => setShowKey(v => !v)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-white/30 hover:text-white/60 transition-colors"
            >
              {showKey ? <EyeOff size={15} /> : <Eye size={15} />}
            </button>
          </div>
        </div>

        {/* Model name */}
        <div className="space-y-1.5">
          <label className="text-white/50 text-xs">Gemini Model ID</label>
          <input
            type="text"
            value={modelId}
            onChange={e => setModelId(e.target.value)}
            placeholder="e.g. gemini-2.5-flash"
            className="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none placeholder-white/20 focus:border-violet-500/40 transition-colors font-mono"
          />
          <div className="flex flex-wrap gap-2 pt-1">
            {MODEL_SUGGESTIONS.map(m => (
              <button
                key={m}
                onClick={() => setModelId(m)}
                className={`text-xs px-2.5 py-1 rounded-lg border transition-colors font-mono ${
                  modelId === m
                    ? "bg-violet-500/20 border-violet-500/40 text-violet-300"
                    : "bg-white/5 border-white/10 text-white/40 hover:text-white/60"
                }`}
              >
                {m}
              </button>
            ))}
          </div>
          <p className="text-white/25 text-xs">
            Find the exact model ID in your{" "}
            <span className="text-violet-400/70">aistudio.google.com</span> project settings.
            "Gemini 3.5 Flash Lite" in the UI maps to{" "}
            <span className="font-mono text-white/40">gemini-3.5-flash-lite</span>.
          </p>
        </div>

        {msg && (
          <p className={`text-sm ${msg.ok ? "text-emerald-400" : "text-rose-400"}`}>{msg.text}</p>
        )}

        <div className="flex items-center gap-3">
          <button
            onClick={save}
            disabled={saving || (!apiKey.trim() && !configured)}
            className="px-5 py-2.5 rounded-xl text-white text-sm font-bold disabled:opacity-40 transition-all hover:opacity-90"
            style={{ background: "linear-gradient(135deg,#7c3aed,#ec4899)" }}
          >
            {saving ? "Saving..." : "Save Settings"}
          </button>
          <button onClick={load} className="text-white/30 hover:text-white/60 transition-colors" title="Refresh">
            <RefreshCw size={15} />
          </button>
        </div>
      </div>

      {/* Feature info */}
      <div className="bg-white/5 border border-white/10 rounded-2xl p-5 space-y-2">
        <p className="text-white font-semibold text-sm">What the chatbot does</p>
        <ul className="space-y-1 text-white/50 text-sm">
          <li>• Answers parenting questions in English, Bahasa Malaysia, and Chinese</li>
          <li>• Covers pregnancy, baby development, nutrition, breastfeeding, and wellbeing</li>
          <li>• Responds in the same language the user writes in</li>
          <li>• Keeps answers under 150 words; refers medical concerns to a doctor</li>
          <li>• Accessible via the AI button in the bottom-right corner of the app</li>
        </ul>
      </div>
    </div>
  );
}
