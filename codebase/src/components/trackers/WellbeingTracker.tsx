import { useState, useEffect, type FormEvent } from "react";
import pb from "../../lib/pocketbase";
import { useLang } from "../../contexts/LanguageContext";

interface Props { userId: string }

const moods = ["😢", "😟", "😐", "🙂", "😊", "😄", "🤗", "😍", "🥰", "🌟"];

export default function WellbeingTracker({ userId }: Props) {
  const { t } = useLang();
  const [logs, setLogs] = useState<Record<string, unknown>[]>([]);
  const [type, setType] = useState<"mood" | "epds">("mood");
  const [date, setDate] = useState(new Date().toISOString().split("T")[0]);
  const [moodScore, setMoodScore] = useState(5);
  const [epdsScore, setEpdsScore] = useState("");
  const [notes, setNotes] = useState("");
  const [saving, setSaving] = useState(false);

  const fetch_ = async () => {
    const r = await pb.collection("wellbeing_logs").getList(1, 20, {
      filter: pb.filter("user = {:id}", { id: userId }), sort: "-date", requestKey: null,
    });
    setLogs(r.items);
  };
  useEffect(() => { fetch_(); }, [userId]);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      await pb.collection("wellbeing_logs").create({
        user: userId, date, type,
        mood_score: type === "mood" ? moodScore : 0,
        epds_score: type === "epds" && epdsScore ? parseInt(epdsScore) : 0,
        notes,
      });
      setNotes(""); setEpdsScore("");
      await fetch_();
    } finally { setSaving(false); }
  };

  return (
    <div className="space-y-4">
      <form onSubmit={submit} className="glass-strong rounded-3xl p-4 space-y-3">
        <h3 className="font-bold text-gray-800">💜 {t("wellbeingCheckin")}</h3>
        <div className="flex gap-2">
          <button type="button" onClick={() => setType("mood")}
            className={`flex-1 py-2 rounded-2xl text-sm font-semibold transition-all ${type === "mood" ? "glass-btn text-white" : "glass text-gray-600"}`}>
            😊 {t("moodLog")}
          </button>
          <button type="button" onClick={() => setType("epds")}
            className={`flex-1 py-2 rounded-2xl text-sm font-semibold transition-all ${type === "epds" ? "glass-btn text-white" : "glass text-gray-600"}`}>
            📋 {t("epdsScreen")}
          </button>
        </div>
        <input type="date" value={date} onChange={e => setDate(e.target.value)} className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
        {type === "mood" ? (
          <div>
            <label className="text-xs text-gray-500 font-medium mb-2 block">{t("howFeeling")} ({moodScore}/10)</label>
            <div className="flex justify-between items-center glass rounded-2xl p-3">
              {moods.map((emoji, i) => (
                <button key={i} type="button" onClick={() => setMoodScore(i + 1)}
                  className={`text-xl transition-transform ${moodScore === i + 1 ? "scale-150" : "opacity-40 hover:opacity-70"}`}>{emoji}</button>
              ))}
            </div>
          </div>
        ) : (
          <div>
            <label className="text-xs text-gray-500 font-medium">{t("epdsScore")}</label>
            <input type="number" min={0} max={30} value={epdsScore} onChange={e => setEpdsScore(e.target.value)} placeholder={t("enterScore")}
              className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
            <p className="text-xs text-gray-400 mt-1">{t("epdsWarning")}</p>
          </div>
        )}
        <textarea value={notes} onChange={e => setNotes(e.target.value)} placeholder={t("howFeelingToday")} rows={2}
          className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none resize-none" />
        <button type="submit" disabled={saving} className="glass-btn w-full py-2.5 rounded-2xl text-white font-bold text-sm">
          {saving ? t("saving") : t("saveCheckin")}
        </button>
      </form>
      <div className="space-y-2">
        <h3 className="font-bold text-gray-700 text-sm">{t("recentCheckins")}</h3>
        {logs.length === 0 ? (
          <p className="text-gray-400 text-sm text-center py-8">{t("noWellbeingEntries")}</p>
        ) : logs.map(log => {
          const isMood = log.type === "mood";
          const score = isMood ? Number(log.mood_score) : Number(log.epds_score);
          return (
            <div key={String(log.id)} className="glass rounded-2xl p-3 flex items-center gap-3">
              <span className="text-lg">{isMood ? (moods[score - 1] || "😐") : "📋"}</span>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-gray-800">{isMood ? `${t("moodLog")}: ${score}/10` : `EPDS: ${score}/30`}</p>
                {log.notes && <p className="text-xs text-gray-400 truncate">{String(log.notes)}</p>}
              </div>
              <span className="text-xs text-gray-400 shrink-0">{new Date(String(log.date)).toLocaleDateString()}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
