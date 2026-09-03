import { useState, useEffect } from "react";
import AppLogo from "./AppLogo";

const DISPLAY_MS = 2600;

const taglines = [
  "Teman penjagaan anda sejak hari pertama",
  "Your parenting companion from day one",
  "从第一天起陪伴您育儿",
];

export default function SplashScreen({ onDone }: { onDone: () => void }) {
  const [phase, setPhase] = useState<"in" | "out">("in");
  const [langIdx, setLangIdx] = useState(0);

  // Cycle through languages every 800ms
  useEffect(() => {
    const iv = setInterval(() => setLangIdx(i => (i + 1) % 3), 820);
    return () => clearInterval(iv);
  }, []);

  // After display time, fade out then call onDone
  useEffect(() => {
    const t1 = setTimeout(() => setPhase("out"), DISPLAY_MS);
    const t2 = setTimeout(() => onDone(), DISPLAY_MS + 500);
    return () => { clearTimeout(t1); clearTimeout(t2); };
  }, [onDone]);

  return (
    <div
      className={`fixed inset-0 z-[9999] flex flex-col items-center justify-center ${phase === "out" ? "splash-out" : ""}`}
      style={{
        background: "linear-gradient(145deg, #ede9fe 0%, #f5f3ff 30%, #fce7f3 60%, #f0f9ff 100%)",
      }}
    >
      {/* Ambient orbs */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-[-15%] left-[-10%] w-72 h-72 rounded-full opacity-30"
          style={{ background: "radial-gradient(circle, #a78bfa, transparent 70%)" }} />
        <div className="absolute bottom-[-10%] right-[-10%] w-80 h-80 rounded-full opacity-20"
          style={{ background: "radial-gradient(circle, #60a5fa, transparent 70%)" }} />
        <div className="absolute top-[40%] right-[5%] w-48 h-48 rounded-full opacity-15"
          style={{ background: "radial-gradient(circle, #f472b6, transparent 70%)" }} />
      </div>

      {/* Content */}
      <div className="relative z-10 flex flex-col items-center px-8 text-center">
        {/* Logo */}
        <div className="splash-logo mb-6">
          <AppLogo size={160} />
        </div>

        {/* Cycling language name */}
        <div className="h-9 overflow-hidden relative w-64">
          {["Sihat Dari Mula", "My Healthy Start", "健康从这里开始"].map((name, i) => (
            <span
              key={name}
              className="absolute inset-x-0 top-0 text-2xl font-bold bg-gradient-to-r from-violet-600 to-blue-500 bg-clip-text text-transparent transition-all duration-500"
              style={{
                opacity: langIdx === i ? 1 : 0,
                transform: langIdx === i ? "translateY(0)" : langIdx === (i - 1 + 3) % 3 ? "translateY(-100%)" : "translateY(100%)",
              }}
            >
              {name}
            </span>
          ))}
        </div>

        {/* Tagline */}
        <div className="h-6 overflow-hidden relative w-72 mt-2">
          {taglines.map((tag, i) => (
            <span
              key={i}
              className="absolute inset-x-0 top-0 text-xs text-gray-500 transition-all duration-500"
              style={{
                opacity: langIdx === i ? 1 : 0,
                transform: langIdx === i ? "translateY(0)" : langIdx === (i - 1 + 3) % 3 ? "translateY(-100%)" : "translateY(100%)",
              }}
            >
              {tag}
            </span>
          ))}
        </div>

        {/* Loading dots */}
        <div className="flex items-center gap-1.5 mt-10">
          {[0, 1, 2].map(i => (
            <span
              key={i}
              className="w-2 h-2 rounded-full bg-violet-400"
              style={{
                animation: `dot-pulse 1.2s ease-in-out ${i * 0.2}s infinite`,
              }}
            />
          ))}
        </div>
      </div>

      {/* Bottom branding */}
      <div className="absolute bottom-10 text-center splash-tagline">
        <p className="text-[11px] text-gray-400 tracking-wider uppercase font-medium">Malaysia · 马来西亚</p>
      </div>
    </div>
  );
}
