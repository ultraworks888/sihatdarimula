import { useState, useEffect, useRef } from "react";
import pb from "../../lib/pocketbase";
import { Plus, ChevronLeft, Trash2, Edit2, BookOpen, Layers, Play, ImagePlus, GripVertical } from "lucide-react";

type View = "courses" | "lessons" | "quiz";
interface Course { id: string; title_en: string; title_ms: string; title_zh: string; description_en: string; description_ms: string; description_zh: string; category: string; level: string; is_published: boolean; is_featured: boolean; has_modules: boolean; thumbnail?: string; }
interface Module { id: string; title_en: string; title_ms: string; title_zh: string; order: number; }
interface Lesson { id: string; title_en: string; title_ms: string; title_zh: string; description_en: string; description_ms: string; description_zh: string; video_url: string; video_provider: string; video_duration: number; completion_threshold: number; has_quiz: boolean; order: number; is_published: boolean; is_free_preview: boolean; module: string; }
interface QuizQ { question: string; options: string[]; correct: number; explanation: string; }

const EMPTY_COURSE: Omit<Course, "id"> = { title_en: "", title_ms: "", title_zh: "", description_en: "", description_ms: "", description_zh: "", category: "parenting", level: "beginner", is_published: false, is_featured: false, has_modules: false };
const EMPTY_LESSON: Omit<Lesson, "id"> = { title_en: "", title_ms: "", title_zh: "", description_en: "", description_ms: "", description_zh: "", video_url: "", video_provider: "youtube", video_duration: 0, completion_threshold: 100, has_quiz: false, order: 0, is_published: false, is_free_preview: false, module: "" };
const EMPTY_Q: QuizQ = { question: "", options: ["", "", "", ""], correct: 0, explanation: "" };

