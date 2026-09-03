import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { useLang } from "../contexts/LanguageContext";
import type { Language } from "../i18n/translations";
import pb from "../lib/pocketbase";
import AppLogo from "../components/AppLogo";

const langs: { code: Language; flag: string; name: string; native: string }[] = [
  { code: "en", flag: "🇬🇧", name: "English", native: "English" },
  { code: "ms", flag: "🇲🇾", name: "Bahasa Malaysia", native: "Bahasa Malaysia" },
  { code: "zh", flag: "🇨🇳", name: "Chinese", native: "中文" },
];

export default function LanguageSelect() {
  const { user } = useAuth();
  const { lang, setLang, t } = useLang();
  const navigate = useNavigate();
  const [selected, setSelected] = useState<Language>(lang);
  const [saving, setSaving] = useState(false);

  const handleContinue = async () => {
    setSaving(true);
    setLang(selected);
    if (user) {
      try { await pb.collection("users").update(user.id, { language: selected }); } catch {}
    }
    navigate("/enter-phone", { replace: true });
  };

  return (
    <div className="min-h-screen bg-cream bg-mesh flex items-center justify-center p-4">
      <div className="w-full max-w-sm fade-up">
        <div className="text-center mb-6">
          <div className="flex justify-center mb-3">
            <AppLogo size={72} />
          </div>
          <h1 className="text-2xl font-bold text-gray-800">{t("chooseLanguage")}</h1>
          <p className="text-gray-500 mt-1 text-sm">{t("selectLanguage")}</p>
        </div>
        <div className="glass-strong rounded-3xl p-3 space-y-2 mb-4">
          {langs.map(l => (
            <button key={l.code} onClick={() => setSelected(l.code)}
              className={`w-full flex items-center gap-4 p-4 rounded-2xl text-left transition-all duration-200 ${
                selected === l.code ? "glass-btn !bg-gradient-to-r !from-violet-500/90 !to-rose-400/90 text-white" : "glass hover:scale-[1.02]"
              }`}>
              <span className="text-2xl">{l.flag}</span>
              <div>
                <p className={`font-bold ${selected === l.code ? "text-white" : "text-gray-800"}`}>{l.native}</p>
                <p className={`text-xs ${selected === l.code ? "text-white/70" : "text-gray-500"}`}>{l.name}</p>
              </div>
              {selected === l.code && <span className="ml-auto font-bold">✓</span>}
            </button>
          ))}
        </div>
        <button onClick={handleContinue} disabled={saving}
          className="glass-btn w-full py-3 rounded-2xl text-white font-bold">
          {t("continue")}
        </button>
      </div>
    </div>
  );
}
