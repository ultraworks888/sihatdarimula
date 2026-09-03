import { useState, useEffect, useCallback } from "react";
import { useChild } from "../contexts/ChildContext";
import { useAuth } from "../contexts/AuthContext";
import { useLang } from "../contexts/LanguageContext";
import { useNavigate } from "react-router-dom";
import { computeReminders, type ChildForReminder } from "../hooks/useVaccineReminders";
import pb from "../lib/pocketbase";
import type { TranslationKey } from "../i18n/translations";
import AppLogo from "../components/AppLogo";
import LearningCard from "../components/LearningCard";

function getAge(dateStr: string, t: (k: TranslationKey) => string) {
  if (!dateStr) return null;
  const birth = new Date(dateStr);
  const now = new Date();
  const months = (now.getFullYear() - birth.getFullYear()) * 12 + (now.getMonth() - birth.getMonth());
  if (months < 1) {
    const d = Math.floor((now.getTime() - birth.getTime()) / 86400000);
    return `${d} ${d === 1 ? t("day") : t("days")}`;
  }
  if (months < 12) return `${months} ${t("months")}`;
  const y = Math.floor(months / 12);
  const m = months % 12;
  return m > 0 ? `${y} ${t("year")} ${m} ${t("months")}` : `${y} ${t(y > 1 ? "years" : "year")}`;
}

function getWeeksPregnant(dueDateStr: string) {
  if (!dueDateStr) return null;
  const due = new Date(dueDateStr);
  const now = new Date();
  const conception = new Date(due.getTime() - 40 * 7 * 86400000);
  return Math.max(0, Math.min(42, Math.floor((now.getTime() - conception.getTime()) / (7 * 86400000))));
}

