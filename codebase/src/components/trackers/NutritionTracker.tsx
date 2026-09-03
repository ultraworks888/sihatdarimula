import { useState, useEffect, useRef, type FormEvent } from "react";
import pb from "../../lib/pocketbase";
import { useLang } from "../../contexts/LanguageContext";

interface Props { childId: string; userId: string }

export default function NutritionTracker({ childId, userId }: Props) {
  const { t } = useLang();
  const [logs, setLogs] = useState<Record<string, unknown>[]>([]);
  const [type, setType] = useState("breastfeed");
  const [date, setDate] = useState(new Date().toISOString().split("T")[0]);
  const [duration, setDuration] = useState("");
  const [volume, setVolume] = useState("");
  const [food, setFood] = useState("");
  const [notes, setNotes] = useState("");
  const [saving, setSaving] = useState(false);

  const [timerActive, setTimerActive] = useState(false);
  const [timerPaused, setTimerPaused] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [feedSide, setFeedSide] = useState<"left" | "right">("left");
  const intervalRef = useRef<number | null>(null);

  useEffect(() => {
    if (timerActive && !timerPaused) {
      intervalRef.current = window.setInterval(() => setElapsed(p => p + 1), 1000);
    }
    return () => { if (intervalRef.current) clearInterval(intervalRef.current); };
  }, [timerActive, timerPaused]);

  const fetch_ = async () => {
    const r = await pb.collection("nutrition_logs").getList(1, 20, {
      filter: pb.filter("child = {:id}", { id: childId }), sort: "-date", requestKey: null,
    });
    setLogs(r.items);
  };
  useEffect(() => { fetch_(); }, [childId]);

  const formatTime = (s: number) => `${Math.floor(s / 60).toString().padStart(2, "0")}:${(s % 60).toString().padStart(2, "0")}`;

  const startTimer = () => { setTimerActive(true); setTimerPaused(false); setElapsed(0); };
  const pauseTimer = () => setTimerPaused(true);
  const resumeTimer = () => setTimerPaused(false);

  const stopAndSave = async () => {
    setTimerActive(false);
    setTimerPaused(false);
    if (intervalRef.current) clearInterval(intervalRef.current);
    const mins = Math.max(1, Math.ceil(elapsed / 60));
    setSaving(true);
    try {
      await pb.collection("nutrition_logs").create({
        user: userId, child: childId, date: new Date().toISOString().split("T")[0],
        type: "breastfeed", duration_min: mins,
        notes: feedSide === "left" ? t("leftSide") : t("rightSide"),
      });
      setElapsed(0);
      await fetch_();
    } finally { setSaving(false); }
  };

  const submitManual = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      await pb.collection("nutrition_logs").create({
        user: userId, child: childId, date, type,
        duration_min: duration ? parseInt(duration) : 0,
        volume_ml: volume ? parseInt(volume) : 0,
        food_name: food, notes,
      });
      setDuration(""); setVolume(""); setFood(""); setNotes("");
      await fetch_();
    } finally { setSaving(false); }
  };

  const types = [
    { value: "breastfeed", label: `🤱 ${t("breastfeed")}` },
    { value: "formula", label: `🍼 ${t("formula")}` },
    { value: "solid", label: `🥣 ${t("solidFood")}` },
    { value: "prenatal_diet", label: `🥗 ${t("prenatalDiet")}` },
  ];
  const typeIcons: Record<string, string> = { breastfeed: "🤱", formula: "🍼", solid: "🥣", prenatal_diet: "🥗" };

  return (
    <div className="space-y-4">
      {/* Type selector */}
      <div className="glass-strong rounded-3xl p-4 space-y-3">
        <h3 className="font-bold text-gray-800">🍼 {t("logNutrition")}</h3>
        <div className="grid grid-cols-2 gap-2">
          {types.map(tp => (
            <button key={tp.value} type="button" onClick={() => { setType(tp.value); if (timerActive) { setTimerActive(false); setTimerPaused(false); setElapsed(0); if (intervalRef.current) clearInterval(intervalRef.current); } }}
              className={`py-2 rounded-2xl text-xs font-semibold transition-all ${type === tp.value ? "glass-btn text-white" : "glass text-gray-600"}`}>
              {tp.label}
            </button>
          ))}
        </div>
      </div>

      {/* Breastfeed timer */}
      {type === "breastfeed" && (
        <div className="glass rounded-3xl p-5 relative overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-br from-violet-500/5 via-transparent to-rose-500/5 pointer-events-none" />
          <h3 className="font-bold text-gray-800 text-center mb-4 relative z-10">⏱ {t("feedingTimer")}</h3>
          <div className="flex justify-center mb-4 relative z-10">
            <div className="w-32 h-32 rounded-full glass-strong flex items-center justify-center" style={{ boxShadow: "0 8px 32px rgba(139,92,246,0.12), inset 0 2px 0 rgba(255,255,255,0.5)" }}>
              <span className="text-3xl font-bold text-violet-600 tabular-nums">{formatTime(elapsed)}</span>
            </div>
          </div>
          <div className="flex justify-center gap-3 mb-4 relative z-10">
            <button onClick={() => setFeedSide("left")}
              className={`px-5 py-2 rounded-full text-sm font-semibold transition-all ${feedSide === "left" ? "glass-btn text-white" : "glass text-gray-600"}`}>
              ◀ {t("leftSide")}
            </button>
            <button onClick={() => setFeedSide("right")}
              className={`px-5 py-2 rounded-full text-sm font-semibold transition-all ${feedSide === "right" ? "glass-btn text-white" : "glass text-gray-600"}`}>
              {t("rightSide")} ▶
            </button>
          </div>
          <div className="flex gap-2 relative z-10">
            {!timerActive ? (
              <button onClick={startTimer} className="flex-1 py-3 rounded-2xl bg-emerald-500/85 backdrop-blur-sm text-white font-bold text-sm border border-emerald-400/30 hover:bg-emerald-500 transition-all">
                ▶ {t("start")}
              </button>
            ) : (
              <>
                {timerPaused ? (
                  <button onClick={resumeTimer} className="flex-1 py-3 rounded-2xl bg-blue-500/85 backdrop-blur-sm text-white font-bold text-sm border border-blue-400/30">
                    ▶ {t("resume")}
                  </button>
                ) : (
                  <button onClick={pauseTimer} className="flex-1 py-3 rounded-2xl bg-amber-500/85 backdrop-blur-sm text-white font-bold text-sm border border-amber-400/30">
                    ⏸ {t("pause")}
                  </button>
                )}
                <button onClick={stopAndSave} disabled={saving || elapsed < 5}
                  className="flex-1 py-3 rounded-2xl bg-rose-500/85 backdrop-blur-sm text-white font-bold text-sm border border-rose-400/30 disabled:opacity-50">
                  ⏹ {t("stopSave")}
                </button>
              </>
            )}
          </div>
        </div>
      )}

      {/* Manual form */}
      <form onSubmit={submitManual} className="glass rounded-3xl p-4 space-y-3">
        <h3 className="text-sm font-semibold text-gray-600">{type === "breastfeed" ? `${t("logNutrition")} (${t("durationMin")})` : t("logNutrition")}</h3>
        <input type="date" value={date} onChange={e => setDate(e.target.value)} className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
        {(type === "breastfeed") && (
          <div>
            <label className="text-xs text-gray-500 font-medium">{t("durationMin")}</label>
            <input type="number" value={duration} onChange={e => setDuration(e.target.value)} placeholder="15" className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
          </div>
        )}
        {type === "formula" && (
          <div>
            <label className="text-xs text-gray-500 font-medium">{t("volumeMl")}</label>
            <input type="number" value={volume} onChange={e => setVolume(e.target.value)} placeholder="120" className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
          </div>
        )}
        {(type === "solid" || type === "prenatal_diet") && (
          <div>
            <label className="text-xs text-gray-500 font-medium">{t("food")}</label>
            <input type="text" value={food} onChange={e => setFood(e.target.value)} placeholder={t("foodPlaceholder")} className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
          </div>
        )}
        <textarea value={notes} onChange={e => setNotes(e.target.value)} placeholder={t("notesOptional")} rows={2}
          className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none resize-none" />
        <button type="submit" disabled={saving} className="glass-btn w-full py-2.5 rounded-2xl text-white font-bold text-sm">
          {saving ? t("saving") : t("saveEntry")}
        </button>
      </form>

      {/* Recent entries */}
      <div className="space-y-2">
        <h3 className="font-bold text-gray-700 text-sm">{t("recentEntries")}</h3>
        {logs.length === 0 ? (
          <p className="text-gray-400 text-sm text-center py-8">{t("noNutritionEntries")}</p>
        ) : logs.map(log => (
          <div key={String(log.id)} className="glass rounded-2xl p-3">
            <div className="flex justify-between items-start">
              <div className="flex items-center gap-2">
                <span className="text-lg">{typeIcons[String(log.type)] || "🍽"}</span>
                <div>
                  <p className="text-sm font-semibold text-gray-800">{types.find(tp => tp.value === String(log.type))?.label.slice(2) || String(log.type)}</p>
                  <p className="text-xs text-gray-400">{new Date(String(log.date)).toLocaleDateString()}</p>
                </div>
              </div>
              <div className="text-right text-xs text-gray-500">
                {Number(log.duration_min) > 0 && <p>{String(log.duration_min)} min</p>}
                {Number(log.volume_ml) > 0 && <p>{String(log.volume_ml)} ml</p>}
                {log.food_name && <p>{String(log.food_name)}</p>}
                {log.notes && <p className="text-gray-400">{String(log.notes)}</p>}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
