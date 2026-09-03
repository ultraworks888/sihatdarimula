import { useEffect, useRef, useState } from "react";
import { useLang } from "../contexts/LanguageContext";

const categoryColors: Record<string, { pill: string; bar: string }> = {
  growth:       { pill: "text-blue-600 bg-blue-500/12",    bar: "#3b82f6" },
  nutrition:    { pill: "text-orange-600 bg-orange-500/12", bar: "#f97316" },
  activity:     { pill: "text-emerald-600 bg-emerald-500/12", bar: "#10b981" },
  wellbeing:    { pill: "text-violet-600 bg-violet-500/12", bar: "#8b5cf6" },
  immunisation: { pill: "text-rose-600 bg-rose-500/12",    bar: "#f43f5e" },
  pregnancy:    { pill: "text-pink-600 bg-pink-500/12",    bar: "#ec4899" },
  general:      { pill: "text-gray-600 bg-gray-500/10",    bar: "#6b7280" },
};

function extractYoutubeId(url: string): string | null {
  if (!url) return null;
  const patterns = [
    /(?:youtube\.com\/watch\?v=)([^&\s]+)/,
    /(?:youtu\.be\/)([^?\s]+)/,
    /(?:youtube\.com\/embed\/)([^?\s]+)/,
  ];
  for (const p of patterns) {
    const m = url.match(p);
    if (m) return m[1];
  }
  return null;
}

interface Props {
  article: Record<string, unknown>;
  isBookmarked: boolean;
  onToggleBookmark: () => void;
  onClose: () => void;
}

export default function ArticleReader({ article, isBookmarked, onToggleBookmark, onClose }: Props) {
  const { lang, t } = useLang();
  const scrollRef = useRef<HTMLDivElement>(null);
  const [progress, setProgress] = useState(0);
  const [visible, setVisible] = useState(false);
  const [closing, setClosing] = useState(false);

  // Slide-in on mount
  useEffect(() => {
    requestAnimationFrame(() => setVisible(true));
    // Lock body scroll
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = ""; };
  }, []);

  const handleClose = () => {
    setClosing(true);
    setTimeout(onClose, 320);
  };

  // Close on back-swipe / Escape
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") handleClose(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const onScroll = () => {
    const el = scrollRef.current;
    if (!el) return;
    const { scrollTop, scrollHeight, clientHeight } = el;
    const max = scrollHeight - clientHeight;
    setProgress(max > 0 ? Math.min(100, (scrollTop / max) * 100) : 0);
  };

  const getField = (field: string) => {
    if (lang !== "en") {
      const loc = article[`${field}_${lang}`];
      if (loc && String(loc).trim()) return String(loc);
    }
    return String(article[field] ?? "");
  };

  const title    = getField("title");
  const summary  = getField("summary");
  const content  = getField("content");
  const category = String(article.category ?? "general");
  const readTime = String(article.reading_time ?? "");
  const youtubeId = extractYoutubeId(String(article.youtube_url ?? ""));
  const colors = categoryColors[category] ?? categoryColors.general;

  const catLabels: Record<string, string> = {
    growth: t("growth"), nutrition: t("nutrition"), activity: t("activity"),
    wellbeing: t("wellbeing"), immunisation: t("immunisation"),
    pregnancy: t("pregnancy"), general: t("general") ?? "General",
  };

  const translateY = closing ? "100%" : visible ? "0%" : "100%";

  return (
    <div
      className="fixed inset-0 z-50 flex flex-col"
      style={{
        background: "rgba(0,0,0,0.35)",
        backdropFilter: "blur(6px)",
        transition: "opacity 0.32s ease",
        opacity: visible && !closing ? 1 : 0,
      }}>
      {/* Sheet */}
      <div
        className="absolute inset-x-0 bottom-0 flex flex-col rounded-t-3xl overflow-hidden shadow-2xl"
        style={{
          top: "4vh",
          background: "rgba(253,248,255,0.97)",
          backdropFilter: "blur(40px)",
          transform: `translateY(${translateY})`,
          transition: "transform 0.35s cubic-bezier(0.32,0.72,0,1)",
        }}>

        {/* ── Progress bar ── */}
        <div className="absolute top-0 inset-x-0 h-[3px] z-10 bg-black/5">
          <div
            className="h-full transition-all duration-150 ease-out"
            style={{ width: `${progress}%`, background: colors.bar }} />
        </div>

        {/* ── Header ── */}
        <div
          className="shrink-0 flex items-center justify-between px-4 pt-4 pb-3 border-b border-black/5 z-10"
          style={{ background: "rgba(253,238,246,0.9)", backdropFilter: "blur(32px)" }}>
          <button
            onClick={handleClose}
            className="w-9 h-9 flex items-center justify-center rounded-full bg-black/5 hover:bg-black/10 transition-colors text-gray-600">
            ←
          </button>

          <div className="flex-1 flex justify-center">
            <span className={`text-[11px] font-bold uppercase px-3 py-1 rounded-full ${colors.pill}`}>
              {catLabels[category] ?? category}
            </span>
          </div>

          <button
            onClick={onToggleBookmark}
            className="w-9 h-9 flex items-center justify-center rounded-full bg-black/5 hover:bg-black/10 transition-colors text-xl active:scale-90">
            {isBookmarked ? "🔖" : "📄"}
          </button>
        </div>

        {/* ── Drag handle ── */}
        <div className="absolute top-3 left-1/2 -translate-x-1/2 w-10 h-1 rounded-full bg-gray-300/60" />

        {/* ── Scrollable content ── */}
        <div
          ref={scrollRef}
          onScroll={onScroll}
          className="flex-1 overflow-y-auto overscroll-contain">

          {/* Hero */}
          <div className="px-5 pt-6 pb-4">
            <div className="flex items-center gap-2 text-xs text-gray-400 mb-3">
              {readTime && <span>⏱ {readTime}</span>}
            </div>
            <h1 className="text-2xl font-extrabold text-gray-800 leading-tight tracking-tight">{title}</h1>
            {summary && (
              <p className="mt-3 text-gray-500 text-[15px] leading-relaxed border-l-[3px] pl-3"
                style={{ borderColor: colors.bar }}>
                {summary}
              </p>
            )}
          </div>

          {/* YouTube embed */}
          {youtubeId && (
            <div className="px-5 pb-5">
              <div className="relative rounded-2xl overflow-hidden shadow-md bg-black"
                style={{ paddingBottom: "56.25%" }}>
                <iframe
                  src={`https://www.youtube-nocookie.com/embed/${youtubeId}?rel=0&modestbranding=1`}
                  title="Video"
                  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                  allowFullScreen
                  className="absolute inset-0 w-full h-full border-0" />
              </div>
            </div>
          )}

          {/* Divider */}
          <div className="mx-5 mb-5 h-px bg-gradient-to-r from-transparent via-gray-200 to-transparent" />

          {/* Article body */}
          {content && (
            <div
              className="px-5 pb-16 text-[15px] text-gray-600 leading-[1.75] article-body"
              dangerouslySetInnerHTML={{ __html: content }} />
          )}
        </div>
      </div>
    </div>
  );
}
