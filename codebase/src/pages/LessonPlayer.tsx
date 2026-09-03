import { useState, useEffect, useRef, useCallback } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { ChevronLeft, WifiOff, CheckCircle, BookOpen } from "lucide-react";
import pb from "../lib/pocketbase";
import { useAuth } from "../contexts/AuthContext";
import { useLang } from "../contexts/LanguageContext";
import VideoPlayer from "../components/lms/VideoPlayer";
import QuizPlayer, { QuizQuestion } from "../components/lms/QuizPlayer";
import { useXAPI } from "../hooks/useXAPI";

type Phase = "watching" | "quiz" | "done";

export default function LessonPlayer() {
  const { courseId, lessonId } = useParams<{ courseId: string; lessonId: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { lang } = useLang();
  const { record: xRecord } = useXAPI();

  const [lesson, setLesson] = useState<Record<string, unknown> | null>(null);
  const [quiz, setQuiz] = useState<{ questions: QuizQuestion[]; passing_score: number } | null>(null);
  const [progress, setProgress] = useState<Record<string, unknown> | null>(null);
  const [phase, setPhase] = useState<Phase>("watching");
  const [watchPct, setWatchPct] = useState(0);
  const [loading, setLoading] = useState(true);
  const [allLessons, setAllLessons] = useState<{ id: string }[]>([]);
  const progressId = useRef<string | null>(null);
  const startTime = useRef(Date.now());
  const saveTimer = useRef<ReturnType<typeof setInterval> | null>(null);
  const latestPct = useRef(0);
  const latestSec = useRef(0);

  const getField = (obj: Record<string, unknown>, field: string) => {
    if (lang !== "en") { const l = obj[`${field}_${lang}`]; if (l && String(l).trim()) return String(l); }
    return String(obj[field] ?? "");
  };

  useEffect(() => {
    if (!lessonId || !courseId || !user) return;
    startTime.current = Date.now();
    xRecord("initialized", "lesson", lessonId);

    (async () => {
      const [l, ls] = await Promise.all([
        pb.collection("lessons").getOne(lessonId, { requestKey: null }),
        pb.collection("lessons").getFullList({ filter: pb.filter("course = {:c} && is_published = true", { c: courseId }), sort: "order", requestKey: null }),
      ]);
      setLesson(l as unknown as Record<string, unknown>);
      setAllLessons(ls as unknown as { id: string }[]);

      if (l.has_quiz) {
        try {
          const q = await pb.collection("lesson_quizzes").getFirstListItem(
            pb.filter("lesson = {:l}", { l: lessonId }), { requestKey: null }
          );
          setQuiz({ questions: q.questions as QuizQuestion[], passing_score: (q.passing_score as number) ?? 70 });
        } catch { /* no quiz */ }
      }

      try {
        const prg = await pb.collection("lesson_progress").getFirstListItem(
          pb.filter("user = {:u} && lesson = {:l}", { u: user.id, l: lessonId }), { requestKey: null }
        );
        setProgress(prg as unknown as Record<string, unknown>);
        progressId.current = prg.id;
        setWatchPct((prg.watch_percent as number) ?? 0);
        if (prg.is_completed) setPhase("done");
        else if (prg.is_video_complete && l.has_quiz) setPhase("quiz");
      } catch { /* no progress yet */ }
      setLoading(false);
    })();

    return () => { if (saveTimer.current) clearInterval(saveTimer.current); };
  }, [lessonId, courseId, user]);

  const saveProgress = useCallback(async (pct: number, sec: number, isVideoComplete = false) => {
    if (!user || !lessonId || !courseId) return;
    const data = { user: user.id, lesson: lessonId, course: courseId, watch_percent: pct, watch_seconds: sec, last_position: sec, is_video_complete: isVideoComplete };
    try {
      if (progressId.current) {
        await pb.collection("lesson_progress").update(progressId.current, data);
      } else {
        const rec = await pb.collection("lesson_progress").create(data);
        progressId.current = rec.id;
      }
    } catch { /* offline — xAPI hook handles queuing */ }
  }, [user, lessonId, courseId]);

  useEffect(() => {
    saveTimer.current = setInterval(() => {
      if (latestPct.current > 0) saveProgress(latestPct.current, latestSec.current);
      xRecord("progressed", "lesson", lessonId!, { progress: latestPct.current, duration: Math.round((Date.now() - startTime.current) / 1000) });
    }, 30_000);
    return () => { if (saveTimer.current) clearInterval(saveTimer.current); };
  }, [saveProgress, lessonId]);

  const threshold = Number(lesson?.completion_threshold ?? 100);

  const handleVideoProgress = (pct: number, sec: number) => {
    latestPct.current = pct;
    latestSec.current = sec;
    setWatchPct(pct);
  };

  const handleVideoComplete = async () => {
    if (!lesson) return;
    await saveProgress(100, latestSec.current, true);
    xRecord("completed", "lesson", lessonId!, { completion: true, progress: 100, duration: Math.round((Date.now() - startTime.current) / 1000) });
    if (lesson.has_quiz && quiz) setPhase("quiz");
    else await markLessonDone(true, 0);
  };

  const markLessonDone = async (videoOk: boolean, score: number) => {
    if (!user || !lessonId || !courseId) return;
    const now = new Date().toISOString().replace("T", " ").slice(0, 23) + "Z";
    const data = { is_video_complete: videoOk, is_quiz_passed: score > 0 || !lesson?.has_quiz, quiz_score: score, is_completed: true, completed_at: now };
    if (progressId.current) await pb.collection("lesson_progress").update(progressId.current, data).catch(() => {});
    const isCourseComplete = await updateEnrollmentProgress();
    if (isCourseComplete) {
      navigate(`/courses/${courseId}/complete`, { replace: true });
    } else {
      setPhase("done");
    }
  };

  const updateEnrollmentProgress = async (): Promise<boolean> => {
    if (!user || !courseId) return false;
    try {
      const [all, done] = await Promise.all([
        pb.collection("lessons").getFullList({ filter: pb.filter("course = {:c} && is_published = true", { c: courseId }), requestKey: null }),
        pb.collection("lesson_progress").getFullList({ filter: pb.filter("user = {:u} && course = {:c} && is_completed = true", { u: user.id, c: courseId }), requestKey: null }),
      ]);
      const pct = all.length > 0 ? Math.round((done.length / all.length) * 100) : 0;
      const enr = await pb.collection("enrollments").getFirstListItem(pb.filter("user = {:u} && course = {:c}", { u: user.id, c: courseId }), { requestKey: null });
      await pb.collection("enrollments").update(enr.id, { progress_percent: pct, is_completed: pct === 100 });
      if (pct === 100) xRecord("completed", "course", courseId, { completion: true, success: true });
      return pct === 100;
    } catch { return false; /* offline */ }
  };

  const handleQuizPass = async (score: number) => {
    xRecord("passed", "quiz", lessonId!, { success: true, score, completion: true });
    await markLessonDone(true, score);
  };

  const handleQuizFail = (score: number) => {
    xRecord("failed", "quiz", lessonId!, { success: false, score, completion: false });
  };

  const goToNext = () => {
    const idx = allLessons.findIndex(l => l.id === lessonId);
    const next = allLessons[idx + 1];
    if (next) navigate(`/courses/${courseId}/lessons/${next.id}`, { replace: true });
    else navigate(`/courses/${courseId}`);
  };

  if (loading) return (
    <div className="h-[100dvh] bg-gray-950 flex items-center justify-center">
      <div className="animate-spin rounded-full h-8 w-8 border-2 border-amber-500 border-t-transparent" />
    </div>
  );

  if (!lesson) return <div className="h-[100dvh] bg-gray-950 flex items-center justify-center text-white">Lesson not found</div>;

  const currentIdx = allLessons.findIndex(l => l.id === lessonId);
  const totalLessons = allLessons.length;

  return (
    <div className="h-[100dvh] bg-gray-950 flex flex-col overflow-hidden">
      {/* Header */}
      <header className="flex items-center gap-3 px-4 py-3 shrink-0 z-10 border-b border-white/5">
        <button onClick={() => navigate(`/courses/${courseId}`)} className="p-1 -ml-1">
          <ChevronLeft size={22} className="text-white/70" />
        </button>
        <div className="flex-1 min-w-0">
          <p className="text-white font-semibold text-sm truncate">{getField(lesson, "title")}</p>
          <p className="text-white/40 text-[11px]">Lesson {currentIdx + 1} of {totalLessons}</p>
        </div>
        {!navigator.onLine && <WifiOff size={16} className="text-amber-400 shrink-0" />}
      </header>

      {/* Progress bar */}
      <div className="h-0.5 bg-white/10 shrink-0">
        <div className="h-full bg-gradient-to-r from-amber-400 to-emerald-400 transition-all duration-1000"
          style={{ width: `${phase === "done" ? 100 : watchPct}%` }} />
      </div>

      {/* Video */}
      <div className="shrink-0">
        <VideoPlayer
          videoUrl={String(lesson.video_url ?? "")}
          provider={String(lesson.video_provider ?? "")}
          threshold={threshold}
          startPosition={Number(progress?.last_position ?? 0)}
          onProgress={handleVideoProgress}
          onComplete={handleVideoComplete}
        />
      </div>

      {/* Content area */}
      <div className="flex-1 overflow-y-auto">
        {phase === "done" ? (
          <div className="p-6 text-center space-y-4">
            <div className="w-16 h-16 mx-auto rounded-full bg-emerald-500/20 flex items-center justify-center">
              <CheckCircle size={32} className="text-emerald-400" />
            </div>
            <p className="text-white font-bold text-lg">Lesson Complete!</p>
            <p className="text-white/50 text-sm">Great work — keep going!</p>
            <button onClick={goToNext}
              className="w-full max-w-xs mx-auto py-3 rounded-2xl bg-amber-500 text-white font-bold text-sm block">
              {currentIdx < totalLessons - 1 ? "Next Lesson →" : "Back to Course"}
            </button>
          </div>
        ) : phase === "quiz" && quiz ? (
          <div className="bg-white rounded-t-3xl min-h-full">
            <div className="p-4 border-b border-gray-100 flex items-center gap-2">
              <BookOpen size={16} className="text-amber-500" />
              <p className="font-bold text-gray-800 text-sm">Knowledge Check</p>
              <span className="text-[10px] text-amber-600 bg-amber-50 px-2 py-0.5 rounded-full font-bold ml-auto">Required to complete</span>
            </div>
            <QuizPlayer questions={quiz.questions} passingScore={quiz.passing_score} onPass={handleQuizPass} onFail={handleQuizFail} />
          </div>
        ) : (
          <div className="bg-white rounded-t-3xl min-h-full p-5 space-y-3">
            <h2 className="font-bold text-gray-800 text-base">{getField(lesson, "title")}</h2>
            {getField(lesson, "description") && (
              <p className="text-gray-600 text-sm leading-relaxed">{getField(lesson, "description")}</p>
            )}
            {lesson.has_quiz && phase === "watching" && (
              <div className="flex items-center gap-2 px-3 py-2 bg-amber-50 rounded-xl text-amber-700 text-xs font-medium">
                <BookOpen size={13} /> A quiz will appear after you finish watching
              </div>
            )}
            {!navigator.onLine && (
              <div className="flex items-center gap-2 px-3 py-2 bg-gray-100 rounded-xl text-gray-500 text-xs font-medium">
                <WifiOff size={13} /> Offline — progress is saved locally and will sync when you reconnect
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
