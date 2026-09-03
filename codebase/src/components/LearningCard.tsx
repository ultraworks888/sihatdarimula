import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { BookOpen, Flame, Trophy, CheckCircle } from "lucide-react";
import pb from "../lib/pocketbase";
import { useLang } from "../contexts/LanguageContext";

interface Stats {
  enrolled: number;
  completed: number;
  lessonsFinished: number;
  streak: number;
  activeDays: Set<string>;
  inProgress: { courseId: string; title: string; pct: number } | null;
}

function getLast7Days() {
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date();
    d.setDate(d.getDate() - (6 - i));
    return { key: d.toISOString().slice(0, 10), dayNum: d.getDate(), isToday: i === 6 };
  });
}

export default function LearningCard({ userId }: { userId: string }) {
  const { t, lang } = useLang();
  const navigate = useNavigate();
  const [stats, setStats] = useState<Stats | null>(null);

  useEffect(() => {
    const thirtyAgo = new Date();
    thirtyAgo.setDate(thirtyAgo.getDate() - 29);
    thirtyAgo.setHours(0, 0, 0, 0);
    const cutoff = thirtyAgo.toISOString().replace("T", " ").slice(0, 10) + " 00:00:00.000Z";

    Promise.all([
      pb.collection("enrollments").getFullList({
        filter: pb.filter("user = {:u}", { u: userId }),
        expand: "course",
        requestKey: null,
      }),
      pb.collection("lesson_progress").getFullList({
        filter: pb.filter("user = {:u} && updated >= {:c}", { u: userId, c: cutoff }),
        fields: "updated,is_completed",
        requestKey: null,
      }),
    ]).then(([enrollments, progress]) => {
      // Build date sets
      const allDates = new Set<string>();
      let lessonsFinished = 0;
      for (const p of progress) {
        allDates.add(new Date(String(p.updated)).toISOString().slice(0, 10));
        if (p.is_completed) lessonsFinished++;
      }

      // Last 7 active days
      const activeDays = new Set<string>();
      const sevenAgo = new Date();
      sevenAgo.setDate(sevenAgo.getDate() - 6);
      sevenAgo.setHours(0, 0, 0, 0);
      for (const ds of allDates) {
        if (new Date(ds) >= sevenAgo) activeDays.add(ds);
      }

      // Current streak (consecutive days ending today or yesterday)
      let streak = 0;
      const cursor = new Date();
      if (!allDates.has(cursor.toISOString().slice(0, 10)))
        cursor.setDate(cursor.getDate() - 1);
      while (allDates.has(cursor.toISOString().slice(0, 10))) {
        streak++;
        cursor.setDate(cursor.getDate() - 1);
      }

      // Most-recently-active in-progress course
      const inProg = (enrollments as Record<string, unknown>[])
        .filter(e => !e.is_completed && Number(e.progress_percent) > 0)
        .sort((a, b) => new Date(String(b.updated)).getTime() - new Date(String(a.updated)).getTime())[0];

      const getCourseTitle = (e: Record<string, unknown>) => {
        const c = (e.expand as Record<string, unknown> | undefined)?.course as Record<string, unknown> | undefined;
        if (!c) return "";
        if (lang !== "en") {
          const loc = c[`title_${lang}`];
          if (loc && String(loc).trim()) return String(loc);
        }
        return String(c.title_en ?? c.title ?? "");
      };

      setStats({
        enrolled: enrollments.length,
        completed: (enrollments as Record<string, unknown>[]).filter(e => e.is_completed).length,
        lessonsFinished,
        streak,
        activeDays,
        inProgress: inProg ? {
          courseId: String(inProg.course),
          title: getCourseTitle(inProg),
          pct: Math.round(Number(inProg.progress_percent)),
        } : null,
      });
    }).catch(() => {});
  }, [userId, lang]);

  if (!stats) return null;

  const last7 = getLast7Days();

  return (
    <div className="glass rounded-3xl p-4 space-y-4">

      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <BookOpen size={16} className="text-violet-500" />
          <h3 className="font-bold text-gray-800 text-sm">{t("learningJourney")}</h3>
        </div>
        {stats.streak > 0 && (
          <div className="flex items-center gap-1 bg-amber-50 border border-amber-100 px-2.5 py-1 rounded-full">
            <Flame size={12} className="text-amber-500" />
            <span className="text-amber-700 text-[11px] font-bold">
              {stats.streak} {t("dayStreak")}
            </span>
          </div>
        )}
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-2">
        {[
          { value: stats.enrolled,       label: t("coursesEnrolled"), Icon: BookOpen,    color: "text-violet-400" },
          { value: stats.completed,      label: t("achievements"),    Icon: Trophy,      color: "text-amber-400"  },
          { value: stats.lessonsFinished,label: t("lessonsLearned"),  Icon: CheckCircle, color: "text-emerald-400"},
        ].map(({ value, label, Icon, color }) => (
          <div key={label} className="bg-white/50 rounded-2xl p-3 text-center">
            <Icon size={14} className={`${color} mx-auto mb-1`} />
            <p className="font-black text-gray-800 text-xl leading-none">{value}</p>
            <p className="text-gray-400 text-[10px] leading-snug mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* Weekly dots */}
      <div>
        <p className="text-[11px] font-semibold text-gray-400 mb-2 uppercase tracking-wide">
          {t("weeklyActivity")}
        </p>
        <div className="flex justify-between gap-1">
          {last7.map(({ key, dayNum, isToday }) => {
            const active = stats.activeDays.has(key);
            return (
              <div key={key} className="flex-1 flex flex-col items-center gap-1">
                <div className={`w-full aspect-square max-w-[36px] rounded-full flex items-center justify-center transition-all ${
                  active
                    ? "bg-gradient-to-br from-violet-500 to-pink-500 shadow-sm"
                    : isToday
                    ? "border-2 border-dashed border-violet-300 bg-violet-50"
                    : "bg-gray-100"
                }`}>
                  <span className={`text-[11px] font-black leading-none ${
                    active ? "text-white" : isToday ? "text-violet-400" : "text-gray-300"
                  }`}>{dayNum}</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Inactivity nudge */}
      {stats.enrolled > 0 && stats.streak === 0 && stats.lessonsFinished > 0 && (
        <div className="flex items-center gap-3 bg-amber-50 border border-amber-100 rounded-2xl px-3 py-2.5">
          <span className="text-xl shrink-0">💤</span>
          <div className="min-w-0">
            <p className="text-amber-800 text-xs font-bold leading-snug">{t("noRecentActivity")}</p>
            <p className="text-amber-600 text-[11px] mt-0.5">{t("continueWhereLeftOff")}</p>
          </div>
        </div>
      )}

      {/* In-progress course */}
      {stats.inProgress ? (
        <button
          onClick={() => navigate(`/courses/${stats.inProgress!.courseId}`)}
          className="w-full bg-gradient-to-r from-violet-50 to-pink-50 rounded-2xl p-3 text-left border border-violet-100 hover:scale-[1.01] active:scale-[0.99] transition-all">
          <div className="flex items-center justify-between mb-1.5">
            <p className="text-xs font-bold text-violet-700 truncate flex-1 mr-2">
              {stats.inProgress.title}
            </p>
            <span className="text-xs font-black text-violet-600 shrink-0">{stats.inProgress.pct}%</span>
          </div>
          <div className="h-1.5 bg-violet-100 rounded-full overflow-hidden">
            <div
              className="h-full rounded-full bg-gradient-to-r from-violet-500 to-pink-500 transition-all duration-700"
              style={{ width: `${stats.inProgress.pct}%` }}
            />
          </div>
          <p className="text-violet-500 text-[11px] font-semibold mt-1.5">{t("continueCourse")} →</p>
        </button>
      ) : stats.enrolled === 0 ? (
        <button onClick={() => navigate("/content")}
          className="w-full py-2.5 rounded-2xl bg-gradient-to-r from-violet-500 to-pink-500 text-white text-xs font-bold text-center">
          {t("startLearning")} →
        </button>
      ) : null}

    </div>
  );
}
