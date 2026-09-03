import { useState, useEffect, type FormEvent } from "react";
import pb from "../../lib/pocketbase";
import { useLang } from "../../contexts/LanguageContext";

interface Props { childId: string; userId: string }

export default function ActivityTracker({ childId, userId }: Props) {
  const { t } = useLang();
  const [logs, setLogs] = useState<Record<string, unknown>[]>([]);
  const [type, setType] = useState("tummy_time");
  const [date, setDate] = useState(new Date().toISOString().split("T")[0]);
  const [duration, setDuration] = useState("");
  const [milestone, setMilestone] = useState("");
  const [notes, setNotes] = useState("");
  const [saving, setSaving] = useState(false);

  const fetch_ = async () => {
    const r = await pb.collection("activity_logs").getList(1, 20, {
      filter: pb.filter("child = {:id}", { id: childId }), sort: "-date", requestKey: null,
    });
    setLogs(r.items);
  };
  useEffect(() => { fetch_(); }, [childId]);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      await pb.collection("activity_logs").create({
        user: userId, child: childId, date, type,
        duration_min: duration ? parseInt(duration) : 0,
        milestone_name: milestone, notes,
      });
      setDuration(""); setMilestone(""); setNotes("");
      await fetch_();
    } finally { setSaving(false); }
  };

  const actTypes = [
    { value: "tummy_time", label: `🐣 ${t("tummyTime")}` },
    { value: "milestone", label: `🏆 ${t("milestone")}` },
    { value: "playtime", label: `🎮 ${t("playtime")}` },
  ];
  const icons: Record<string, string> = { tummy_time: "🐣", milestone: "🏆", playtime: "🎮" };

  return (
    <div className="space-y-4">
      <form onSubmit={submit} className="glass-strong rounded-3xl p-4 space-y-3">
        <h3 className="font-bold text-gray-800">🎯 {t("logActivity")}</h3>
        <div className="grid grid-cols-3 gap-2">
          {actTypes.map(tp => (
            <button key={tp.value} type="button" onClick={() => setType(tp.value)}
              className={`py-2 rounded-2xl text-xs font-semibold transition-all ${type === tp.value ? "glass-btn text-white" : "glass text-gray-600"}`}>
              {tp.label}
            </button>
          ))}
        </div>
        <input type="date" value={date} onChange={e => setDate(e.target.value)} className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
        {type !== "milestone" && (
          <div>
            <label className="text-xs text-gray-500 font-medium">{t("durationMin")}</label>
            <input type="number" value={duration} onChange={e => setDuration(e.target.value)} placeholder="10" className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
          </div>
        )}
        {type === "milestone" && (
          <div>
            <label className="text-xs text-gray-500 font-medium">{t("milestone")}</label>
            <input type="text" value={milestone} onChange={e => setMilestone(e.target.value)} placeholder={t("milestonePlaceholder")} className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
          </div>
        )}
        <textarea value={notes} onChange={e => setNotes(e.target.value)} placeholder={t("notesOptional")} rows={2}
          className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none resize-none" />
        <button type="submit" disabled={saving} className="glass-btn w-full py-2.5 rounded-2xl text-white font-bold text-sm">
          {saving ? t("saving") : t("saveEntry")}
        </button>
      </form>
      <div className="space-y-2">
        <h3 className="font-bold text-gray-700 text-sm">{t("recentEntries")}</h3>
        {logs.length === 0 ? (
          <p className="text-gray-400 text-sm text-center py-8">{t("noActivityEntries")}</p>
        ) : logs.map(log => (
          <div key={String(log.id)} className="glass rounded-2xl p-3 flex items-center gap-3">
            <span className="text-lg">{icons[String(log.type)] || "🎯"}</span>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold text-gray-800">{actTypes.find(tp => tp.value === String(log.type))?.label.slice(2) || String(log.type)}</p>
              {log.milestone_name && <p className="text-xs text-violet-600 font-medium">{String(log.milestone_name)}</p>}
              {log.notes && <p className="text-xs text-gray-400 truncate">{String(log.notes)}</p>}
            </div>
            <div className="text-right shrink-0">
              <p className="text-xs text-gray-400">{new Date(String(log.date)).toLocaleDateString()}</p>
              {Number(log.duration_min) > 0 && <p className="text-xs text-gray-500 font-medium">{String(log.duration_min)} min</p>}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
