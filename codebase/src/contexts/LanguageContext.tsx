import { createContext, useContext, useState, useCallback, type ReactNode } from "react";
import { translations, type Language, type TranslationKey } from "../i18n/translations";

interface LanguageContextType {
  lang: Language;
  setLang: (lang: Language) => void;
  t: (key: TranslationKey) => string;
}

const LanguageContext = createContext<LanguageContextType | null>(null);
const LANG_KEY = "sdm_lang_v2"; // bumped key — clears any old "en" default

export function useLang() {
  const ctx = useContext(LanguageContext);
  if (!ctx) throw new Error("useLang must be used within LanguageProvider");
  return ctx;
}

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Language>(() => {
    const s = localStorage.getItem(LANG_KEY);
    if (s === "en" || s === "ms" || s === "zh") return s;
    return "ms";
  });

  const setLang = useCallback((l: Language) => {
    setLangState(l);
    localStorage.setItem(LANG_KEY, l);
  }, []);

  const t = useCallback((key: TranslationKey): string => {
    return translations[lang][key] ?? translations.en[key] ?? key;
  }, [lang]);

  return (
    <LanguageContext.Provider value={{ lang, setLang, t }}>
      {children}
    </LanguageContext.Provider>
  );
}
