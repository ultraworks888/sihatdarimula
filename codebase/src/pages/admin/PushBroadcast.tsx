import { useState, useEffect, type FormEvent } from "react";
import {
  Bell, Send, Users, CheckCircle, XCircle, Clock, Smartphone,
  ExternalLink, CalendarClock, Zap, Trash2, Baby, Heart,
  BookOpen, Target, Globe, Filter, BellRing, ChevronRight,
} from "lucide-react";
import pb from "../../lib/pocketbase";
import AppLogo from "../../components/AppLogo";

// ── Types ───────────────────────────────────────────────────────────────────

type SegmentType =
  | "all" | "subscribed"
  | "baby_age" | "expectant"
  | "course_enrolled" | "not_enrolled"
  | "language";

type SendMode = "now" | "schedule";

interface SegmentConfig {
  type: string;
  label?: string;
  minMonths?: number;
  maxMonths?: number;
  courseId?: string;
  courseName?: string;
  lang?: string;
}

interface Broadcast {
  id: string;
  title: string;
  message: string;
  status: "sent" | "failed" | "pending" | "cancelled";
  target: string;
  recipient_count: number;
  url: string;
  scheduled_at?: string;
  segment_config?: SegmentConfig | null;
  created: string;
  expand?: { sent_by?: { name: string; email: string } };
}

interface Course { id: string; title_en: string; }

// ── Constants ────────────────────────────────────────────────────────────────

const TITLE_MAX = 60;
const MSG_MAX   = 200;

const MONTH_OPTS = [0, 1, 2, 3, 4, 5, 6, 9, 12, 18, 24, 36, 48, 60];
const LANG_LABELS: Record<string, string> = { en: "English", ms: "Bahasa Malaysia", zh: "中文" };

const statusCfg: Record<string, { cls: string; icon: React.ReactNode; label: string }> = {
  sent:      { cls: "bg-emerald-500/15 text-emerald-400", icon: <CheckCircle size={11}/>, label: "Sent"      },
  failed:    { cls: "bg-rose-500/15 text-rose-400",       icon: <XCircle size={11}/>,     label: "Failed"    },
  pending:   { cls: "bg-amber-500/15 text-amber-400",     icon: <Clock size={11}/>,       label: "Scheduled" },
  cancelled: { cls: "bg-white/8 text-white/25",           icon: <XCircle size={11}/>,     label: "Cancelled" },
};

const SEGMENT_DEFS: {
  type: SegmentType; Icon: React.ElementType; label: string; desc: string;
}[] = [
  { type: "all",            Icon: Users,    label: "All registered users",    desc: "Everyone registered with OneSignal" },
  { type: "subscribed",     Icon: BellRing, label: "Push subscribers only",   desc: "Mothers who have enabled push notifications" },
  { type: "baby_age",       Icon: Baby,     label: "Baby age range",          desc: "Filter by the age of their youngest born child" },
  { type: "expectant",      Icon: Heart,    label: "Expectant mothers",       desc: "Mothers with a baby not yet born" },
  { type: "course_enrolled",Icon: BookOpen, label: "Enrolled in a course",    desc: "Currently enrolled in a specific course" },
  { type: "not_enrolled",   Icon: Target,   label: "Not yet enrolled",        desc: "Registered but haven't started any course" },
  { type: "language",       Icon: Globe,    label: "By app language",         desc: "Filter by preferred language set in their profile" },
];

// ── Helpers ──────────────────────────────────────────────────────────────────

const toMYT = (iso: string) =>
  new Date(iso).toLocaleString("en-MY", {
    timeZone: "Asia/Kuala_Lumpur", day: "numeric", month: "short",
    year: "numeric", hour: "2-digit", minute: "2-digit", hour12: true,
  });

const minDateTime = () => {
  const d = new Date(Date.now() + 5 * 60_000);
  return new Date(d.getTime() - d.getTimezoneOffset() * 60_000).toISOString().slice(0, 16);
};

