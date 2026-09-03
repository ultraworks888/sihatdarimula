import { useState, useEffect } from "react";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, Cell,
} from "recharts";
import {
  BookOpen, Users, Zap, CheckCircle, TrendingUp,
  Award, BarChart2, ChevronRight,
} from "lucide-react";
import pb from "../../lib/pocketbase";

// ── Types ────────────────────────────────────────────────────────────────────

interface CourseRow {
  id: string;
  title: string;
  category: string;
  enrollment_count: number;
  completion_count: number;
  completion_rate: number;
  avg_progress: number;
  lessons_completed: number;
}

interface Analytics {
  enrollments: {
    total: number;
    completed: number;
    in_progress: number;
    completion_rate: number;
    avg_progress: number;
  };
  learners: { active_7d: number; active_30d: number };
  lessons: { total_completed: number };
  courses: CourseRow[];
  weekly_activity: { label: string; learners: number }[];
}

// ── Constants ─────────────────────────────────────────────────────────────────

const CAT_COLOR: Record<string, string> = {
  parenting:    "#8b5cf6",
  nutrition:    "#10b981",
  development:  "#3b82f6",
  wellbeing:    "#f472b6",
  breastfeeding:"#f59e0b",
  pregnancy:    "#ec4899",
};

const CAT_LABEL: Record<string, string> = {
  parenting: "Parenting", nutrition: "Nutrition", development: "Development",
  wellbeing: "Wellbeing", breastfeeding: "Breastfeeding", pregnancy: "Pregnancy",
};

const BAR_COLORS = ["#8b5cf6","#7c3aed","#6d28d9","#5b21b6","#4c1d95"];

// ── Sub-components ────────────────────────────────────────────────────────────

const KpiCard = ({
  icon: Icon, label, value, sub, accent,
}: { icon: React.ElementType; label: string; value: string | number; sub?: string; accent: string }) => (
  <div className="rounded-2xl p-4 border border-white/5 flex items-start gap-3"
    style={{ background: "rgba(255,255,255,0.03)" }}>
    <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
      style={{ background: `${accent}18` }}>
      <Icon size={18} style={{ color: accent }} />
    </div>
    <div className="min-w-0">
      <p className="text-white/40 text-[11px] font-medium leading-snug">{label}</p>
      <p className="text-white text-2xl font-bold mt-0.5 tabular-nums">{value}</p>
      {sub && <p className="text-white/30 text-[11px] mt-0.5 leading-snug">{sub}</p>}
    </div>
  </div>
);

const MiniBar = ({ value, max, color = "#8b5cf6" }: { value: number; max: number; color?: string }) => {
  const pct = max > 0 ? Math.round((value / max) * 100) : 0;
  return (
    <div className="flex items-center gap-2">
      <div className="flex-1 h-1.5 bg-white/8 rounded-full overflow-hidden">
        <div className="h-full rounded-full transition-all duration-700"
          style={{ width: `${pct}%`, background: color }} />
      </div>
      <span className="text-white/40 text-[11px] tabular-nums w-7 text-right">{value}</span>
    </div>
  );
};

const ProgressBar = ({ value, color = "#8b5cf6" }: { value: number; color?: string }) => (
  <div className="flex items-center gap-2 min-w-0">
    <div className="flex-1 h-1.5 bg-white/8 rounded-full overflow-hidden">
      <div className="h-full rounded-full transition-all duration-700"
        style={{ width: `${value}%`, background: color }} />
    </div>
    <span className="text-white/50 text-[11px] tabular-nums w-8 text-right shrink-0">{value}%</span>
  </div>
);

const TooltipDark = ({ active, payload, label }: {
  active?: boolean; payload?: { value: number }[]; label?: string;
}) => {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl px-3 py-2 text-xs border border-white/10"
      style={{ background: "rgba(15,8,30,0.97)" }}>
      {label && <p className="text-white/40 mb-1">{label}</p>}
      <p className="text-white font-bold">{payload[0].value} active learner{payload[0].value !== 1 ? "s" : ""}</p>
    </div>
  );
};

// ── Main page ─────────────────────────────────────────────────────────────────

