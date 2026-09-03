import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import pb from "../lib/pocketbase";
import { useAuth } from "../contexts/AuthContext";
import { useLang } from "../contexts/LanguageContext";
import ArticleReader from "../components/ArticleReader";
import CourseCard from "../components/lms/CourseCard";
import { BookOpen } from "lucide-react";

const categoryColors: Record<string, string> = {
  growth: "text-blue-600 bg-blue-500/10", nutrition: "text-orange-600 bg-orange-500/10",
  activity: "text-emerald-600 bg-emerald-500/10", wellbeing: "text-violet-600 bg-violet-500/10",
  immunisation: "text-rose-600 bg-rose-500/10", pregnancy: "text-pink-600 bg-pink-500/10",
  general: "text-gray-600 bg-gray-500/10",
};
const categoryEmoji: Record<string, string> = {
  growth: "📏", nutrition: "🥛", activity: "🤸", wellbeing: "💜",
  immunisation: "💉", pregnancy: "🤱", general: "📖",
};

type Tab = "articles" | "courses";

export default function Content() {
  const { user } = useAuth();
  const { t, lang } = useLang();
  const navigate = useNavigate();
  const [tab, setTab] = useState<Tab>("articles");

  // Articles state
  const [articles, setArticles] = useState<Record<string, unknown>[]>([]);
  const [bookmarkIds, setBookmarkIds] = useState<Set<string>>(new Set());
  const [bookmarkMap, setBookmarkMap] = useState<Record<string, string>>({});
  const [category, setCategory] = useState("all");
  const [search, setSearch] = useState("");
  const [reading, setReading] = useState<Record<string, unknown> | null>(null);
  const [articlesLoading, setArticlesLoading] = useState(true);

  // Courses state
  const [courses, setCourses] = useState<Record<string, unknown>[]>([]);
  const [enrollments, setEnrollments] = useState<Record<string, unknown>[]>([]);
  const [lessonCounts, setLessonCounts] = useState<Record<string, number>>({});
  const [coursesLoading, setCoursesLoading] = useState(true);

  useEffect(() => {
    (async () => {
      const [arts, bks] = await Promise.all([
        pb.collection("articles").getFullList({ sort: "-created", requestKey: null }),
        user ? pb.collection("bookmarks").getFullList({ filter: pb.filter("user = {:u}", { u: user.id }), requestKey: null }) : Promise.resolve([]),
      ]);
      setArticles(arts);
      const ids = new Set(bks.map(b => String(b.article)));
      setBookmarkIds(ids);
      const map: Record<string, string> = {};
      bks.forEach(b => { map[String(b.article)] = String(b.id); });
      setBookmarkMap(map);
      setArticlesLoading(false);
    })();
  }, [user]);

  useEffect(() => {
    if (tab !== "courses") return;
    (async () => {
      setCoursesLoading(true);
      const [cs, enrs] = await Promise.all([
        pb.collection("courses").getFullList({ sort: "-is_featured,-created", requestKey: null }),
        user ? pb.collection("enrollments").getFullList({ filter: pb.filter("user = {:u}", { u: user.id }), requestKey: null }) : Promise.resolve([]),
      ]);
      setCourses(cs);
      setEnrollments(enrs as unknown as Record<string, unknown>[]);
      const counts: Record<string, number> = {};
      for (const c of cs) {
        try {
          const ls = await pb.collection("lessons").getList(1, 1, { filter: pb.filter("course = {:c} && is_published = true", { c: c.id }), skipTotal: false, requestKey: null });
          counts[String(c.id)] = ls.totalItems;
        } catch { counts[String(c.id)] = 0; }
      }
      setLessonCounts(counts);
      setCoursesLoading(false);
    })();
  }, [tab, user]);

  const getField = (article: Record<string, unknown>, field: string) => {
    if (lang !== "en") { const loc = article[`${field}_${lang}`]; if (loc && String(loc).trim()) return String(loc); }
    return String(article[field] ?? "");
  };

  const toggleBookmark = async (articleId: string) => {
    if (!user) return;
    if (bookmarkIds.has(articleId)) {
      const bkId = bookmarkMap[articleId];
      if (bkId) await pb.collection("bookmarks").delete(bkId);
      setBookmarkIds(prev => { const s = new Set(prev); s.delete(articleId); return s; });
      setBookmarkMap(prev => { const m = { ...prev }; delete m[articleId]; return m; });
    } else {
      const bk = await pb.collection("bookmarks").create({ user: user.id, article: articleId });
      setBookmarkIds(prev => new Set(prev).add(articleId));
      setBookmarkMap(prev => ({ ...prev, [articleId]: bk.id }));
    }
  };

  const catKeys = ["all", "growth", "nutrition", "activity", "wellbeing", "immunisation", "pregnancy"] as const;
  const catLabels: Record<string, string> = {
    all: t("all"), growth: t("growth"), nutrition: t("nutrition"), activity: t("activity"),
    wellbeing: t("wellbeing"), immunisation: t("immunisation"), pregnancy: t("pregnancy"),
  };

  const filtered = articles.filter(a => {
    if (category === "saved") return bookmarkIds.has(String(a.id));
    if (category !== "all" && a.category !== category) return false;
    if (search) { const q = search.toLowerCase(); return getField(a, "title").toLowerCase().includes(q) || getField(a, "summary").toLowerCase().includes(q); }
    return true;
  });

  const getEnrollment = (courseId: string) => enrollments.find(e => String(e.course) === courseId);

  return (
    <>
      <div className="p-4 space-y-4 fade-up">
        {/* Tabs */}
        <div className="flex gap-2">
          {(["articles", "courses"] as Tab[]).map(tabId => (
            <button key={tabId} onClick={() => setTab(tabId)}
              className="flex-1 py-2.5 rounded-2xl text-sm font-bold transition-all"
              style={tab === tabId
                ? { background: "linear-gradient(135deg,#7c3aed,#ec4899)", color: "#fff", boxShadow: "0 4px 14px rgba(124,58,237,0.35)" }
                : { background: "rgba(124,58,237,0.08)", color: "#7c3aed" }
              }>
              {tabId === "articles" ? t("articlesTab") : t("coursesTab")}
            </button>
          ))}
        </div>

        {tab === "articles" ? (
          <>
            <div className="relative">
              <span className="absolute left-3 top-2.5 text-gray-400 text-sm">🔍</span>
              <input type="text" value={search} onChange={e => setSearch(e.target.value)}
                placeholder={t("searchArticles")}
                className="glass-input w-full px-4 py-2.5 pl-9 rounded-2xl text-sm outline-none" />
            </div>
            <div className="flex gap-1.5 overflow-x-auto pb-1 -mx-1 px-1 no-scrollbar">
              {[...catKeys, "saved" as const].map(cat => (
                <button key={cat} onClick={() => setCategory(cat)}
                  className={`px-3 py-1.5 rounded-2xl text-xs font-semibold whitespace-nowrap transition-all ${
                    category === cat ? "glass-btn text-white" : "glass text-gray-500 hover:text-gray-700"
                  }`}>
                  {cat === "saved" ? `🔖 ${t("saved")}` : catLabels[cat] || cat}
                </button>
              ))}
            </div>
            {articlesLoading ? (
              <div className="flex justify-center py-12"><div className="animate-spin rounded-full h-6 w-6 border-2 border-violet-500 border-t-transparent" /></div>
            ) : (
              <div className="space-y-3">
                {filtered.length === 0 ? (
                  <div className="text-center py-16"><p className="text-4xl mb-3">📭</p><p className="text-gray-400 text-sm">{t("noArticles")}</p></div>
                ) : filtered.map(article => {
                  const id = String(article.id);
                  const cat = String(article.category ?? "general");
                  const colors = categoryColors[cat] ?? categoryColors.general;
                  const emoji = categoryEmoji[cat] ?? "📖";
                  const hasVideo = !!String(article.youtube_url ?? "").trim();
                  return (
                    <button key={id} onClick={() => setReading(article)}
                      className="glass rounded-3xl overflow-hidden w-full text-left group active:scale-[0.99] transition-transform">
                      <div className="p-4">
                        <div className="flex items-start gap-3">
                          <div className={`w-11 h-11 rounded-2xl flex items-center justify-center text-xl shrink-0 ${colors.replace("text-", "bg-").split(" ")[0].replace("bg-", "bg-").replace("/10", "/15")}`}>{emoji}</div>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-1.5 mb-1 flex-wrap">
                              <span className={`text-[10px] font-bold uppercase px-2 py-0.5 rounded-full ${colors}`}>{catLabels[cat] ?? cat}</span>
                              {hasVideo && <span className="text-[10px] font-semibold text-rose-500 bg-rose-500/10 px-2 py-0.5 rounded-full">▶ Video</span>}
                            </div>
                            <h3 className="font-bold text-gray-800 leading-snug text-[15px] group-hover:text-violet-700 transition-colors">{getField(article, "title")}</h3>
                            <p className="text-gray-500 text-[13px] mt-1 line-clamp-2 leading-relaxed">{getField(article, "summary")}</p>
                          </div>
                          <button onClick={e => { e.stopPropagation(); toggleBookmark(id); }} className="text-xl shrink-0 active:scale-90 transition-transform pt-0.5">
                            {bookmarkIds.has(id) ? "🔖" : "📄"}
                          </button>
                        </div>
                        <div className="flex items-center justify-between mt-3 pt-3 border-t border-white/40">
                          <span className="text-xs text-gray-400">{String(article.reading_time || `3 ${t("minRead")}`)}</span>
                          <span className="text-xs font-semibold text-violet-600 flex items-center gap-1">{t("readMore")} <span className="text-[10px]">→</span></span>
                        </div>
                      </div>
                    </button>
                  );
                })}
              </div>
            )}
          </>
        ) : (
          <>
            {coursesLoading ? (
              <div className="flex justify-center py-12"><div className="animate-spin rounded-full h-6 w-6 border-2 border-amber-500 border-t-transparent" /></div>
            ) : courses.length === 0 ? (
              <div className="text-center py-16 space-y-3">
                <div className="w-16 h-16 mx-auto rounded-2xl bg-amber-50 flex items-center justify-center">
                  <BookOpen size={32} className="text-amber-300" />
                </div>
                <p className="text-gray-400 text-sm">No courses published yet.</p>
                <p className="text-gray-300 text-xs">Check back soon — courses are coming!</p>
              </div>
            ) : (
              <div className="space-y-4">
                {courses.map(course => {
                  const enr = getEnrollment(String(course.id));
                  return (
                    <CourseCard key={String(course.id)} course={course}
                      progress={enr ? Number(enr.progress_percent ?? 0) : 0}
                      lessonCount={lessonCounts[String(course.id)] ?? 0}
                      lang={lang}
                      onClick={() => navigate(`/courses/${course.id}`)} />
                  );
                })}
              </div>
            )}
          </>
        )}
      </div>

      {reading && (
        <ArticleReader article={reading} isBookmarked={bookmarkIds.has(String(reading.id))}
          onToggleBookmark={() => toggleBookmark(String(reading.id))} onClose={() => setReading(null)} />
      )}
    </>
  );
}