const fmtMonths = (m: number) =>
  m === 0 ? "0 months" : m === 60 ? "5 years" : m >= 12 ? `${m / 12 % 1 === 0 ? m/12 : m} months` : `${m} months`;

const audienceLabel = (b: Broadcast) => {
  if (b.segment_config?.label) return b.segment_config.label;
  if (b.target === "subscribed") return "Push subscribers";
  return "All users";
};

// ── Sub-components ────────────────────────────────────────────────────────────

const StatusBadge = ({ status }: { status: string }) => {
  const cfg = statusCfg[status] ?? statusCfg.failed;
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold ${cfg.cls}`}>
      {cfg.icon}{cfg.label}
    </span>
  );
};

const SelectInput = ({
  value, onChange, children, className = "",
}: { value: string | number; onChange: (v: string) => void; children: React.ReactNode; className?: string }) => (
  <select
    value={value}
    onChange={e => onChange(e.target.value)}
    className={`bg-white/8 border border-white/12 text-white text-sm rounded-lg px-2.5 py-2
      outline-none focus:border-violet-500/50 transition-colors cursor-pointer ${className}`}
  >
    {children}
  </select>
);

// ── Main component ────────────────────────────────────────────────────────────

export default function AdminPushBroadcast() {
  // Form
  const [title,        setTitle]        = useState("");
  const [message,      setMessage]      = useState("");
  const [url,          setUrl]          = useState("");
  const [sendMode,     setSendMode]     = useState<SendMode>("now");
  const [scheduledAt,  setScheduledAt]  = useState("");
  // Segment
  const [segment,      setSegment]      = useState<SegmentType>("all");
  const [babyMin,      setBabyMin]      = useState(0);
  const [babyMax,      setBabyMax]      = useState(6);
  const [courseId,     setCourseId]     = useState("");
  const [lang,         setLang]         = useState<"en"|"ms"|"zh">("en");
  const [courses,      setCourses]      = useState<Course[]>([]);
  // UI state
  const [sending,      setSending]      = useState(false);
  const [cancelling,   setCancelling]   = useState<string | null>(null);
  const [result,       setResult]       = useState<{
    ok: boolean; scheduled?: boolean; scheduledAt?: string;
    recipients?: number; skipped?: boolean; error?: string;
  } | null>(null);
  const [history,      setHistory]      = useState<Broadcast[]>([]);
  const [loading,      setLoading]      = useState(true);

  // Load published courses for the course-enrollment segment
  useEffect(() => {
    pb.collection("courses").getFullList({
      filter: "is_published = true", sort: "title_en",
      fields: "id,title_en", requestKey: null,
    }).then(items => setCourses(items as unknown as Course[])).catch(() => {});
  }, []);

  const fetchHistory = async () => {
    try {
      const res = await pb.collection("push_broadcasts").getList(1, 50, {
        sort: "-created", expand: "sent_by", requestKey: null,
      });
      const items = res.items as unknown as Broadcast[];
      // Pending first, then by created desc
      items.sort((a, b) => {
        if (a.status === "pending" && b.status !== "pending") return -1;
        if (a.status !== "pending" && b.status === "pending") return 1;
        return new Date(b.created).getTime() - new Date(a.created).getTime();
      });
      setHistory(items);
    } catch (_) {}
    finally { setLoading(false); }
  };

  useEffect(() => { fetchHistory(); }, []);

  // Build segment config object from current UI state
  const buildSegmentConfig = (): SegmentConfig | null => {
    if (segment === "all" || segment === "subscribed") return null;
    const course = courses.find(c => c.id === courseId);
    const map: Record<SegmentType, SegmentConfig | null> = {
      all:            null,
      subscribed:     null,
      baby_age:       { type: "baby_age",       minMonths: babyMin, maxMonths: babyMax, label: `Baby age ${babyMin}–${babyMax} months` },
      expectant:      { type: "expectant",       label: "Expectant mothers" },
      course_enrolled:courseId ? { type: "course_enrolled", courseId, courseName: course?.title_en, label: `Enrolled in: ${course?.title_en ?? "—"}` } : null,
      not_enrolled:   { type: "not_enrolled",    label: "Not yet enrolled in any course" },
      language:       { type: "language",        lang,  label: `App language: ${LANG_LABELS[lang]}` },
    };
    return map[segment];
  };

  const isSegmentValid = () => {
    if (segment === "course_enrolled" && !courseId) return false;
    if (segment === "baby_age" && babyMin >= babyMax) return false;
    return true;
  };

  const resetForm = () => {
    setTitle(""); setMessage(""); setUrl(""); setScheduledAt("");
  };

  const handleSend = async (e: FormEvent) => {
    e.preventDefault();
    if (!isSegmentValid()) return;
    setSending(true); setResult(null);
    try {
      const segConfig = buildSegmentConfig();
      const target = segment === "subscribed" ? "subscribed"
                   : segment === "all"        ? "all"
                   : "segment";
      const body: Record<string, unknown> = {
        title: title.trim(), message: message.trim(), url: url.trim(), target,
        ...(segConfig ? { segment_config: segConfig } : {}),
        ...(sendMode === "schedule" && scheduledAt
          ? { scheduled_at: new Date(scheduledAt).toISOString() } : {}),
      };
      const res = await pb.send("/api/admin/push-broadcast", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      }) as { ok: boolean; scheduled?: boolean; scheduled_at?: string; recipients?: number };

      setResult(res.scheduled
        ? { ok: true, scheduled: true, scheduledAt: res.scheduled_at }
        : { ok: true, recipients: res.recipients });
      resetForm();
      fetchHistory();
    } catch (err) {
      setResult({ ok: false, error: String(err) });
    } finally { setSending(false); }
  };

  const handleCancel = async (id: string) => {
    if (!confirm("Cancel this scheduled broadcast?")) return;
    setCancelling(id);
    try {
      await pb.send("/api/admin/push-broadcast/cancel", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id }),
      });
      fetchHistory();
    } catch (_) { alert("Failed to cancel. Please try again."); }
    finally { setCancelling(null); }
  };

  const pending = history.filter(b => b.status === "pending");
  const past    = history.filter(b => b.status !== "pending");
  const totalSent  = history.filter(b => b.status === "sent").length;
  const totalReach = history.reduce((s, b) => s + (b.recipient_count || 0), 0);

  return (
    <div className="space-y-6">

      {/* ── Header ─────────────────────────────────────────────────────── */}
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-2xl flex items-center justify-center"
          style={{ background: "rgba(139,92,246,0.15)" }}>
          <Bell size={20} className="text-violet-400" />
        </div>
        <div>
          <h1 className="text-white font-bold text-xl">Push Broadcast</h1>
          <p className="text-white/40 text-sm">Send or schedule targeted push notifications</p>
        </div>
      </div>

      {/* ── Stats ──────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        {[
          { Icon: Send,       label: "Broadcasts Sent",   value: totalSent,      color: "#8b5cf6" },
          { Icon: Smartphone, label: "Devices Reached",   value: totalReach,     color: "#10b981" },
          { Icon: Clock,      label: "Scheduled Pending", value: pending.length, color: "#f59e0b" },
          { Icon: Filter,     label: "Total in History",  value: history.length, color: "#3b82f6" },
        ].map(s => (
          <div key={s.label} className="rounded-2xl p-4 border border-white/5 flex items-start gap-3"
            style={{ background: "rgba(255,255,255,0.03)" }}>
            <div className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
              style={{ background: `${s.color}20` }}>
              <s.Icon size={16} style={{ color: s.color }} />
            </div>
            <div className="min-w-0">
              <p className="text-white/40 text-[11px] font-medium leading-snug">{s.label}</p>
              <p className="text-white text-2xl font-bold mt-0.5">{s.value}</p>
            </div>
          </div>
        ))}
      </div>

      {/* ── Compose + Preview ──────────────────────────────────────────── */}
      <div className="grid lg:grid-cols-5 gap-5">

        {/* Compose — 3 cols */}
        <div className="lg:col-span-3 rounded-2xl border border-white/5 p-5 space-y-5"
          style={{ background: "rgba(255,255,255,0.03)" }}>

          <h2 className="text-white font-semibold flex items-center gap-2">
            <Send size={15} className="text-violet-400" /> Compose Notification
          </h2>

          <form onSubmit={handleSend} className="space-y-5">

            {/* Title */}
            <div>
              <div className="flex justify-between mb-1.5">
                <label className="text-white/50 text-[11px] font-semibold uppercase tracking-wide">Title</label>
                <span className={`text-[11px] ${title.length > TITLE_MAX * 0.85 ? "text-amber-400" : "text-white/25"}`}>
                  {title.length}/{TITLE_MAX}
                </span>
              </div>
              <input type="text" value={title} required
                onChange={e => setTitle(e.target.value.slice(0, TITLE_MAX))}
                placeholder="e.g. New Course Available!"
                className="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white text-sm
                  placeholder-white/20 outline-none focus:border-violet-500/50 transition-colors" />
            </div>

            {/* Message */}
            <div>
              <div className="flex justify-between mb-1.5">
                <label className="text-white/50 text-[11px] font-semibold uppercase tracking-wide">Message</label>
                <span className={`text-[11px] ${message.length > MSG_MAX * 0.85 ? "text-amber-400" : "text-white/25"}`}>
                  {message.length}/{MSG_MAX}
                </span>
              </div>
              <textarea value={message} required rows={3}
                onChange={e => setMessage(e.target.value.slice(0, MSG_MAX))}
                placeholder="e.g. Our new Breastfeeding Basics course is now live — tap to start learning!"
                className="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white text-sm
                  placeholder-white/20 outline-none focus:border-violet-500/50 transition-colors resize-none" />
            </div>

            {/* Deep link */}
            <div>
              <label className="text-white/50 text-[11px] font-semibold uppercase tracking-wide flex items-center gap-1.5 mb-1.5">
                <ExternalLink size={11} /> Deep Link
                <span className="text-white/20 normal-case font-normal">— optional</span>
              </label>
              <input type="url" value={url} onChange={e => setUrl(e.target.value)}
                placeholder="https://app.sihatdarimula.my/courses/…"
                className="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white text-sm
                  placeholder-white/20 outline-none focus:border-violet-500/50 transition-colors" />
            </div>

            {/* ── Audience Segment ───────────────────────────────────── */}
            <div>
              <label className="text-white/50 text-[11px] font-semibold uppercase tracking-wide flex items-center gap-1.5 mb-3">
                <Filter size={11} /> Audience Segment
              </label>

              <div className="space-y-1.5">
                {SEGMENT_DEFS.map(({ type, Icon, label, desc }) => {
                  const active = segment === type;
                  return (
                    <label key={type}
                      className={`flex items-start gap-3 p-3 rounded-xl border cursor-pointer transition-all select-none ${
                        active
                          ? "bg-violet-600/12 border-violet-500/30"
                          : "bg-white/[0.02] border-white/8 hover:bg-white/[0.04] hover:border-white/12"
                      }`}>
                      <input type="radio" name="segment" value={type}
                        checked={active}
                        onChange={() => setSegment(type as SegmentType)}
                        className="mt-0.5 accent-violet-500 shrink-0" />

                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <Icon size={13} className={active ? "text-violet-400" : "text-white/30"} />
                          <span className={`text-sm font-semibold ${active ? "text-white" : "text-white/55"}`}>
                            {label}
                          </span>
                        </div>
                        <p className="text-white/30 text-[11px] mt-0.5 ml-5 leading-snug">{desc}</p>

                        {/* ── Sub-options ─────────────────────────── */}
                        {active && type === "baby_age" && (
                          <div className="mt-3 ml-5 flex flex-wrap items-center gap-2">
                            <span className="text-white/50 text-xs">From</span>
                            <SelectInput value={babyMin} onChange={v => setBabyMin(Number(v))}>
                              {MONTH_OPTS.filter(m => m < babyMax).map(m => (
                                <option key={m} value={m}>{fmtMonths(m)}</option>
                              ))}
                            </SelectInput>
                            <span className="text-white/50 text-xs">to</span>
                            <SelectInput value={babyMax} onChange={v => setBabyMax(Number(v))}>
                              {MONTH_OPTS.filter(m => m > babyMin).map(m => (
                                <option key={m} value={m}>{fmtMonths(m)}</option>
                              ))}
                            </SelectInput>
                            <span className="text-white/30 text-[11px]">old</span>
                            {babyMin >= babyMax && (
                              <p className="w-full text-rose-400 text-[11px]">Max must be greater than min.</p>
                            )}
                          </div>
                        )}

                        {active && type === "course_enrolled" && (
                          <div className="mt-3 ml-5">
                            {courses.length === 0 ? (
                              <p className="text-white/30 text-xs">No published courses found.</p>
                            ) : (
                              <SelectInput value={courseId} onChange={setCourseId} className="w-full max-w-xs">
                                <option value="">— Select a course —</option>
                                {courses.map(c => (
                                  <option key={c.id} value={c.id}>{c.title_en}</option>
                                ))}
                              </SelectInput>
                            )}
                            {!courseId && (
                              <p className="text-amber-400/80 text-[11px] mt-1.5">Please select a course.</p>
                            )}
                          </div>
                        )}

                        {active && type === "language" && (
                          <div className="mt-3 ml-5 flex gap-2">
                            {(["en", "ms", "zh"] as const).map(l => (
                              <button key={l} type="button" onClick={() => setLang(l)}
                                className={`px-3 py-1.5 rounded-lg text-xs font-semibold border transition-all ${
                                  lang === l
                                    ? "bg-violet-600/20 border-violet-500/40 text-violet-300"
                                    : "bg-white/5 border-white/10 text-white/40 hover:text-white/60"
                                }`}>
                                {LANG_LABELS[l]}
                              </button>
                            ))}
                          </div>
                        )}
                      </div>
                    </label>
                  );
                })}
              </div>
            </div>

            {/* ── When to send ───────────────────────────────────────── */}
            <div>
              <label className="text-white/50 text-[11px] font-semibold uppercase tracking-wide flex items-center gap-1.5 mb-2">
                <CalendarClock size={11} /> When to Send
              </label>
              <div className="flex gap-2 mb-3">
                {([
                  ["now",      <Zap size={13}/>,           "Send Now",          "Deliver immediately"],
                  ["schedule", <CalendarClock size={13}/>, "Schedule",          "Pick a future date & time"],
                ] as const).map(([val, icon, label, hint]) => (
                  <button key={val} type="button" onClick={() => setSendMode(val as SendMode)}
                    className={`flex-1 flex flex-col items-center gap-0.5 py-2.5 rounded-xl text-xs font-semibold border transition-all ${
                      sendMode === val
                        ? "bg-violet-600/20 border-violet-500/40 text-violet-300"
                        : "bg-white/5 border-white/10 text-white/40 hover:text-white/60"
                    }`}>
                    <span className="flex items-center gap-1">{icon} {label}</span>
                    <span className="text-[10px] font-normal opacity-60">{hint}</span>
                  </button>
                ))}
              </div>
              {sendMode === "schedule" && (
                <div className="rounded-xl border border-amber-500/20 bg-amber-500/5 p-3 space-y-2">
                  <label className="text-amber-300/80 text-[11px] font-semibold flex items-center gap-1.5">
                    <Clock size={11}/> Date & Time
                    <span className="text-amber-300/40 font-normal">(Malaysia Time — UTC+8)</span>
                  </label>
                  <input type="datetime-local"
                    value={scheduledAt} min={minDateTime()}
                    required={sendMode === "schedule"}
                    onChange={e => setScheduledAt(e.target.value)}
                    className="w-full px-3 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white text-sm
                      outline-none focus:border-amber-500/50 transition-colors
                      [&::-webkit-calendar-picker-indicator]:invert [&::-webkit-calendar-picker-indicator]:opacity-40"
                  />
                  <p className="text-white/25 text-[10px] leading-snug">
                    Checked every 5 minutes — your notification goes out within 5 minutes of the chosen time.
                  </p>
                </div>
              )}
            </div>

            {/* Result banner */}
            {result && (
              <div className={`flex items-start gap-2.5 px-4 py-3 rounded-xl border text-sm ${
                result.ok
                  ? result.scheduled
                    ? "bg-amber-500/10 border-amber-500/20 text-amber-300"
                    : "bg-emerald-500/10 border-emerald-500/20 text-emerald-300"
                  : "bg-rose-500/10 border-rose-500/20 text-rose-300"
              }`}>
                {result.ok
                  ? result.scheduled ? <Clock size={16} className="shrink-0 mt-0.5"/>
                    : <CheckCircle size={16} className="shrink-0 mt-0.5"/>
                  : <XCircle size={16} className="shrink-0 mt-0.5"/>}
                <span>
                  {result.ok
                    ? result.scheduled
                      ? <>Broadcast scheduled for <strong>{result.scheduledAt ? toMYT(result.scheduledAt) : "the chosen time"}</strong>.</>
                      : result.recipients === 0
                        ? "No matching users found for this segment — no notification was sent."
                        : <>Sent to <strong>{result.recipients} device{result.recipients !== 1 ? "s" : ""}</strong> successfully!</>
                    : `Failed: ${result.error || "Please try again."}`}
                </span>
              </div>
            )}

            {/* Submit */}
            <button type="submit"
              disabled={sending || !title.trim() || !message.trim() || !isSegmentValid() || (sendMode === "schedule" && !scheduledAt)}
              className="w-full flex items-center justify-center gap-2 py-3.5 rounded-xl font-bold text-sm text-white
                transition-all disabled:opacity-40 disabled:cursor-not-allowed hover:opacity-90 active:scale-[0.98]"
              style={{ background: sendMode === "schedule"
                ? "linear-gradient(135deg,#b45309,#d97706)"
                : "linear-gradient(135deg,#7c3aed,#db2777)" }}>
              {sending ? (
                <><div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"/>Processing…</>
              ) : sendMode === "schedule" ? (
                <><CalendarClock size={16}/>Schedule Broadcast</>
              ) : (
                <><Send size={16}/>Send Push Notification</>
              )}
            </button>
          </form>
        </div>

        {/* Preview — 2 cols */}
        <div className="lg:col-span-2">
          <div className="rounded-2xl border border-white/5 p-5 lg:sticky lg:top-6"
            style={{ background: "rgba(255,255,255,0.03)" }}>
            <h2 className="text-white font-semibold flex items-center gap-2 mb-4">
              <Smartphone size={15} className="text-violet-400"/> Live Preview
            </h2>

            {/* Phone */}
            <div className="rounded-[28px] border-2 border-white/10 overflow-hidden"
              style={{ background: "rgba(8,4,20,0.95)" }}>
              <div className="flex justify-between items-center px-5 pt-3 pb-2">
                <span className="text-white/30 text-[11px] font-bold">9:41</span>
                <div className="flex items-center gap-1.5">
                  <div className="flex gap-0.5 items-end">
                    {[2,3,4,5].map((h, i) => (
                      <div key={i} className="w-1 rounded-sm bg-white/40" style={{ height: h * 2.5 }}/>
                    ))}
                  </div>
                  <svg className="w-5 h-3 text-white/40 ml-1" viewBox="0 0 24 12" fill="currentColor">
                    <rect x="0" y="0" width="20" height="12" rx="2" fillOpacity="0.3"/>
                    <rect x="1" y="1" width="14" height="10" rx="1.5"/>
                    <rect x="21" y="3" width="3" height="6" rx="1.5" fillOpacity="0.5"/>
                  </svg>
                </div>
              </div>
              <div className="px-3 pb-5 space-y-2">
                <div className="h-10 rounded-2xl bg-white/[0.03] border border-white/5"/>
                <div className="rounded-2xl border border-violet-500/25 overflow-hidden"
                  style={{ background: "rgba(255,255,255,0.07)" }}>
                  <div className="px-3 pt-2.5 pb-0.5 flex items-center gap-1.5">
                    <div className="w-4 h-4 rounded-md overflow-hidden shrink-0 bg-violet-700/60 flex items-center justify-center">
                      <AppLogo size={12}/>
                    </div>
                    <span className="text-white/40 text-[10px] font-bold uppercase tracking-wide">Sihat dari Mula</span>
                    <span className="ml-auto text-white/25 text-[10px]">
                      {sendMode === "schedule" && scheduledAt
                        ? <span className="text-amber-400/60 flex items-center gap-0.5"><Clock size={9}/> scheduled</span>
                        : "now"}
                    </span>
                  </div>
                  <div className="px-3 pb-3 pt-1">
                    <p className="text-white text-[13px] font-bold leading-snug min-h-[18px]">
                      {title.trim() || <span className="text-white/20 italic font-normal">Title…</span>}
                    </p>
                    <p className="text-white/55 text-[11px] leading-snug mt-0.5 min-h-[16px] line-clamp-2">
                      {message.trim() || <span className="text-white/20 italic">Message…</span>}
                    </p>
                  </div>
                </div>
                <div className="h-9 rounded-2xl bg-white/[0.03] border border-white/5"/>
              </div>
            </div>

            {/* Segment summary */}
            <div className="mt-3 rounded-xl border border-white/8 px-3 py-2.5 flex items-start gap-2"
              style={{ background: "rgba(255,255,255,0.02)" }}>
              <Filter size={12} className="text-white/30 mt-0.5 shrink-0"/>
              <div className="min-w-0">
                <p className="text-white/35 text-[10px] font-semibold uppercase tracking-wide">Target audience</p>
                <p className="text-white/70 text-xs mt-0.5 font-medium leading-snug">
                  {segment === "all"            ? "All registered users"
                   : segment === "subscribed"   ? "Push subscribers only"
                   : segment === "baby_age"     ? `Babies ${babyMin}–${babyMax} months old`
                   : segment === "expectant"    ? "Expectant mothers"
                   : segment === "course_enrolled"
                     ? (courseId ? `Enrolled in: ${courses.find(c => c.id === courseId)?.title_en ?? "—"}` : "— Select a course")
                   : segment === "not_enrolled" ? "Not yet enrolled in any course"
                   : segment === "language"     ? `App language: ${LANG_LABELS[lang]}`
                   : "—"}
                </p>
              </div>
            </div>

            <p className="text-white/20 text-[11px] text-center mt-3">Approx. Android lock-screen appearance</p>
          </div>
        </div>
      </div>

      {/* ── Upcoming scheduled ─────────────────────────────────────────── */}
      {pending.length > 0 && (
        <div className="rounded-2xl border border-amber-500/15 overflow-hidden"
          style={{ background: "rgba(245,158,11,0.04)" }}>
          <div className="flex items-center gap-2 px-5 py-4 border-b border-amber-500/10">
            <Clock size={15} className="text-amber-400"/>
            <h2 className="text-white font-semibold">Upcoming Scheduled</h2>
            <span className="ml-auto bg-amber-500/20 text-amber-400 text-[10px] font-bold px-2 py-0.5 rounded-full">
              {pending.length}
            </span>
          </div>
          <div className="divide-y divide-white/5">
            {pending.map(b => (
              <div key={b.id} className="flex items-start gap-4 px-5 py-4">
                <CalendarClock size={15} className="text-amber-400 mt-0.5 shrink-0"/>
                <div className="flex-1 min-w-0">
                  <p className="text-white text-sm font-semibold truncate">{b.title}</p>
                  <p className="text-white/40 text-xs mt-0.5 line-clamp-1">{b.message}</p>
                  <div className="flex flex-wrap gap-x-3 gap-y-0.5 mt-1.5">
                    {b.scheduled_at && (
                      <p className="text-amber-400/80 text-[11px] flex items-center gap-1">
                        <Clock size={10}/> {toMYT(b.scheduled_at)}
                      </p>
                    )}
                    <p className="text-white/30 text-[11px] flex items-center gap-1">
                      <Filter size={10}/> {audienceLabel(b)}
                    </p>
                  </div>
                </div>
                <div className="text-right shrink-0 space-y-1.5">
                  <StatusBadge status={b.status}/>
                  <div>
                    <button onClick={() => handleCancel(b.id)}
                      disabled={cancelling === b.id}
                      className="flex items-center gap-1 text-rose-400/70 hover:text-rose-400 text-[11px] font-semibold transition-colors disabled:opacity-40 ml-auto">
                      <Trash2 size={11}/>
                      {cancelling === b.id ? "Cancelling…" : "Cancel"}
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ── History ────────────────────────────────────────────────────── */}
      <div className="rounded-2xl border border-white/5 overflow-hidden"
        style={{ background: "rgba(255,255,255,0.03)" }}>
        <div className="flex items-center justify-between px-5 py-4 border-b border-white/5">
          <h2 className="text-white font-semibold">Broadcast History</h2>
          <span className="text-white/30 text-xs">{past.length} records</span>
        </div>

        {loading ? (
          <div className="flex justify-center py-10">
            <div className="w-6 h-6 border-2 border-violet-500 border-t-transparent rounded-full animate-spin"/>
          </div>
        ) : past.length === 0 ? (
          <div className="py-12 text-center">
            <Bell size={28} className="text-white/10 mx-auto mb-2"/>
            <p className="text-white/30 text-sm">No broadcasts sent yet</p>
          </div>
        ) : (
          <div className="divide-y divide-white/5">
            {past.map(b => (
              <div key={b.id} className="flex items-start gap-4 px-5 py-4 hover:bg-white/[0.02] transition-colors">
                <div className="mt-0.5 shrink-0">
                  {b.status === "sent"       ? <CheckCircle size={15} className="text-emerald-400"/>
                  : b.status === "failed"    ? <XCircle     size={15} className="text-rose-400"/>
                  : b.status === "cancelled" ? <XCircle     size={15} className="text-white/20"/>
                  :                            <Clock        size={15} className="text-amber-400"/>}
                </div>
                <div className="flex-1 min-w-0">
                  <p className={`text-sm font-semibold truncate ${b.status === "cancelled" ? "text-white/25 line-through" : "text-white"}`}>
                    {b.title}
                  </p>
                  <p className="text-white/40 text-xs mt-0.5 line-clamp-1">{b.message}</p>
                  <div className="flex flex-wrap gap-x-3 gap-y-0.5 mt-1">
                    <p className="text-white/25 text-[11px] flex items-center gap-1">
                      <Filter size={10}/> {audienceLabel(b)}
                    </p>
                    {b.expand?.sent_by && (
                      <p className="text-white/20 text-[11px]">
                        by {b.expand.sent_by.name || b.expand.sent_by.email}
                      </p>
                    )}
                    {b.scheduled_at && b.status !== "pending" && (
                      <p className="text-white/20 text-[10px] flex items-center gap-1">
                        <CalendarClock size={9}/> was scheduled for {toMYT(b.scheduled_at)}
                      </p>
                    )}
                  </div>
                </div>
                <div className="text-right shrink-0 space-y-1">
                  <StatusBadge status={b.status}/>
                  {b.status === "sent" && (
                    <p className="text-white/35 text-[11px] font-semibold">{b.recipient_count ?? 0} devices</p>
                  )}
                  <p className="text-white/20 text-[10px]">
                    {new Date(b.created).toLocaleDateString("en-GB", {
                      day: "numeric", month: "short", year: "numeric",
                    })}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
