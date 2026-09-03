import { useState, type FormEvent } from "react";
import { Link, Navigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { useLang } from "../contexts/LanguageContext";
import type { Language } from "../i18n/translations";
import pb from "../lib/pocketbase";
import AppLogo from "../components/AppLogo";
import { MailCheck, RefreshCw, Eye, EyeOff } from "lucide-react";

type Step = "form" | "verify";

export default function Register() {
  const { user, register } = useAuth();
  const { lang, setLang, t } = useLang();
  const [step, setStep] = useState<Step>("form");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [resent, setResent] = useState(false);

  if (user && step === "form") return <Navigate to="/select-language" replace />;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError("");
    if (password.length < 8) { setError(t("passwordTooShort")); return; }
    setLoading(true);
    try {
      await register(email, password, name);
      // Request email verification (quietly — works once SMTP is configured)
      try {
        await pb.collection("users").requestVerification(email);
      } catch { /* SMTP may not be set up yet — that's OK */ }
      setStep("verify");
    } catch { setError(t("registrationFailed")); }
    finally { setLoading(false); }
  };

  const handleResend = async () => {
    setResending(true);
    try {
      await pb.collection("users").requestVerification(email);
      setResent(true);
      setTimeout(() => setResent(false), 4000);
    } catch { /* ignore */ }
    finally { setResending(false); }
  };

  if (step === "verify") return (
    <div className="min-h-screen bg-cream bg-mesh flex items-center justify-center p-4">
      <div className="w-full max-w-sm fade-up text-center space-y-6">
        <div className="flex justify-center">
          <div className="w-20 h-20 rounded-full bg-violet-100 flex items-center justify-center">
            <MailCheck size={36} className="text-violet-600" />
          </div>
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Check your email</h1>
          <p className="text-gray-500 mt-2 text-sm leading-relaxed">
            We sent a verification link to<br />
            <span className="font-semibold text-gray-700">{email}</span>
          </p>
          <p className="text-gray-400 text-xs mt-2">Click the link to verify your account. You can still use the app without verifying.</p>
        </div>
        <div className="glass-strong rounded-3xl p-5 space-y-3">
          <Link to="/select-language" replace
            className="block w-full py-3 rounded-2xl glass-btn text-white font-bold text-sm text-center">
            Continue to App
          </Link>
          <button onClick={handleResend} disabled={resending}
            className="flex items-center justify-center gap-2 w-full py-2.5 text-sm text-gray-500 hover:text-violet-600 transition-colors">
            <RefreshCw size={14} className={resending ? "animate-spin" : ""} />
            {resent ? "Email sent!" : resending ? "Sending..." : "Resend verification email"}
          </button>
        </div>
        <p className="text-gray-400 text-xs">
          Tip: Check your spam folder if you don't see the email.
        </p>
      </div>
    </div>
  );

  const LANGS: { code: Language; label: string }[] = [
    { code: "en", label: "English" },
    { code: "ms", label: "Bahasa" },
    { code: "zh", label: "中文" },
  ];

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

        <div className="text-center mb-6">
          <div className="flex justify-center mb-3"><AppLogo size={72} /></div>
          <h1 className="text-2xl font-bold text-gray-800">{t("createAccount")}</h1>
          <p className="text-gray-500 mt-1 text-sm">{t("startJourney")}</p>
        </div>
        <form onSubmit={handleSubmit} className="glass-strong rounded-3xl p-6 space-y-4">
          <div>
            <label className="text-sm font-semibold text-gray-700 block mb-1">{t("yourName")}</label>
            <input type="text" value={name} onChange={e => setName(e.target.value)} required
              className="glass-input w-full px-4 py-2.5 rounded-2xl outline-none text-sm"
              placeholder={t("namePlaceholder")} />
          </div>
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
                placeholder={t("passwordMin")} />
              <button type="button" onClick={() => setShowPassword(v => !v)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-violet-500 transition-colors">
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>
          {error && <p className="text-rose-500 text-sm text-center">{error}</p>}
          <button type="submit" disabled={loading} className="glass-btn w-full py-3 rounded-2xl text-white font-bold">
            {loading ? t("creatingAccount") : t("getStarted")}
          </button>
          <p className="text-center text-sm text-gray-500">
            {t("hasAccount")} <Link to="/login" className="text-violet-600 font-semibold">{t("signIn")}</Link>
          </p>
        </form>
      </div>
    </div>
  );
}
