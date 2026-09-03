import { useState, type FormEvent } from "react";
import { Link, Navigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { useLang } from "../contexts/LanguageContext";
import type { Language } from "../i18n/translations";
import AppLogo from "../components/AppLogo";
import { Eye, EyeOff } from "lucide-react";

const LANGS: { code: Language; label: string }[] = [
  { code: "en", label: "English" },
  { code: "ms", label: "Bahasa" },
  { code: "zh", label: "中文" },
];

export default function Login() {
  const { user, login } = useAuth();
  const { lang, setLang, t } = useLang();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  if (user) return <Navigate to="/" replace />;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try { await login(email, password); }
    catch { setError(t("invalidCredentials")); }
    finally { setLoading(false); }
  };

  return (
    <div className="min-h-screen bg-cream bg-mesh flex items-center justify-center p-4">
      <div className="w-full max-w-sm fade-up">

        {/* Language chooser */}
        <div className="flex justify-center gap-2 mb-5">
          {LANGS.map(({ code, label }) => (
            <button
              key={code}
              type="button"
              onClick={() => setLang(code)}
              className={`px-4 py-1.5 rounded-full text-sm font-semibold border transition-all duration-200 ${
                lang === code
                  ? "bg-gradient-to-r from-violet-500 to-pink-400 text-white border-transparent shadow-sm scale-105"
                  : "bg-white/60 text-gray-500 border-gray-200/70 hover:border-violet-300 hover:text-violet-600"
              }`}>
              {label}
            </button>
          ))}
        </div>

        {/* Logo & branding */}
        <div className="text-center mb-8">
          <div className="flex justify-center mb-4">
            <AppLogo size={96} />
          </div>
          <h1 className="text-2xl font-bold bg-gradient-to-r from-violet-600 to-blue-500 bg-clip-text text-transparent leading-tight">
            {t("appName")}
          </h1>
          <p className="text-gray-400 mt-1 text-xs font-medium tracking-wide">
            {t("appNameAlt")}
          </p>
          <p className="text-gray-500 mt-1 text-sm">{t("tagline")}</p>
        </div>

        <form onSubmit={handleSubmit} className="glass-strong rounded-3xl p-6 space-y-4">
          <div>
            <label className="text-sm font-semibold text-gray-700 block mb-1">{t("email")}</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} required
              className="glass-input w-full px-4 py-2.5 rounded-2xl outline-none text-sm"
              placeholder={t("emailPlaceholder")} />
          </div>
          <div>
            <label className="text-sm font-semibold text-gray-700 block mb-1">{t("password")}</label>
            <div className="relative">
              <input type={showPassword ? "text" : "password"} value={password} onChange={e => setPassword(e.target.value)} required
                className="glass-input w-full px-4 py-2.5 pr-11 rounded-2xl outline-none text-sm"
                placeholder={t("passwordPlaceholder")} />
              <button type="button" onClick={() => setShowPassword(v => !v)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-violet-500 transition-colors">
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>
          {error && <p className="text-rose-500 text-sm text-center">{error}</p>}
          <button type="submit" disabled={loading}
            className="glass-btn w-full py-3 rounded-2xl text-white font-bold">
            {loading ? t("signingIn") : t("signIn")}
          </button>
          <div className="space-y-2 pt-1 text-center text-sm">
            <div>
              <Link to="/forgot-password" className="text-gray-400 hover:text-violet-600 transition-colors">
                {t("forgotPassword")}
              </Link>
            </div>
            <div className="text-gray-500">
              {t("noAccount")} <Link to="/register" className="text-violet-600 font-semibold">{t("signUp")}</Link>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
}
