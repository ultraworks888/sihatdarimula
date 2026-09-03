import { useState } from "react";
import {
  Download, Users, Baby, BookOpen, Zap, TrendingUp,
  BarChart2, FileText, ChevronDown, CheckCircle,
} from "lucide-react";
import pb from "../../lib/pocketbase";

// ── Export catalogue ─────────────────────────────────────────────────────────

const EXPORTS = [
  {
    type: "users",
    icon: Users,
    name: "User Accounts",
    description: "Complete list of all registered mothers — their profile details and account status.",
    accent: "#8b5cf6",
    columns: ["Name", "Email", "Phone", "Language", "Role", "Joined Date"],
    note: "Excludes admin accounts.",
  },
  {
    type: "children",
    icon: Baby,
    name: "Children & Milestones",
    description: "Every child profile linked to a parent account, including age, birth status and due dates.",
    accent: "#ec4899",
    columns: ["Parent Name", "Parent Email", "Child Name", "Gender", "Is Born", "Date of Birth", "Due Date", "Age (months)"],
    note: "Age is calculated at time of export.",
  },
  {
    type: "enrollments",
    icon: BookOpen,
    name: "Course Enrolments",
    description: "One row per enrolment — shows which mother is taking which course and how far they've progressed.",
    accent: "#3b82f6",
    columns: ["User Name", "User Email", "Course Title", "Category", "Level", "Progress %", "Completed", "Completed Date", "Enrolled Date"],
    note: "Includes both active and completed enrolments.",
  },
  {
    type: "learners",
    icon: Zap,
    name: "Learner Activity",
    description: "One row per user — a quick snapshot of each mother's learning engagement and recency.",
    accent: "#10b981",
    columns: ["Name", "Email", "Language", "Courses Enrolled", "Courses Completed", "Lessons Completed", "Last Active", "Active (7d)", "Active (30d)"],
    note: "Activity windows are relative to export date.",
  },
  {
    type: "retention",
    icon: TrendingUp,
    name: "User Retention",
    description: "Full retention report — days since joining, course progress, lesson completion and activity windows per user.",
    accent: "#f59e0b",
    columns: ["Name", "Email", "Joined Date", "Days Since Joining", "Language", "Courses Enrolled", "In Progress", "Courses Completed", "Completion Rate %", "Avg Progress %", "Lessons Completed", "Last Active", "Active (7d)", "Active (30d)"],
    note: "Best used for cohort and churn analysis.",
  },
  {
    type: "progress",
    icon: BarChart2,
    name: "Lesson Progress Detail",
    description: "Granular lesson-by-lesson progress — watch time, quiz results and completion timestamps for every user.",
    accent: "#6366f1",
    columns: ["User Name", "User Email", "Course Title", "Lesson Title", "Watch %", "Watch Seconds", "Completed", "Quiz Passed", "Quiz Score %", "Completed Date", "Last Updated"],
    note: "May be large for platforms with many learners.",
  },
] as const;

type ExportType = typeof EXPORTS[number]["type"];

// ── Download helper ───────────────────────────────────────────────────────────

async function downloadCSV(type: ExportType): Promise<{ rows: number }> {
  const res = await pb.send(`/api/admin/export?type=${type}`, {
    method: "GET", requestKey: null,
  }) as { csv: string; filename: string; rows: number };

  // UTF-8 BOM ensures Excel opens the file with correct encoding
  const bom  = "\uFEFF";
  const blob = new Blob([bom + res.csv], { type: "text/csv;charset=utf-8;" });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement("a");
  a.href = url; a.download = res.filename;
  document.body.appendChild(a); a.click();
  document.body.removeChild(a); URL.revokeObjectURL(url);

  return { rows: res.rows };
}

// ── Main page ─────────────────────────────────────────────────────────────────

