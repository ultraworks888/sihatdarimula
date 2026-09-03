import { useState, useEffect, type FormEvent } from "react";
import pb from "../../lib/pocketbase";
import { useLang } from "../../contexts/LanguageContext";
import GrowthChart from "../GrowthChart";

interface GrowthLog {
  id: string;
  date: string;
  weight_kg: number;
  height_cm: number;
  head_cm: number;
}

interface Props { childId: string; userId: string; childDob?: string }

export default function GrowthTracker({ childId, userId, childDob }: Props) {
  const { t } = useLang();
  const [logs, setLogs] = useState<GrowthLog[]>([]);
  const [date, setDate] = useState(new Date().toISOString().split("T")[0]);
  const [weight, setWeight] = useState("");
  const [height, setHeight] = useState("");
  const [head, setHead] = useState("");
  const [saving, setSaving] = useState(false);
  const [view, setView] = useState<"chart" | "log">("chart");

  const fetch_ = async () => {
    const r = await pb.collection("growth_logs").getList(1, 50, {
      filter: pb.filter("child = {:id}", { id: childId }),
      sort: "-date",
      requestKey: null,
    });
    setLogs(r.items.map(item => ({
      id: String(item.id),
      date: String(item.date ?? ""),
      weight_kg: Number(item.weight_kg ?? 0),
      height_cm: Number(item.height_cm ?? 0),
      head_cm: Number(item.head_cm ?? 0),
    })));
  };

  useEffect(() => { fetch_(); }, [childId]);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      await pb.collection("growth_logs").create({
        user: userId, child: childId, date,
        weight_kg: weight ? parseFloat(weight) : 0,
        height_cm: height ? parseFloat(height) : 0,
        head_cm: head ? parseFloat(head) : 0,
      });
      setWeight(""); setHeight(""); setHead("");
      await fetch_();
      setView("chart");
    } finally { setSaving(false); }
  };

  return (
    <div className="space-y-4">
      {/* View toggle */}
      <div className="glass-strong rounded-3xl p-1 flex gap-1">
        {(["chart", "log"] as const).map(v => (
          <button key={v} onClick={() => setView(v)}
            className={`flex-1 py-2 rounded-2xl text-sm font-semibold transition-all duration-200 ${
              view === v ? "glass-btn text-white" : "text-gray-500"
            }`}>
            {v === "chart" ? `📈 ${t("chart")}` : `➕ ${t("logGrowth")}`}
          </button>
        ))}
      </div>

      {view === "chart" && <GrowthChart logs={logs} childDob={childDob} />}

      {view === "log" && (
        <form onSubmit={submit} className="glass-strong rounded-3xl p-4 space-y-3 fade-up">
          <h3 className="font-bold text-gray-800 flex items-center gap-2">📏 {t("logGrowth")}</h3>
          <input type="date" value={date} onChange={e => setDate(e.target.value)}
            className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
          <div className="grid grid-cols-3 gap-2">
            <div>
              <label className="text-xs text-gray-500 font-medium block mb-1">{t("weightKg")}</label>
              <input type="number" step="0.01" value={weight} onChange={e => setWeight(e.target.value)}
                placeholder="4.5" className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
            </div>
            <div>
              <label className="text-xs text-gray-500 font-medium block mb-1">{t("heightCm")}</label>
              <input type="number" step="0.1" value={height} onChange={e => setHeight(e.target.value)}
                placeholder="55" className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
            </div>
            <div>
              <label className="text-xs text-gray-500 font-medium block mb-1">{t("headCm")}</label>
              <input type="number" step="0.1" value={head} onChange={e => setHead(e.target.value)}
                placeholder="36" className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
            </div>
          </div>
          <button type="submit" disabled={saving}
            className="glass-btn w-full py-2.5 rounded-2xl text-white font-bold text-sm">
            {saving ? t("saving") : t("saveEntry")}
          </button>
        </form>
      )}

      {/* Recent entries always visible when enough data */}
      {logs.length > 0 && (
        <div className="space-y-2">
          <h3 className="font-bold text-gray-700 text-sm">{t("recentEntries")}</h3>
          {logs.slice(0, 5).map(log => (
            <div key={log.id} className="glass rounded-2xl p-3 flex justify-between items-center">
              <span className="text-sm text-gray-500 font-medium">
                {new Date(log.date).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" })}
              </span>
              <div className="flex gap-3 text-sm font-semibold">
                {log.weight_kg > 0 && <span className="text-violet-600">{log.weight_kg} kg</span>}
                {log.height_cm > 0 && <span className="text-blue-600">{log.height_cm} cm</span>}
                {log.head_cm > 0 && <span className="text-emerald-600">{log.head_cm} cm 🧠</span>}
              </div>
            </div>
          ))}
          {logs.length > 5 && (
            <p className="text-center text-xs text-gray-400">+ {logs.length - 5} {t("recentEntries").toLowerCase()}</p>
          )}
        </div>
      )}
    </div>
  );
}