export default function AdminAnalytics() {
  const [data,    setData]    = useState<Analytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState(false);

  useEffect(() => {
    pb.send("/api/admin/analytics", { method: "GET", requestKey: null })
      .then((res) => setData(res as Analytics))
      .catch(() => setError(true))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return (
    <div className="flex items-center justify-center py-32">
      <div className="w-8 h-8 border-2 border-violet-500 border-t-transparent rounded-full animate-spin" />
    </div>
  );

  if (error || !data) return (
    <div className="flex flex-col items-center justify-center py-32 gap-3">
      <BarChart2 size={32} className="text-white/15" />
      <p className="text-white/40 text-sm">Could not load analytics. Please refresh.</p>
    </div>
  );

  const { enrollments, learners, lessons, courses, weekly_activity } = data;
  const maxEnrollment = courses.length > 0 ? courses[0].enrollment_count : 1;
  const peakWeek = Math.max(...weekly_activity.map(w => w.learners), 1);

  return (
    <div className="space-y-6">

      {/* ── Header ─────────────────────────────────────────────────────── */}
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl flex items-center justify-center"
            style={{ background: "rgba(139,92,246,0.15)" }}>
            <TrendingUp size={20} className="text-violet-400" />
          </div>
          <div>
            <h1 className="text-white font-bold text-xl">Learning Analytics</h1>
            <p className="text-white/40 text-sm">Enrolment, completion and engagement metrics</p>
          </div>
        </div>
        <p className="text-white/25 text-xs pt-1 shrink-0">
          {new Date().toLocaleDateString("en-MY", { day: "numeric", month: "long", year: "numeric" })}
        </p>
      </div>

      {/* ── KPI row ────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-3">
        <KpiCard icon={BookOpen}     label="Total Enrolments"    value={enrollments.total}
          sub={`${enrollments.in_progress} in progress`}  accent="#8b5cf6" />
        <KpiCard icon={Zap}          label="Active This Week"    value={learners.active_7d}
          sub={`${learners.active_30d} active this month`} accent="#3b82f6" />
        <KpiCard icon={CheckCircle}  label="Lessons Completed"   value={lessons.total_completed}
          accent="#10b981" />
        <KpiCard icon={Award}        label="Courses Completed"   value={enrollments.completed}
          sub={`${enrollments.completion_rate}% completion rate`} accent="#f59e0b" />
        <KpiCard icon={TrendingUp}   label="Avg Progress"        value={`${enrollments.avg_progress}%`}
          sub="across all enrolments" accent="#ec4899" />
      </div>

      {/* ── Activity trend + Funnel ─────────────────────────────────────── */}
      <div className="grid lg:grid-cols-5 gap-5">

        {/* Weekly activity chart — 3 cols */}
        <div className="lg:col-span-3 rounded-2xl border border-white/5 p-5"
          style={{ background: "rgba(255,255,255,0.03)" }}>
          <div className="flex items-center justify-between mb-5">
            <div>
              <h2 className="text-white font-semibold">Weekly Active Learners</h2>
              <p className="text-white/35 text-xs mt-0.5">Unique learners with lesson activity per week</p>
            </div>
            <div className="text-right">
              <p className="text-violet-400 text-xl font-bold tabular-nums">{learners.active_7d}</p>
              <p className="text-white/30 text-[11px]">this week</p>
            </div>
          </div>

          <ResponsiveContainer width="100%" height={180}>
            <BarChart data={weekly_activity} margin={{ left: -20, right: 4, top: 4, bottom: 0 }} barSize={32}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" vertical={false} />
              <XAxis dataKey="label" tick={{ fill: "rgba(255,255,255,0.35)", fontSize: 11 }}
                axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: "rgba(255,255,255,0.30)", fontSize: 11 }}
                axisLine={false} tickLine={false} allowDecimals={false} />
              <Tooltip content={<TooltipDark />} cursor={{ fill: "rgba(255,255,255,0.04)" }} />
              <Bar dataKey="learners" radius={[6, 6, 2, 2]}>
                {weekly_activity.map((w, i) => (
                  <Cell key={i}
                    fill={i === weekly_activity.length - 1 ? "#8b5cf6" : `rgba(139,92,246,${0.35 + i * 0.12})`} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>

          {/* Spark legend */}
          <div className="flex items-center gap-4 mt-3 pt-3 border-t border-white/5">
            {[
              { label: "Peak week", value: peakWeek + " learners" },
              { label: "30-day active", value: learners.active_30d + " mothers" },
            ].map(s => (
              <div key={s.label} className="flex items-center gap-1.5">
                <div className="w-2 h-2 rounded-full bg-violet-500/50"/>
                <span className="text-white/30 text-[11px]">{s.label}:</span>
                <span className="text-white/60 text-[11px] font-semibold">{s.value}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Enrolment funnel — 2 cols */}
        <div className="lg:col-span-2 rounded-2xl border border-white/5 p-5"
          style={{ background: "rgba(255,255,255,0.03)" }}>
          <h2 className="text-white font-semibold mb-1">Enrolment Funnel</h2>
          <p className="text-white/35 text-xs mb-5">How far enrolled mothers progress</p>

          <div className="space-y-4">
            {[
              { label: "Enrolled",    value: enrollments.total,      pct: 100,                     color: "#8b5cf6", desc: "started at least one course" },
              { label: "In Progress", value: enrollments.in_progress, pct: enrollments.total > 0 ? Math.round(enrollments.in_progress / enrollments.total * 100) : 0, color: "#3b82f6", desc: "actively working through lessons" },
              { label: "Completed",   value: enrollments.completed,   pct: enrollments.completion_rate, color: "#10b981", desc: "finished all lessons" },
            ].map((row, i) => (
              <div key={row.label}>
                <div className="flex items-baseline justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <div className="w-2 h-2 rounded-full shrink-0" style={{ background: row.color }}/>
                    <span className="text-white/60 text-sm font-medium">{row.label}</span>
                  </div>
                  <div className="text-right">
                    <span className="text-white font-bold tabular-nums text-lg">{row.value}</span>
                    <span className="text-white/30 text-xs ml-1.5">({row.pct}%)</span>
                  </div>
                </div>
                <div className="h-2.5 bg-white/8 rounded-full overflow-hidden">
                  <div className="h-full rounded-full transition-all duration-700"
                    style={{ width: `${row.pct}%`, background: row.color }} />
                </div>
                <p className="text-white/25 text-[11px] mt-1.5">{row.desc}</p>
              </div>
            ))}
          </div>

          {/* Avg progress meter */}
          <div className="mt-5 pt-4 border-t border-white/5">
            <div className="flex items-baseline justify-between mb-2">
              <span className="text-white/50 text-xs font-semibold uppercase tracking-wide">Avg Progress</span>
              <span className="text-violet-400 font-bold tabular-nums">{enrollments.avg_progress}%</span>
            </div>
            <div className="h-2 bg-white/8 rounded-full overflow-hidden">
              <div className="h-full rounded-full transition-all duration-700"
                style={{ width: `${enrollments.avg_progress}%`, background: "linear-gradient(90deg,#7c3aed,#db2777)" }} />
            </div>
            <p className="text-white/25 text-[11px] mt-1.5">
              Average completion progress across all {enrollments.total} enrolments
            </p>
          </div>
        </div>
      </div>

      {/* ── Course performance table ────────────────────────────────────── */}
      <div className="rounded-2xl border border-white/5 overflow-hidden"
        style={{ background: "rgba(255,255,255,0.03)" }}>
        <div className="flex items-center justify-between px-5 py-4 border-b border-white/5">
          <div className="flex items-center gap-2">
            <BookOpen size={15} className="text-violet-400"/>
            <h2 className="text-white font-semibold">Course Performance</h2>
          </div>
          <span className="text-white/25 text-xs">{courses.length} published courses · ranked by enrolment</span>
        </div>

        {courses.length === 0 ? (
          <div className="py-12 text-center">
            <BookOpen size={28} className="text-white/10 mx-auto mb-2"/>
            <p className="text-white/30 text-sm">No published courses yet</p>
          </div>
        ) : (
          <>
            {/* Table header */}
            <div className="hidden lg:grid grid-cols-[2rem_1fr_6rem_7rem_11rem_11rem_6rem] gap-4 px-5 py-2.5
              border-b border-white/5 text-[10px] font-bold uppercase tracking-wide text-white/25">
              <span>#</span>
              <span>Course</span>
              <span>Enrolled</span>
              <span>Completed</span>
              <span>Completion Rate</span>
              <span>Avg Progress</span>
              <span className="text-right">Lessons</span>
            </div>

            <div className="divide-y divide-white/[0.04]">
              {courses.map((course, i) => (
                <div key={course.id}
                  className="grid grid-cols-1 lg:grid-cols-[2rem_1fr_6rem_7rem_11rem_11rem_6rem] gap-2 lg:gap-4
                    px-5 py-4 hover:bg-white/[0.02] transition-colors items-center">

                  {/* Rank */}
                  <span className={`hidden lg:block text-sm font-bold tabular-nums ${
                    i === 0 ? "text-amber-400" : i === 1 ? "text-white/50" : i === 2 ? "text-orange-700" : "text-white/20"
                  }`}>
                    {i + 1}
                  </span>

                  {/* Course name + category */}
                  <div className="flex items-start gap-2.5 min-w-0">
                    <div className="w-1 h-8 rounded-full mt-0.5 shrink-0"
                      style={{ background: CAT_COLOR[course.category] ?? "#6b7280" }} />
                    <div className="min-w-0">
                      <p className="text-white text-sm font-semibold leading-snug line-clamp-1">{course.title}</p>
                      <span className="inline-block text-[10px] font-semibold px-1.5 py-0.5 rounded-md mt-0.5"
                        style={{
                          background: `${CAT_COLOR[course.category] ?? "#6b7280"}18`,
                          color: CAT_COLOR[course.category] ?? "#9ca3af",
                        }}>
                        {CAT_LABEL[course.category] ?? course.category}
                      </span>
                    </div>
                  </div>

                  {/* Enrolled */}
                  <div>
                    <p className="text-white/30 text-[10px] lg:hidden font-semibold uppercase tracking-wide mb-1">Enrolled</p>
                    <div className="flex items-center gap-2">
                      <span className="text-white font-bold tabular-nums">{course.enrollment_count}</span>
                      <div className="hidden lg:block flex-1">
                        <MiniBar value={course.enrollment_count} max={maxEnrollment}/>
                      </div>
                    </div>
                  </div>

                  {/* Completed */}
                  <div>
                    <p className="text-white/30 text-[10px] lg:hidden font-semibold uppercase tracking-wide mb-1">Completed</p>
                    <div className="flex items-center gap-1.5">
                      <CheckCircle size={12} className={course.completion_count > 0 ? "text-emerald-400" : "text-white/15"}/>
                      <span className={`font-bold tabular-nums text-sm ${course.completion_count > 0 ? "text-emerald-400" : "text-white/30"}`}>
                        {course.completion_count}
                      </span>
                    </div>
                  </div>

                  {/* Completion rate */}
                  <div>
                    <p className="text-white/30 text-[10px] lg:hidden font-semibold uppercase tracking-wide mb-1">Completion Rate</p>
                    <ProgressBar value={course.completion_rate} color="#10b981"/>
                  </div>

                  {/* Avg progress */}
                  <div>
                    <p className="text-white/30 text-[10px] lg:hidden font-semibold uppercase tracking-wide mb-1">Avg Progress</p>
                    <ProgressBar value={course.avg_progress} color="#8b5cf6"/>
                  </div>

                  {/* Lessons completed */}
                  <div className="lg:text-right">
                    <p className="text-white/30 text-[10px] lg:hidden font-semibold uppercase tracking-wide mb-1">Lessons Done</p>
                    <span className="text-white/50 font-semibold tabular-nums text-sm">{course.lessons_completed}</span>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
      </div>

      {/* ── Quick insight strip ─────────────────────────────────────────── */}
      {courses.length > 0 && (
        <div className="grid sm:grid-cols-3 gap-3">
          {[
            {
              label: "Most popular course",
              value: courses[0]?.title ?? "—",
              sub: `${courses[0]?.enrollment_count ?? 0} enrolments`,
              icon: Users, accent: "#8b5cf6",
            },
            {
              label: "Highest completion rate",
              value: (() => {
                const best = [...courses].sort((a, b) => b.completion_rate - a.completion_rate)[0];
                return best?.completion_rate ? `${best.completion_rate}%` : "—";
              })(),
              sub: (() => {
                const best = [...courses].sort((a, b) => b.completion_rate - a.completion_rate)[0];
                return best?.title ?? "—";
              })(),
              icon: Award, accent: "#10b981",
            },
            {
              label: "Lessons completed (total)",
              value: lessons.total_completed,
              sub: `across ${enrollments.total} enrolments`,
              icon: CheckCircle, accent: "#f59e0b",
            },
          ].map(card => (
            <div key={card.label} className="rounded-2xl border border-white/5 p-4 flex items-start gap-3"
              style={{ background: "rgba(255,255,255,0.02)" }}>
              <div className="w-8 h-8 rounded-xl flex items-center justify-center shrink-0"
                style={{ background: `${card.accent}15` }}>
                <card.icon size={15} style={{ color: card.accent }}/>
              </div>
              <div className="min-w-0">
                <p className="text-white/35 text-[10px] font-semibold uppercase tracking-wide">{card.label}</p>
                <p className="text-white font-bold text-base mt-0.5 leading-snug truncate">{card.value}</p>
                <p className="text-white/30 text-[11px] mt-0.5 truncate">{card.sub}</p>
              </div>
            </div>
          ))}
        </div>
      )}

    </div>
  );
}
