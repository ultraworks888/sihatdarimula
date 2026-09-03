import { useEffect, useState, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { Trophy, Star, Sparkles } from "lucide-react";
import confetti from "canvas-confetti";
import pb from "../lib/pocketbase";
import { useLang } from "../contexts/LanguageContext";

export default function CourseComplete() {
  const { courseId } = useParams<{ courseId: string }>();
  const navigate = useNavigate();
  const { t, lang } = useLang();
  const [course, setCourse] = useState<Record<string, unknown> | null>(null);
  const [show, setShow] = useState(false);
  const fired = useRef(false);

  const getTitle = () => {
    if (!course) return "";
    if (lang !== "en") {
      const loc = course[`title_${lang}`];
      if (loc && String(loc).trim()) return String(loc);
    }
    return String(course["title_en"] ?? course["title"] ?? "");
  };

  useEffect(() => {
    if (!courseId) return;
    pb.collection("courses").getOne(courseId, { requestKey: null })
      .then(c => {
        setCourse(c as unknown as Record<string, unknown>);
        setTimeout(() => setShow(true), 100);
      })
      .catch(() => navigate("/content"));
  }, [courseId]);

  useEffect(() => {
    if (!course || fired.current) return;
    fired.current = true;

    // Initial big burst
    confetti({
      particleCount: 120,
      spread: 100,
      origin: { y: 0.5 },
      colors: ["#a855f7", "#ec4899", "#f59e0b", "#10b981", "#3b82f6", "#f97316"],
      scalar: 1.2,
    });

    // Sustained shower from both sides
    const end = Date.now() + 3200;
    const rain = () => {
      confetti({
        particleCount: 6,
        angle: 60,
        spread: 70,
        origin: { x: 0, y: 0.6 },
        colors: ["#a855f7", "#ec4899", "#f59e0b", "#10b981"],
      });
      confetti({
        particleCount: 6,
        angle: 120,
        spread: 70,
        origin: { x: 1, y: 0.6 },
        colors: ["#3b82f6", "#f97316", "#a855f7", "#ec4899"],
      });
      if (Date.now() < end) requestAnimationFrame(rain);
    };
    setTimeout(rain, 300);
  }, [course]);

  return (
    <div className="h-[100dvh] flex flex-col items-center justify-center overflow-hidden relative"
      style={{ background: "linear-gradient(160deg, #1e1b4b 0%, #4c1d95 40%, #7c3aed 75%, #db2777 100%)" }}>

      {/* Decorative blobs */}
      <div className="absolute top-0 left-0 w-72 h-72 rounded-full opacity-20 blur-3xl"
        style={{ background: "radial-gradient(circle, #f59e0b, transparent)" }} />
      <div className="absolute bottom-0 right-0 w-96 h-96 rounded-full opacity-20 blur-3xl"
        style={{ background: "radial-gradient(circle, #ec4899, transparent)" }} />

      {/* Content */}
      <div className={`relative z-10 flex flex-col items-center text-center px-8 transition-all duration-700 ${show ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"}`}>

        {/* Trophy icon with glow ring */}
        <div className="relative mb-8">
          <div className="absolute inset-0 rounded-full blur-xl opacity-60"
            style={{ background: "radial-gradient(circle, #f59e0b, #ec4899)" }} />
          <div className="relative w-28 h-28 rounded-full flex items-center justify-center border-4 border-white/20"
            style={{ background: "linear-gradient(135deg, #f59e0b, #ec4899)" }}>
            <Trophy size={52} className="text-white drop-shadow-lg" />
          </div>
          {/* Orbiting stars */}
          <Star size={18} className="text-yellow-300 absolute -top-2 -right-2 fill-yellow-300" />
          <Star size={12} className="text-pink-300 absolute -bottom-1 -left-3 fill-pink-300" />
          <Sparkles size={16} className="text-violet-200 absolute top-2 -left-4 " />
        </div>

        {/* Congratulations text */}
        <h1 className="text-white font-black text-4xl leading-none tracking-tight mb-3 drop-shadow-lg">
          {t("congratulations")}
        </h1>

        <p className="text-white/70 text-base font-medium mb-2">
          {t("courseCompleted")}
        </p>

        {course && (
          <p className="text-white font-bold text-xl leading-snug mb-10 max-w-xs">
            "{getTitle()}"
          </p>
        )}

        {/* Divider */}
        <div className="flex items-center gap-3 mb-10">
          <div className="w-12 h-px bg-white/30" />
          <Star size={12} className="text-white/50 fill-white/50" />
          <div className="w-12 h-px bg-white/30" />
        </div>

        {/* CTA */}
        <button
          onClick={() => navigate("/content")}
          className="px-10 py-4 bg-white text-violet-700 font-black text-base rounded-3xl shadow-2xl
            hover:scale-105 active:scale-95 transition-transform duration-150">
          {t("keepLearning")}
        </button>
      </div>
    </div>
  );
}