export default function Home() {
  const { selectedChild, children } = useChild();
  const { user } = useAuth();
  const { t } = useLang();
  const navigate = useNavigate();
  const [completedMap, setCompletedMap] = useState<Record<string, Set<string>>>({});

  const fetchCompleted = useCallback(async () => {
    if (!user) return;
    const result = await pb.collection("immunisations").getFullList({
      filter: pb.filter("user = {:uid} && is_completed = true", { uid: user.id }),
      fields: "child,vaccine_name",
      requestKey: null,
    });
    const map: Record<string, Set<string>> = {};
    for (const r of result) {
      const cid = String(r["child"]);
      if (!map[cid]) map[cid] = new Set();
      map[cid].add(String(r["vaccine_name"]));
    }
    setCompletedMap(map);
  }, [user]);

  useEffect(() => { fetchCompleted(); }, [fetchCompleted]);

  if (!selectedChild) return null;

  const age = selectedChild.is_born ? getAge(selectedChild.date_of_birth, t) : null;
  const weeks = !selectedChild.is_born ? getWeeksPregnant(selectedChild.due_date) : null;

  const childrenForReminder: ChildForReminder[] = children
    .filter(c => c.is_born && c.date_of_birth)
    .map(c => ({ id: c.id, name: c.name, date_of_birth: c.date_of_birth, is_born: c.is_born }));

  const allReminders = computeReminders(childrenForReminder, completedMap);
  const childReminders = allReminders.filter(r => r.childId === selectedChild.id);
  const overdueCount = childReminders.filter(r => r.status === "overdue").length;
  const dueSoonCount = childReminders.filter(r => r.status === "due_soon").length;

  const quickActions = [
    { icon: "📏", label: t("growth"), tab: "growth" },
    { icon: "🍼", label: t("feed"), tab: "nutrition" },
    { icon: "🎯", label: t("activity"), tab: "activity" },
    { icon: "💜", label: t("mood"), tab: "wellbeing" },
    { icon: "💉", label: t("vaccines"), tab: "immunisation" },
  ];

  const tipKeys: TranslationKey[] = selectedChild.is_born
    ? ["tipGrowth", "tipTummy", "tipReading", "tipSleep"]
    : ["tipHydrate", "tipVitamins", "tipExercise", "tipBreathing"];

  return (
    <div className="p-4 space-y-5 fade-up">
      {/* Hero Card */}
      <div className="relative overflow-hidden rounded-3xl p-5 text-white shadow-lg" style={{
        background: "linear-gradient(135deg, rgba(109,40,217,0.85), rgba(124,58,237,0.75), rgba(59,130,246,0.8))",
        backdropFilter: "blur(20px)",
      }}>
        <div className="absolute inset-0 bg-gradient-to-br from-white/10 via-transparent to-white/5 pointer-events-none" />
        {/* Logo watermark */}
        <div className="absolute -right-4 -top-4 opacity-10 pointer-events-none">
          <AppLogo size={100} />
        </div>
        <div className="flex items-center gap-4 relative z-10">
          <div className="w-14 h-14 bg-white/20 rounded-2xl flex items-center justify-center text-2xl backdrop-blur-sm shrink-0 border border-white/20">
            {selectedChild.is_born ? (selectedChild.gender === "girl" ? "👧" : "👦") : "🤰"}
          </div>
          <div>
            <h2 className="text-xl font-bold">{selectedChild.name}</h2>
            {age && <p className="text-white/80 text-sm">{age} {t("old")}</p>}
            {weeks !== null && (
              <div>
                <p className="text-white/80 text-sm">{t("weekOf")} {weeks} {t("ofPregnancy")}</p>
                <div className="w-32 h-1.5 bg-white/20 rounded-full mt-1.5">
                  <div className="h-full bg-white rounded-full transition-all" style={{ width: `${(weeks / 40) * 100}%` }} />
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Vaccine Reminder Alert */}
      {selectedChild.is_born && (overdueCount > 0 || dueSoonCount > 0) && (
        <button onClick={() => navigate("/track?tab=immunisation")} className="w-full text-left">
          <div className={`glass rounded-3xl p-4 ${overdueCount > 0 ? "!border-rose-200/60" : "!border-amber-200/60"}`}>
            <div className="flex items-start gap-3">
              <span className="text-2xl shrink-0">{overdueCount > 0 ? "🚨" : "⏰"}</span>
              <div className="min-w-0">
                <h3 className={`font-bold text-sm ${overdueCount > 0 ? "text-rose-700" : "text-amber-700"}`}>
                  {t("vaccineAlert")}
                </h3>
                <p className={`text-xs mt-0.5 ${overdueCount > 0 ? "text-rose-600" : "text-amber-600"}`}>
                  {overdueCount > 0 && `${overdueCount} ${t("overdueVaccines")}`}
                  {overdueCount > 0 && dueSoonCount > 0 && " · "}
                  {dueSoonCount > 0 && `${dueSoonCount} ${t("dueSoonVaccines")}`}
                </p>
                <span className={`inline-block mt-1.5 text-xs font-bold ${overdueCount > 0 ? "text-rose-500" : "text-amber-500"}`}>
                  {t("viewSchedule")} →
                </span>
              </div>
            </div>
          </div>
        </button>
      )}

      {/* Learning Journey */}
      <LearningCard userId={user!.id} />

      {/* Tip of the Day */}
      <div className="glass rounded-3xl p-4">
        <div className="flex items-start gap-3">
          <span className="text-2xl shrink-0">💡</span>
          <div>
            <h3 className="font-bold text-amber-800 text-sm">{t("tipOfDay")}</h3>
            <p className="text-gray-600 text-sm mt-1">{t(tipKeys[new Date().getDate() % tipKeys.length])}</p>
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div>
        <h3 className="font-bold text-gray-800 mb-3">{t("quickTrack")}</h3>
        <div className="grid grid-cols-5 gap-2">
          {quickActions.map(a => (
            <button key={a.tab} onClick={() => navigate(`/track?tab=${a.tab}`)}
              className="glass flex flex-col items-center rounded-2xl p-3 hover:scale-105 active:scale-95 transition-all duration-200">
              <span className="text-2xl mb-1">{a.icon}</span>
              <span className="text-[11px] font-semibold text-gray-600">{a.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Feature Cards */}
      <div className="grid grid-cols-2 gap-3">
        <button onClick={() => navigate("/content")} className="glass rounded-3xl p-4 text-left hover:scale-[1.02] transition-all duration-200">
          <span className="text-2xl">📖</span>
          <h4 className="font-bold text-violet-800 text-sm mt-2">{t("learn")}</h4>
          <p className="text-gray-500 text-xs mt-1">{t("ageArticles")}</p>
          <span className="text-violet-500 text-xs font-bold mt-2 inline-block">{t("browse")}</span>
        </button>
        <button onClick={() => navigate("/track?tab=activity")} className="glass rounded-3xl p-4 text-left hover:scale-[1.02] transition-all duration-200">
          <span className="text-2xl">🏆</span>
          <h4 className="font-bold text-rose-800 text-sm mt-2">{t("milestones")}</h4>
          <p className="text-gray-500 text-xs mt-1">{t("trackAchievements")}</p>
          <span className="text-rose-500 text-xs font-bold mt-2 inline-block">{t("trackArrow")}</span>
        </button>
      </div>
    </div>
  );
}
