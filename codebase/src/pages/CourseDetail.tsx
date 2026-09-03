import { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { ChevronLeft, BookOpen, CheckCircle, Circle, ChevronRight, Play, Download, WifiOff } from "lucide-react";
import pb from "../lib/pocketbase";
import { useAuth } from "../contexts/AuthContext";
import { useLang } from "../contexts/LanguageContext";

interface Lesson { id: string; title_en: string; title_ms: string; title_zh: string; order: number; is_published: boolean; module: string; has_quiz: boolean; }
interface Module { id: string; title_en: string; title_ms: string; title_zh: string; order: number; }
interface Progress { lesson: string; is_completed: boolean; watch_percent: number; }

export default function CourseDetail() {
  const { courseId } = useParams<{ courseId: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { lang } = useLang();

  const [course, setCourse] = useState<Record<string, unknown> | null>(null);
  const [lessons, setLessons] = useState<Lesson[]>([]);
  const [modules, setModules] = useState<Module[]>([]);
  const [enrollment, setEnrollment] = useState<Record<string, unknown> | null>(null);
  const [progress, setProgress] = useState<Progress[]>([]);
  const [loading, setLoading] = useState(true);
  const [enrolling, setEnrolling] = useState(false);

  const getField = (obj: Record<string, unknown>, field: string) => {
    if (lang !== "en") { const l = obj[`${field}_${lang}`]; if (l && String(l).trim()) return String(l); }
    // Always fall back to the _en variant first, then the bare field name
    return String(obj[`${field}_en`] ?? obj[field] ?? "");
  };

  useEffect(() => {
    if (!courseId || !user) return;
    (async () => {
      const [c, ls, ms] = await Promise.all([
        pb.collection("courses").getOne(courseId, { requestKey: null }),
        pb.collection("lessons").getFullList({ filter: pb.filter("course = {:c} && is_published = true", { c: courseId }), sort: "order,created", requestKey: null }),
        pb.collection("course_modules").getFullList({ filter: pb.filter("course = {:c}", { c: courseId }), sort: "order", requestKey: null }),
      ]);
      setCourse(c as unknown as Record<string, unknown>);
      setLessons(ls as unknown as Lesson[]);
      setModules(ms as unknown as Module[]);

      try {
        const enr = await pb.collection("enrollments").getFirstListItem(
          pb.filter("user = {:u} && course = {:c}", { u: user.id, c: courseId }), { requestKey: null }
        );
        setEnrollment(enr as unknown as Record<string, unknown>);
        const prg = await pb.collection("lesson_progress").getFullList({
          filter: pb.filter("user = {:u} && course = {:c}", { u: user.id, c: courseId }), requestKey: null
        });
        setProgress(prg as unknown as Progress[]);
      } catch { /* not enrolled */ }
      setLoading(false);
    })();
  }, [courseId, user]);

  const enroll = async () => {
    if (!courseId || !user) return;
    setEnrolling(true);
    try {
      const enr = await pb.collection("enrollments").create({ user: user.id, course: courseId, progress_percent: 0 });
      setEnrollment(enr as unknown as Record<string, unknown>);
    } finally { setEnrolling(false); }
  };

  const getProgress = (lessonId: string) => progress.find(p => p.lesson === lessonId);
  const completedCount = progress.filter(p => p.is_completed).length;
  const overallPct = lessons.length > 0 ? Math.round((completedCount / lessons.length) * 100) : 0;

  const renderLesson = (lesson: Lesson, idx: number) => {
    const prg = getProgress(lesson.id);
    const isDone = prg?.is_completed ?? false;
    const inProgress = (prg?.watch_percent ?? 0) > 0 && !isDone;
    return (
      <button key={lesson.id} onClick={() => enrollment && navigate(`/courses/${courseId}/lessons/${lesson.id}`)}
        className={`flex items-center gap-3 w-full p-3 rounded-2xl text-left transition-all ${
          enrollment ? "hover:bg-amber-50 active:scale-[0.99]" : "opacity-60 cursor-default"
        }`}>
        <div className={`w-9 h-9 rounded-full flex items-center justify-center shrink-0 ${
          isDone ? "bg-emerald-100 text-emerald-600" : inProgress ? "bg-amber-100 text-amber-600" : "bg-gray-100 text-gray-400"
        }`}>
          {isDone ? <CheckCircle size={18} /> : inProgress ? <Play size={16} /> : <Circle size={18} />}
        </div>
        <div className="flex-1 min-w-0">
          <p className={`font-semibold text-sm leading-snug ${isDone ? "text-gray-500" : "text-gray-800"}`}>
            {idx + 1}. {getField(lesson as unknown as Record<string, unknown>, "title")}
          </p>
          {lesson.has_quiz && <p className="text-[11px] text-amber-600 mt-0.5">Includes quiz</p>}
        </div>
        {inProgress && <span className="text-[10px] text-amber-600 font-bold shrink-0">{prg?.watch_percent}%</span>}
        {enrollment && !isDone && <ChevronRight size={14} className="text-gray-300 shrink-0" />}
      </button>
    );
  };

  if (loading) return (
    <div className="h-[100dvh] bg-cream flex items-center justify-center">
      <div className="animate-spin rounded-full h-8 w-8 border-2 border-amber-500 border-t-transparent" />
    </div>
  );

  if (!course) return <div className="h-[100dvh] flex items-center justify-center text-gray-400">Course not found</div>;

  const hasModules = !!course.has_modules && modules.length > 0;

  return (
    <div className="h-[100dvh] bg-cream flex flex-col overflow-hidden">
      <header className="glass-header px-4 py-3 flex items-center gap-3 shrink-0 z-10">
        <button onClick={() => navigate("/content")} className="p-1 -ml-1">
          <ChevronLeft size={22} className="text-gray-600" />
        </button>
        <h1 className="font-bold text-gray-800 text-sm truncate flex-1">{getField(course, "title")}</h1>
      </header>

      <div className="flex-1 overflow-y-auto">
        {/* Hero */}
        <div className="relative w-full h-52 bg-gradient-to-br from-amber-100 to-orange-50 flex items-center justify-center overflow-hidden">
          {course.thumbnail ? (
            <img src={pb.files.getURL(course as never, String(course.thumbnail))} alt="" className="w-full h-full object-cover" />
          ) : (
            <img
              src="https://images.unsplash.com/photo-1519689680058-324335c77eba?w=800&auto=format&fit=crop&q=80"
              alt="Mother with newborn"
              className="w-full h-full object-cover"
            />
          )}
          <div className="absolute inset-0 bg-gradient-to-t from-black/50 to-transparent" />
          <div className="absolute bottom-4 left-4 right-4">
            <div className="flex gap-2 mb-2">
              <span className="text-[10px] font-bold text-white/80 bg-white/20 px-2 py-0.5 rounded-full capitalize">{String(course.category ?? "")}</span>
              <span className="text-[10px] font-bold text-white/80 bg-white/20 px-2 py-0.5 rounded-full capitalize">{String(course.level ?? "")}</span>
            </div>
            <h2 className="text-white font-bold text-xl leading-tight">{getField(course, "title")}</h2>
          </div>
        </div>

        <div className="p-4 space-y-4">
          {/* Description */}
          {getField(course, "description") && (
            <p className="text-gray-600 text-sm leading-relaxed">{getField(course, "description")}</p>
          )}

          {/* Progress + enroll */}
          <div className="glass rounded-2xl p-4 space-y-3">
            <div className="flex items-center justify-between text-sm">
              <span className="font-semibold text-gray-700">{lessons.length} lessons</span>
              {enrollment && <span className="text-amber-600 font-bold">{overallPct}% complete</span>}
            </div>
            {enrollment && (
              <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
                <div className="h-full rounded-full bg-gradient-to-r from-amber-400 to-emerald-400 transition-all duration-700"
                  style={{ width: `${overallPct}%` }} />
              </div>
            )}
            {!enrollment ? (
              <button onClick={enroll} disabled={enrolling}
                className="w-full py-3 rounded-2xl glass-btn text-white font-bold text-sm">
                {enrolling ? "Enrolling..." : "Enroll Now — Free"}
              </button>
            ) : overallPct < 100 ? (
              <button onClick={() => {
                const next = lessons.find(l => !getProgress(l.id)?.is_completed);
                if (next) navigate(`/courses/${courseId}/lessons/${next.id}`);
              }} className="w-full py-3 rounded-2xl bg-amber-500 text-white font-bold text-sm flex items-center justify-center gap-2">
                <Play size={16} /> Continue Learning
              </button>
            ) : (
              <div className="w-full py-3 rounded-2xl bg-emerald-500 text-white font-bold text-sm flex items-center justify-center gap-2">
                <CheckCircle size={16} /> Course Complete!
              </div>
            )}
          </div>

          {/* Offline notice */}
          {!navigator.onLine && (
            <div className="flex items-center gap-2 px-3 py-2 bg-amber-50 rounded-xl text-amber-700 text-xs font-medium">
              <WifiOff size={14} /> Progress saved offline — syncs when reconnected
            </div>
          )}

          {/* Curriculum */}
          <div>
            <h3 className="font-bold text-gray-800 text-sm mb-3 flex items-center gap-2">
              <BookOpen size={16} className="text-amber-500" /> Curriculum
            </h3>
            {hasModules ? modules.map(mod => {
              const modLessons = lessons.filter(l => l.module === mod.id);
              return (
                <div key={mod.id} className="mb-4">
                  <p className="text-xs font-bold text-gray-500 uppercase tracking-wide px-3 mb-1">
                    {getField(mod as unknown as Record<string, unknown>, "title")}
                  </p>
                  <div className="glass rounded-2xl overflow-hidden divide-y divide-white/30">
                    {modLessons.map((l, i) => renderLesson(l, i))}
                  </div>
                </div>
              );
            }) : (
              <div className="glass rounded-2xl overflow-hidden divide-y divide-white/30">
                {lessons.map((l, i) => renderLesson(l, i))}
              </div>
            )}
          </div>

          <div className="flex items-center gap-2 text-xs text-gray-400 px-1 pb-2">
            <Download size={12} />
            <span>Lesson content cached offline for 7 days after viewing</span>
          </div>
        </div>
      </div>
    </div>
  );
}