export default function AdminExport() {
  const [downloading, setDownloading] = useState<ExportType | null>(null);
  const [done,        setDone]        = useState<Record<string, number>>({});   // type → row count
  const [error,       setError]       = useState<string | null>(null);

  // Dropdown quick-select
  const [quickType, setQuickType] = useState<ExportType | "">("");

  const handleDownload = async (type: ExportType) => {
    if (downloading) return;
    setDownloading(type);
    setError(null);
    try {
      const { rows } = await downloadCSV(type);
      setDone(prev => ({ ...prev, [type]: rows }));
    } catch {
      setError(`Export "${type}" failed. Please try again.`);
    } finally {
      setDownloading(null);
    }
  };

  return (
    <div className="space-y-6">

      {/* ── Header ─────────────────────────────────────────────────────── */}
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl flex items-center justify-center"
            style={{ background: "rgba(139,92,246,0.15)" }}>
            <Download size={20} className="text-violet-400" />
          </div>
          <div>
            <h1 className="text-white font-bold text-xl">Data Exports</h1>
            <p className="text-white/40 text-sm">Download CSV reports — opens correctly in Excel, Google Sheets and Numbers</p>
          </div>
        </div>

        {/* Quick-download dropdown */}
        <div className="flex items-center gap-2 shrink-0">
          <div className="relative">
            <select
              value={quickType}
              onChange={e => setQuickType(e.target.value as ExportType | "")}
              className="appearance-none pl-3 pr-8 py-2.5 rounded-xl bg-white/6 border border-white/12
                text-white text-sm outline-none focus:border-violet-500/50 transition-colors cursor-pointer"
            >
              <option value="" className="bg-slate-900">— Quick select report —</option>
              {EXPORTS.map(ex => (
                <option key={ex.type} value={ex.type} className="bg-slate-900">{ex.name}</option>
              ))}
            </select>
            <ChevronDown size={14} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-white/35 pointer-events-none"/>
          </div>
          <button
            onClick={() => quickType && handleDownload(quickType)}
            disabled={!quickType || !!downloading}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-bold text-white
              transition-all disabled:opacity-40 disabled:cursor-not-allowed hover:opacity-90 active:scale-[0.98]"
            style={{ background: "linear-gradient(135deg,#7c3aed,#db2777)" }}
          >
            {downloading === quickType ? (
              <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"/>
            ) : (
              <Download size={14}/>
            )}
            Download
          </button>
        </div>
      </div>

      {/* Error banner */}
      {error && (
        <div className="rounded-xl px-4 py-3 bg-rose-500/10 border border-rose-500/20 text-rose-300 text-sm">
          {error}
        </div>
      )}

      {/* ── Export cards ────────────────────────────────────────────────── */}
      <div className="grid md:grid-cols-2 xl:grid-cols-3 gap-4">
        {EXPORTS.map(ex => {
          const isDownloading = downloading === ex.type;
          const wasDone       = done[ex.type] != null;
          const Icon          = ex.icon;

          return (
            <div key={ex.type}
              className="rounded-2xl border border-white/5 overflow-hidden flex flex-col transition-all hover:border-white/10"
              style={{ background: "rgba(255,255,255,0.025)" }}>

              {/* Accent bar */}
              <div className="h-0.5 w-full" style={{ background: ex.accent }} />

              <div className="p-5 flex-1 flex flex-col gap-3">
                {/* Icon + name */}
                <div className="flex items-start gap-3">
                  <div className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
                    style={{ background: `${ex.accent}18` }}>
                    <Icon size={17} style={{ color: ex.accent }} />
                  </div>
                  <div className="min-w-0">
                    <h3 className="text-white font-semibold text-sm leading-snug">{ex.name}</h3>
                    {wasDone && (
                      <span className="inline-flex items-center gap-1 text-emerald-400 text-[11px] font-semibold mt-0.5">
                        <CheckCircle size={10}/> {done[ex.type].toLocaleString()} rows downloaded
                      </span>
                    )}
                  </div>
                </div>

                {/* Description */}
                <p className="text-white/45 text-[13px] leading-relaxed">{ex.description}</p>

                {/* Columns */}
                <div>
                  <p className="text-white/25 text-[10px] font-bold uppercase tracking-wide mb-1.5">Columns included</p>
                  <div className="flex flex-wrap gap-1">
                    {ex.columns.map(col => (
                      <span key={col}
                        className="px-1.5 py-0.5 rounded-md text-[10px] font-medium border"
                        style={{
                          background: `${ex.accent}0d`,
                          borderColor: `${ex.accent}25`,
                          color: ex.accent,
                        }}>
                        {col}
                      </span>
                    ))}
                  </div>
                </div>

                {/* Note */}
                <p className="text-white/20 text-[11px] flex items-start gap-1 leading-snug">
                  <FileText size={10} className="shrink-0 mt-0.5" />
                  {ex.note}
                </p>
              </div>

              {/* Download button */}
              <div className="px-5 pb-5">
                <button
                  onClick={() => handleDownload(ex.type)}
                  disabled={!!downloading}
                  className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-bold
                    text-white transition-all disabled:opacity-50 disabled:cursor-not-allowed
                    hover:opacity-90 active:scale-[0.98]"
                  style={{
                    background: isDownloading
                      ? `${ex.accent}40`
                      : `linear-gradient(135deg, ${ex.accent}cc, ${ex.accent})`,
                  }}
                >
                  {isDownloading ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"/>
                      Generating…
                    </>
                  ) : wasDone ? (
                    <><Download size={14}/> Download Again</>
                  ) : (
                    <><Download size={14}/> Download CSV</>
                  )}
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* ── Format note ─────────────────────────────────────────────────── */}
      <div className="rounded-2xl border border-white/5 p-5 flex items-start gap-3"
        style={{ background: "rgba(255,255,255,0.02)" }}>
        <FileText size={16} className="text-white/25 mt-0.5 shrink-0"/>
        <div className="space-y-1">
          <p className="text-white/50 text-sm font-semibold">About these exports</p>
          <ul className="text-white/30 text-xs space-y-0.5 list-disc list-inside leading-relaxed">
            <li>All files are UTF-8 encoded with a BOM — they open directly in Excel, Google Sheets, Numbers and LibreOffice.</li>
            <li>Dates are in <span className="text-white/50 font-mono">YYYY-MM-DD</span> format (ISO 8601) for consistent sorting.</li>
            <li>Data is live — each download reflects the current state of the database at the moment of export.</li>
            <li>Activity windows ("Active 7d / 30d") are calculated relative to the time of download.</li>
          </ul>
        </div>
      </div>

    </div>
  );
}