export default function AdminCourses() {
  const [view, setView] = useState<View>("courses");
  const [courses, setCourses] = useState<Course[]>([]);
  const [selectedCourse, setSelectedCourse] = useState<Course | null>(null);
  const [lessons, setLessons] = useState<Lesson[]>([]);
  const [modules, setModules] = useState<Module[]>([]);
  const [selectedLesson, setSelectedLesson] = useState<Lesson | null>(null);
  const [quizQuestions, setQuizQuestions] = useState<QuizQ[]>([]);
  const [quizPassingScore, setQuizPassingScore] = useState(70);
  const [quizId, setQuizId] = useState<string | null>(null);
  const [showCourseModal, setShowCourseModal] = useState(false);
  const [editCourse, setEditCourse] = useState<Partial<Course>>(EMPTY_COURSE);
  const [showLessonModal, setShowLessonModal] = useState(false);
  const [editLesson, setEditLesson] = useState<Partial<Lesson>>(EMPTY_LESSON);
  const [langTab, setLangTab] = useState<"en" | "ms" | "zh">("en");
  const [lessonLangTab, setLessonLangTab] = useState<"en" | "ms" | "zh">("en");
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState("");
  const [dragIdx, setDragIdx] = useState<number | null>(null);
  const [dropIdx, setDropIdx] = useState<number | null>(null);
  const [thumbnailFile, setThumbnailFile] = useState<File | null>(null);
  const [thumbnailPreview, setThumbnailPreview] = useState<string | null>(null);
  const thumbInputRef = useRef<HTMLInputElement>(null);

  const openCourseModal = (course?: Course) => {
    setEditCourse(course ? { ...course } : { ...EMPTY_COURSE });
    setThumbnailFile(null);
    setThumbnailPreview(
      course?.thumbnail
        ? pb.files.getURL(course as never, course.thumbnail, { thumb: "400x225" })
        : null
    );
    setShowCourseModal(true);
  };

  const loadCourses = async () => {
    const cs = await pb.collection("courses").getFullList({ sort: "-created", requestKey: null });
    setCourses(cs as unknown as Course[]);
  };

  const loadLessons = async (courseId: string) => {
    const [ls, ms] = await Promise.all([
      pb.collection("lessons").getFullList({ filter: pb.filter("course = {:c}", { c: courseId }), sort: "order,created", requestKey: null }),
      pb.collection("course_modules").getFullList({ filter: pb.filter("course = {:c}", { c: courseId }), sort: "order", requestKey: null }),
    ]);
    setLessons(ls as unknown as Lesson[]);
    setModules(ms as unknown as Module[]);
  };

  const loadQuiz = async (lessonId: string) => {
    try {
      const q = await pb.collection("lesson_quizzes").getFirstListItem(pb.filter("lesson = {:l}", { l: lessonId }), { requestKey: null });
      setQuizQuestions(q.questions as QuizQ[]);
      setQuizPassingScore((q.passing_score as number) ?? 70);
      setQuizId(q.id);
    } catch { setQuizQuestions([]); setQuizPassingScore(70); setQuizId(null); }
  };

  useEffect(() => { loadCourses(); }, []);

  const saveCourse = async () => {
    setSaving(true);
    try {
      if (thumbnailFile) {
        const fd = new FormData();
        const { id: _id, ...fields } = editCourse as Record<string, unknown>;
        Object.entries(fields).forEach(([k, v]) => {
          if (v !== undefined && v !== null) fd.append(k, String(v));
        });
        fd.append("thumbnail", thumbnailFile);
        if (editCourse.id) await pb.collection("courses").update(editCourse.id, fd);
        else await pb.collection("courses").create(fd);
      } else {
        if (editCourse.id) await pb.collection("courses").update(editCourse.id, editCourse);
        else await pb.collection("courses").create(editCourse);
      }
      await loadCourses();
      setShowCourseModal(false);
      setThumbnailFile(null);
      setThumbnailPreview(null);
    } finally { setSaving(false); }
  };

  const deleteCourse = async (id: string) => {
    if (!confirm("Delete this course and all its lessons?")) return;
    await pb.collection("courses").delete(id);
    await loadCourses();
  };

  const saveLesson = async () => {
    if (!selectedCourse) return;
    setSaving(true);
    try {
      const data = { ...editLesson, course: selectedCourse.id };
      if (editLesson.id) await pb.collection("lessons").update(editLesson.id, data);
      else await pb.collection("lessons").create(data);
      await loadLessons(selectedCourse.id);
      setShowLessonModal(false);
    } finally { setSaving(false); }
  };

  const deleteLesson = async (id: string) => {
    if (!confirm("Delete this lesson?")) return;
    await pb.collection("lessons").delete(id);
    if (selectedCourse) await loadLessons(selectedCourse.id);
  };

  const handleDrop = async (targetIdx: number) => {
    if (dragIdx === null || dragIdx === targetIdx) { setDragIdx(null); setDropIdx(null); return; }
    const reordered = [...lessons];
    const [moved] = reordered.splice(dragIdx, 1);
    reordered.splice(targetIdx, 0, moved);
    const updated = reordered.map((l, i) => ({ ...l, order: i + 1 }));
    setLessons(updated);
    setDragIdx(null); setDropIdx(null);
    await Promise.all(updated.map(l => pb.collection("lessons").update(l.id, { order: l.order })));
  };

  const saveQuiz = async () => {
    if (!selectedLesson) return;
    setSaving(true);
    try {
      const data = { lesson: selectedLesson.id, questions: quizQuestions, passing_score: quizPassingScore };
      if (quizId) await pb.collection("lesson_quizzes").update(quizId, data);
      else { const q = await pb.collection("lesson_quizzes").create(data); setQuizId(q.id); }
      await pb.collection("lessons").update(selectedLesson.id, { has_quiz: true });
      if (selectedCourse) await loadLessons(selectedCourse.id);
    } finally { setSaving(false); }
  };

  const addQuestion = () => setQuizQuestions(prev => [...prev, { ...EMPTY_Q, options: ["", "", "", ""] }]);
  const removeQuestion = (i: number) => setQuizQuestions(prev => prev.filter((_, idx) => idx !== i));

  const filtered = courses.filter(c => !search || c.title_en.toLowerCase().includes(search.toLowerCase()));

  /* ── QUIZ VIEW ── */
  if (view === "quiz" && selectedLesson) return (
    <div className="space-y-6 max-w-3xl">
      <button onClick={() => setView("lessons")} className="flex items-center gap-2 text-white/60 hover:text-white text-sm"><ChevronLeft size={16} /> Back to Lessons</button>
      <div>
        <h2 className="text-white font-bold text-xl">Quiz Editor</h2>
        <p className="text-white/40 text-sm">{selectedLesson.title_en}</p>
      </div>
      <div className="flex items-center gap-4">
        <label className="text-white/60 text-sm">Passing score:</label>
        <input type="number" value={quizPassingScore} onChange={e => setQuizPassingScore(Number(e.target.value))} min={0} max={100}
          className="w-20 px-3 py-1.5 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none" />
        <span className="text-white/40 text-sm">%</span>
      </div>
      {quizQuestions.map((q, qi) => (
        <div key={qi} className="bg-white/5 border border-white/10 rounded-2xl p-4 space-y-3">
          <div className="flex items-center justify-between">
            <p className="text-white/70 text-sm font-semibold">Question {qi + 1}</p>
            <button onClick={() => removeQuestion(qi)} className="text-rose-400 hover:text-rose-300"><Trash2 size={14} /></button>
          </div>
          <textarea value={q.question} onChange={e => setQuizQuestions(prev => prev.map((x, i) => i === qi ? { ...x, question: e.target.value } : x))}
            placeholder="Question text..." rows={2}
            className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none resize-none placeholder-white/20" />
          <div className="space-y-2">
            {q.options.map((opt, oi) => (
              <div key={oi} className="flex items-center gap-2">
                <input type="radio" name={`correct-${qi}`} checked={q.correct === oi} onChange={() => setQuizQuestions(prev => prev.map((x, i) => i === qi ? { ...x, correct: oi } : x))} className="accent-amber-500" />
                <input value={opt} onChange={e => setQuizQuestions(prev => prev.map((x, i) => i === qi ? { ...x, options: x.options.map((o, j) => j === oi ? e.target.value : o) } : x))}
                  placeholder={`Option ${String.fromCharCode(65 + oi)}`}
                  className="flex-1 px-3 py-1.5 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none placeholder-white/20" />
              </div>
            ))}
          </div>
          <input value={q.explanation} onChange={e => setQuizQuestions(prev => prev.map((x, i) => i === qi ? { ...x, explanation: e.target.value } : x))}
            placeholder="Explanation / hint (optional)"
            className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white/70 text-sm outline-none placeholder-white/20" />
        </div>
      ))}
      <div className="flex gap-3">
        <button onClick={addQuestion} className="flex items-center gap-2 px-4 py-2 bg-white/10 hover:bg-white/15 text-white rounded-xl text-sm transition-all"><Plus size={14} /> Add Question</button>
        <button onClick={saveQuiz} disabled={saving} className="px-6 py-2 bg-amber-500 hover:bg-amber-400 text-white font-semibold rounded-xl text-sm disabled:opacity-50 transition-all">
          {saving ? "Saving..." : "Save Quiz"}
        </button>
      </div>
    </div>
  );

  /* ── LESSONS VIEW ── */
  if (view === "lessons" && selectedCourse) return (
    <div className="space-y-6">
      <button onClick={() => { setView("courses"); setSelectedCourse(null); }} className="flex items-center gap-2 text-white/60 hover:text-white text-sm"><ChevronLeft size={16} /> Back to Courses</button>
      <div className="flex items-start justify-between">
        <div><h2 className="text-white font-bold text-xl">Lessons</h2><p className="text-white/40 text-sm">{selectedCourse.title_en}</p></div>
        <button onClick={() => { setEditLesson({ ...EMPTY_LESSON }); setShowLessonModal(true); }}
          className="flex items-center gap-2 px-4 py-2 bg-amber-500 hover:bg-amber-400 text-white font-semibold rounded-xl text-sm transition-all">
          <Plus size={14} /> New Lesson
        </button>
      </div>
      <div className="space-y-2">
        {lessons.length === 0 && <p className="text-white/30 text-sm text-center py-8">No lessons yet. Add your first one.</p>}
        {lessons.length > 1 && <p className="text-white/20 text-xs text-center pb-1">Drag to reorder</p>}
        {lessons.map((lesson, idx) => (
          <div key={lesson.id}
            draggable
            onDragStart={() => setDragIdx(idx)}
            onDragOver={e => { e.preventDefault(); setDropIdx(idx); }}
            onDragLeave={() => setDropIdx(null)}
            onDrop={() => handleDrop(idx)}
            onDragEnd={() => { setDragIdx(null); setDropIdx(null); }}
            className={`flex items-center gap-3 border rounded-2xl px-4 py-3 transition-all cursor-grab active:cursor-grabbing select-none ${
              dropIdx === idx && dragIdx !== idx
                ? "border-amber-400/60 bg-amber-500/10 scale-[1.01]"
                : dragIdx === idx
                ? "border-white/5 bg-white/3 opacity-40"
                : "bg-white/5 hover:bg-white/8 border-white/10"
            }`}>
            <GripVertical size={16} className="text-white/20 shrink-0" />
            <Play size={14} className="text-amber-400 shrink-0" />
            <div className="flex-1 min-w-0">
              <p className="text-white text-sm font-semibold truncate">{lesson.title_en}</p>
              <div className="flex items-center gap-2 mt-0.5">
                <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded ${lesson.is_published ? "bg-emerald-500/20 text-emerald-400" : "bg-white/10 text-white/30"}`}>
                  {lesson.is_published ? "Published" : "Draft"}
                </span>
                {lesson.has_quiz && <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-400">Quiz</span>}
                <span className="text-white/30 text-[10px]">Threshold: {lesson.completion_threshold ?? 100}%</span>
              </div>
            </div>
            <div className="flex items-center gap-1 shrink-0">
              <button onClick={() => { setSelectedLesson(lesson); loadQuiz(lesson.id); setView("quiz"); }}
                className="p-1.5 text-amber-400/70 hover:text-amber-300 hover:bg-amber-500/10 rounded-lg transition-all" title="Edit Quiz">
                <BookOpen size={15} />
              </button>
              <button onClick={() => { setEditLesson({ ...lesson }); setShowLessonModal(true); }}
                className="p-1.5 text-white/40 hover:text-white hover:bg-white/10 rounded-lg transition-all"><Edit2 size={15} /></button>
              <button onClick={() => deleteLesson(lesson.id)}
                className="p-1.5 text-rose-400/60 hover:text-rose-400 hover:bg-rose-500/10 rounded-lg transition-all"><Trash2 size={15} /></button>
            </div>
          </div>
        ))}
      </div>

      {/* Lesson Modal */}
      {showLessonModal && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-end lg:items-center justify-center p-4">
          <div className="bg-slate-900 border border-white/10 rounded-3xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <div className="p-5 border-b border-white/10 flex items-center justify-between">
              <h3 className="text-white font-bold">{editLesson.id ? "Edit Lesson" : "New Lesson"}</h3>
              <button onClick={() => setShowLessonModal(false)} className="text-white/40 hover:text-white text-lg">×</button>
            </div>
            <div className="p-5 space-y-4">
              <div className="flex gap-1 p-1 bg-white/5 rounded-xl">
                {(["en","ms","zh"] as const).map(l => (
                  <button key={l} onClick={() => setLessonLangTab(l)} className={`flex-1 py-1.5 rounded-lg text-xs font-bold transition-all ${lessonLangTab === l ? "bg-white/10 text-white" : "text-white/30"}`}>{l.toUpperCase()}</button>
                ))}
              </div>
              {(["en","ms","zh"] as const).map(l => lessonLangTab === l && (
                <div key={l} className="space-y-3">
                  <input value={String((editLesson as Record<string, unknown>)[`title_${l}`] ?? "")} onChange={e => setEditLesson(p => ({ ...p, [`title_${l}`]: e.target.value }))}
                    placeholder={`Title (${l.toUpperCase()})`}
                    className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none placeholder-white/20" />
                  <textarea value={String((editLesson as Record<string, unknown>)[`description_${l}`] ?? "")} onChange={e => setEditLesson(p => ({ ...p, [`description_${l}`]: e.target.value }))}
                    placeholder={`Description (${l.toUpperCase()})`} rows={3}
                    className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none resize-none placeholder-white/20" />
                </div>
              ))}
              <input value={editLesson.video_url ?? ""} onChange={e => setEditLesson(p => ({ ...p, video_url: e.target.value }))}
                placeholder="Video URL (YouTube, Bunny, Cloudflare Stream, or direct MP4)"
                className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none placeholder-white/20" />
              <div className="grid grid-cols-2 gap-3">
                <select value={editLesson.video_provider ?? "youtube"} onChange={e => setEditLesson(p => ({ ...p, video_provider: e.target.value }))}
                  className="px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none">
                  <option value="youtube">YouTube</option>
                  <option value="direct">Direct MP4 / URL</option>
                  <option value="bunny">Bunny.net Stream</option>
                  <option value="cloudflare_stream">Cloudflare Stream</option>
                </select>
                <div className="flex items-center gap-2">
                  <label className="text-white/50 text-xs whitespace-nowrap">Complete at:</label>
                  <input type="number" value={editLesson.completion_threshold ?? 100} onChange={e => setEditLesson(p => ({ ...p, completion_threshold: Number(e.target.value) }))}
                    min={1} max={100}
                    className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none" />
                  <span className="text-white/40 text-xs">%</span>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <input type="number" value={editLesson.order ?? 0} onChange={e => setEditLesson(p => ({ ...p, order: Number(e.target.value) }))}
                  placeholder="Order (1, 2, 3...)"
                  className="px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none placeholder-white/20" />
                {selectedCourse.has_modules && modules.length > 0 && (
                  <select value={editLesson.module ?? ""} onChange={e => setEditLesson(p => ({ ...p, module: e.target.value }))}
                    className="px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none">
                    <option value="">No module</option>
                    {modules.map(m => <option key={m.id} value={m.id}>{m.title_en}</option>)}
                  </select>
                )}
              </div>
              <div className="flex gap-4">
                {([["is_published","Published"],["is_free_preview","Free Preview"]] as [string, string][]).map(([field, label]) => (
                  <label key={field} className="flex items-center gap-2 text-white/60 text-sm cursor-pointer">
                    <input type="checkbox" checked={!!(editLesson as Record<string, unknown>)[field]} onChange={e => setEditLesson(p => ({ ...p, [field]: e.target.checked }))} className="accent-amber-500" />
                    {label}
                  </label>
                ))}
              </div>
              <button onClick={saveLesson} disabled={saving} className="w-full py-3 bg-amber-500 hover:bg-amber-400 text-white font-bold rounded-2xl text-sm disabled:opacity-50 transition-all">
                {saving ? "Saving..." : "Save Lesson"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );

  /* ── COURSES VIEW ── */
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div><h2 className="text-white font-bold text-xl">Courses</h2><p className="text-white/40 text-sm">{courses.length} total</p></div>
        <button onClick={() => { setEditCourse({ ...EMPTY_COURSE }); openCourseModal(); }}
          className="flex items-center gap-2 px-4 py-2 bg-amber-500 hover:bg-amber-400 text-white font-semibold rounded-xl text-sm transition-all">
          <Plus size={14} /> New Course
        </button>
      </div>
      <div className="relative">
        <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search courses..."
          className="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-2xl text-white text-sm outline-none placeholder-white/20" />
      </div>
      <div className="space-y-2">
        {filtered.map(course => (
          <div key={course.id} className="flex items-center gap-3 bg-white/5 hover:bg-white/8 border border-white/10 rounded-2xl px-4 py-3 transition-all">
            <div className="w-12 h-12 rounded-xl overflow-hidden shrink-0">
              {course.thumbnail ? (
                <img src={pb.files.getURL(course as never, course.thumbnail, { thumb: "60x60" })} alt="" className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full bg-amber-500/10 flex items-center justify-center">
                  <BookOpen size={18} className="text-amber-400" />
                </div>
              )}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-white font-semibold text-sm truncate">{course.title_en}</p>
              <div className="flex items-center gap-2 mt-0.5">
                <span className="text-white/30 text-[10px] capitalize">{course.category} · {course.level}</span>
                <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded ${course.is_published ? "bg-emerald-500/20 text-emerald-400" : "bg-white/10 text-white/30"}`}>
                  {course.is_published ? "Live" : "Draft"}
                </span>
                {course.has_modules && <span className="text-[10px] bg-violet-500/20 text-violet-400 px-1.5 py-0.5 rounded font-bold">Modules</span>}
              </div>
            </div>
            <div className="flex items-center gap-1 shrink-0">
              <button onClick={() => { setSelectedCourse(course); loadLessons(course.id); setView("lessons"); }}
                className="flex items-center gap-1 px-2.5 py-1.5 text-amber-400/70 hover:text-amber-300 hover:bg-amber-500/10 rounded-lg text-xs font-semibold transition-all">
                <Layers size={13} /> Lessons
              </button>
              <button onClick={() => openCourseModal(course)}
                className="p-1.5 text-white/40 hover:text-white hover:bg-white/10 rounded-lg transition-all"><Edit2 size={15} /></button>
              <button onClick={() => deleteCourse(course.id)}
                className="p-1.5 text-rose-400/60 hover:text-rose-400 hover:bg-rose-500/10 rounded-lg transition-all"><Trash2 size={15} /></button>
            </div>
          </div>
        ))}
        {filtered.length === 0 && <p className="text-white/30 text-sm text-center py-8">No courses found.</p>}
      </div>

      {/* Course Modal */}
      {showCourseModal && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-end lg:items-center justify-center p-4">
          <div className="bg-slate-900 border border-white/10 rounded-3xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <div className="p-5 border-b border-white/10 flex items-center justify-between">
              <h3 className="text-white font-bold">{editCourse.id ? "Edit Course" : "New Course"}</h3>
              <button onClick={() => setShowCourseModal(false)} className="text-white/40 hover:text-white text-lg">×</button>
            </div>
            <div className="p-5 space-y-4">
              {/* Thumbnail upload */}
              <div>
                <p className="text-white/40 text-xs mb-2 font-semibold uppercase tracking-wide">Course Thumbnail</p>
                <div
                  className="relative w-full h-36 rounded-2xl overflow-hidden bg-white/5 border border-white/10 flex items-center justify-center cursor-pointer group"
                  onClick={() => thumbInputRef.current?.click()}>
                  {thumbnailPreview ? (
                    <>
                      <img src={thumbnailPreview} alt="Thumbnail" className="w-full h-full object-cover" />
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-2">
                        <ImagePlus size={20} className="text-white" />
                        <span className="text-white text-sm font-semibold">Change image</span>
                      </div>
                    </>
                  ) : (
                    <div className="flex flex-col items-center gap-2 text-white/30 group-hover:text-white/60 transition-colors">
                      <ImagePlus size={28} />
                      <span className="text-xs font-medium">Click to upload thumbnail</span>
                      <span className="text-[10px]">JPG, PNG, WEBP — max 5 MB</span>
                    </div>
                  )}
                </div>
                <input
                  ref={thumbInputRef}
                  type="file"
                  accept="image/jpeg,image/png,image/webp,image/gif"
                  className="hidden"
                  onChange={e => {
                    const file = e.target.files?.[0];
                    if (!file) return;
                    setThumbnailFile(file);
                    setThumbnailPreview(URL.createObjectURL(file));
                    e.target.value = "";
                  }}
                />
                {thumbnailFile && (
                  <p className="text-emerald-400 text-[11px] mt-1.5 text-center">{thumbnailFile.name} — ready to upload</p>
                )}
              </div>

              <div className="flex gap-1 p-1 bg-white/5 rounded-xl">
                {(["en","ms","zh"] as const).map(l => (
                  <button key={l} onClick={() => setLangTab(l)} className={`flex-1 py-1.5 rounded-lg text-xs font-bold transition-all ${langTab === l ? "bg-white/10 text-white" : "text-white/30"}`}>{l.toUpperCase()}</button>
                ))}
              </div>
              {(["en","ms","zh"] as const).map(l => langTab === l && (
                <div key={l} className="space-y-3">
                  <input value={String((editCourse as Record<string, unknown>)[`title_${l}`] ?? "")} onChange={e => setEditCourse(p => ({ ...p, [`title_${l}`]: e.target.value }))}
                    placeholder={`Title (${l.toUpperCase()}) *`}
                    className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none placeholder-white/20" />
                  <textarea value={String((editCourse as Record<string, unknown>)[`description_${l}`] ?? "")} onChange={e => setEditCourse(p => ({ ...p, [`description_${l}`]: e.target.value }))}
                    placeholder={`Description (${l.toUpperCase()})`} rows={3}
                    className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none resize-none placeholder-white/20" />
                </div>
              ))}
              <div className="grid grid-cols-2 gap-3">
                <select value={editCourse.category ?? "parenting"} onChange={e => setEditCourse(p => ({ ...p, category: e.target.value }))}
                  className="px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none">
                  {["parenting","nutrition","development","wellbeing","breastfeeding","pregnancy"].map(v => <option key={v} value={v}>{v}</option>)}
                </select>
                <select value={editCourse.level ?? "beginner"} onChange={e => setEditCourse(p => ({ ...p, level: e.target.value }))}
                  className="px-3 py-2 bg-white/5 border border-white/10 rounded-xl text-white text-sm outline-none">
                  {["beginner","intermediate","advanced"].map(v => <option key={v} value={v}>{v}</option>)}
                </select>
              </div>
              <div className="flex gap-4 flex-wrap">
                {([["is_published","Published (visible to parents)"],["is_featured","Featured"],["has_modules","Has Modules"]] as [string, string][]).map(([field, label]) => (
                  <label key={field} className="flex items-center gap-2 text-white/60 text-sm cursor-pointer">
                    <input type="checkbox" checked={!!(editCourse as Record<string, unknown>)[field]} onChange={e => setEditCourse(p => ({ ...p, [field]: e.target.checked }))} className="accent-amber-500" />
                    {label}
                  </label>
                ))}
              </div>
              <button onClick={saveCourse} disabled={saving || !editCourse.title_en}
                className="w-full py-3 bg-amber-500 hover:bg-amber-400 text-white font-bold rounded-2xl text-sm disabled:opacity-50 transition-all">
                {saving ? "Saving..." : "Save Course"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
