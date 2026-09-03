import { useState, useRef, useEffect } from "react";
import { Link } from "react-router-dom";
import { useLang } from "../contexts/LanguageContext";
import AppLogo from "../components/AppLogo";
import { MessageCircle, ShieldCheck, KeyRound, RefreshCw, CheckCircle, Eye, EyeOff } from "lucide-react";

const MY_PHONE_REGEX = /^(\+?60)(1[0-9])[0-9]{7,8}$/;

type Step = "phone" | "otp" | "password" | "done";

export default function ForgotPassword() {
  const { t } = useLang();

  const [step, setStep]           = useState<Step>("phone");
  const [phone, setPhone]         = useState("+60");
  const [otpCode, setOtpCode]     = useState("");
  const [newPass, setNewPass]     = useState("");
  const [confirmPass, setConfPass] = useState("");
  const [showPass, setShowPass]   = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [error, setError]         = useState("");
  const [sending, setSending]     = useState(false);
  const [verifying, setVerifying] = useState(false);
  const [resetting, setResetting] = useState(false);
  const [cooldown, setCooldown]   = useState(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => () => { if (timerRef.current) clearInterval(timerRef.current); }, []);

  const cleanPhone = phone.replace(/[\s-]/g, "");
  const isValidPhone = MY_PHONE_REGEX.test(cleanPhone);

  const handlePhoneChange = (val: string) => {
    const d = val.replace(/[^\d+]/g, "");
    if (d.startsWith("60") && !d.startsWith("+60")) setPhone("+" + d);
    else if (d.startsWith("0")) setPhone("+6" + d);
    else setPhone(d);
    setError("");
  };

  const startCooldown = () => {
    setCooldown(60);
    timerRef.current = setInterval(() => {
      setCooldown(prev => { if (prev <= 1) { clearInterval(timerRef.current!); return 0; } return prev - 1; });
    }, 1000);
  };

  const sendOtp = async () => {
    if (!isValidPhone) { setError(t("invalidMYPhone")); return; }
    setSending(true); setError("");
    try {
      const res  = await fetch(`${import.meta.env.VITE_POCKETBASE_URL}/api/auth/request-password-reset-whatsapp`, {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ phone: cleanPhone }),
      });
      const data = await res.json();
      if (data.error === "whatsapp_not_configured") {
        setError("WhatsApp OTP is not yet configured. Please contact the administrator.");
      } else if (res.ok && data.ok) {
        setStep("otp");
        startCooldown();
      } else {
        setError(data.message || t("somethingWrong"));
      }
    } catch { setError(t("somethingWrong")); }
    finally { setSending(false); }
  };

  const verifyOtp = async () => {
    if (otpCode.length !== 6) { setError("Please enter the 6-digit code."); return; }
    setVerifying(true); setError("");
    // Optimistically move to password step — OTP verified on final submit
    setStep("password");
    setVerifying(false);
  };

  const resetPassword = async () => {
    if (newPass.length < 8) { setError(t("passwordTooShort")); return; }
    if (newPass !== confirmPass) { setError(t("passwordsNotMatch")); return; }
    setResetting(true); setError("");
    try {
      const res  = await fetch(`${import.meta.env.VITE_POCKETBASE_URL}/api/auth/confirm-password-reset-whatsapp`, {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ phone: cleanPhone, code: otpCode, password: newPass }),
      });
      const data = await res.json();
      if (res.ok && data.ok) {
        setStep("done");
      } else {
        // If OTP was wrong / expired, go back to OTP step
        if (data.error === "invalid_otp" || data.error === "expired") {
          setStep("otp");
          setOtpCode("");
        }
        setError(data.message || t("somethingWrong"));
      }
    } catch { setError(t("somethingWrong")); }
    finally { setResetting(false); }
  };

  if (step === "done") return (
    <div className="min-h-screen bg-cream bg-mesh flex items-center justify-center p-4">
      <div className="w-full max-w-sm fade-up text-center space-y-6">
        <div className="w-20 h-20 rounded-full bg-emerald-100 flex items-center justify-center mx-auto">
          <CheckCircle size={40} className="text-emerald-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-800">{t("resetPassword")}</h1>
          <p className="text-gray-500 mt-2 text-sm leading-relaxed">{t("passwordResetSuccess")}</p>
        </div>
        <Link to="/login" replace
          className="block glass-btn py-3 rounded-2xl text-white font-bold text-sm text-center">
          {t("backToSignIn")}
        </Link>
      </div>
    </div>
  );

  if (step === "password") return (
    <div className="min-h-screen bg-cream bg-mesh flex items-center justify-center p-4">
      <div className="w-full max-w-sm fade-up">
        <div className="text-center mb-6">
          <div className="w-16 h-16 rounded-full bg-violet-100 flex items-center justify-center mx-auto mb-3">
            <KeyRound size={28} className="text-violet-600" />
          </div>
          <h1 className="text-2xl font-bold text-gray-800">{t("resetPassword")}</h1>
          <p className="text-gray-500 mt-1 text-sm">{t("newPassword")}</p>
        </div>
        <div className="glass-strong rounded-3xl p-6 space-y-4">
          <div>
            <label className="text-sm font-semibold text-gray-700 block mb-1">{t("newPassword")}</label>
            <div className="relative">
              <input type={showPass ? "text" : "password"} value={newPass}
                onChange={e => { setNewPass(e.target.value); setError(""); }}
                className="glass-input w-full px-4 py-3 pr-11 rounded-2xl outline-none text-sm"
                placeholder={t("passwordMin")} autoFocus />
              <button type="button" onClick={() => setShowPass(v => !v)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-violet-500 transition-colors">
                {showPass ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>
          <div>
            <label className="text-sm font-semibold text-gray-700 block mb-1">{t("confirmNewPassword")}</label>
            <div className="relative">
              <input type={showConfirm ? "text" : "password"} value={confirmPass}
                onChange={e => { setConfPass(e.target.value); setError(""); }}
                className="glass-input w-full px-4 py-3 pr-11 rounded-2xl outline-none text-sm"
                placeholder={t("passwordMin")} />
              <button type="button" onClick={() => setShowConfirm(v => !v)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-violet-500 transition-colors">
                {showConfirm ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>
          {error && <p className="text-rose-500 text-xs text-center">{error}</p>}
          <button onClick={resetPassword} disabled={resetting || newPass.length < 8}
            className="glass-btn w-full py-3 rounded-2xl text-white font-bold flex items-center justify-center gap-2">
            {resetting ? t("saving") : <><KeyRound size={16} /> {t("resetPassword")}</>}
          </button>
          <button onClick={() => { setStep("otp"); setError(""); }}
            className="w-full text-center text-sm text-gray-400 hover:text-gray-600 transition-colors">
            ← Back
          </button>
        </div>
      </div>
    </div>
  );

  if (step === "otp") return (
    <div className="min-h-screen bg-cream bg-mesh flex items-center justify-center p-4">
      <div className="w-full max-w-sm fade-up">
        <div className="text-center mb-6">
          <div className="w-16 h-16 rounded-full bg-green-100 flex items-center justify-center mx-auto mb-3">
            <MessageCircle size={28} className="text-green-600" />
          </div>
          <h1 className="text-2xl font-bold text-gray-800">Enter OTP</h1>
          <p className="text-gray-500 mt-1 text-sm">
            We sent a 6-digit code to<br />
            <span className="font-semibold text-gray-700">{cleanPhone}</span>
          </p>
        </div>
        <div className="glass-strong rounded-3xl p-6 space-y-4">
          <div>
            <label className="text-sm font-semibold text-gray-700 block mb-1">Verification Code</label>
            <input type="text" inputMode="numeric" pattern="[0-9]*" maxLength={6}
              value={otpCode} onChange={e => { setOtpCode(e.target.value.replace(/\D/g, "")); setError(""); }}
              className="glass-input w-full px-4 py-3 rounded-2xl outline-none text-2xl tracking-[0.5em] font-bold text-center"
              placeholder="······" autoFocus />
          </div>
          {error && <p className="text-rose-500 text-xs text-center">{error}</p>}
          <button onClick={verifyOtp} disabled={verifying || otpCode.length !== 6}
            className="glass-btn w-full py-3 rounded-2xl text-white font-bold flex items-center justify-center gap-2">
            {verifying ? "Verifying..." : <><ShieldCheck size={16} /> Continue</>}
          </button>
          <div className="flex items-center justify-between text-sm">
            <button onClick={() => { setStep("phone"); setOtpCode(""); setError(""); }}
              className="text-gray-400 hover:text-gray-600">← Back</button>
            <button onClick={sendOtp} disabled={cooldown > 0 || sending}
              className="flex items-center gap-1 text-violet-600 disabled:text-gray-300 transition-colors">
              <RefreshCw size={13} className={sending ? "animate-spin" : ""} />
              {cooldown > 0 ? `Resend in ${cooldown}s` : sending ? "Sending..." : "Resend OTP"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  // Step: phone
  return (
    <div className="min-h-screen bg-cream bg-mesh flex items-center justify-center p-4">
      <div className="w-full max-w-sm fade-up">
        <div className="text-center mb-6">
          <div className="flex justify-center mb-3"><AppLogo size={64} /></div>
          <h1 className="text-2xl font-bold text-gray-800">{t("resetPassword")}</h1>
          <p className="text-gray-500 mt-1 text-sm">{t("enterPhoneForReset")}</p>
        </div>
        <div className="glass-strong rounded-3xl p-6 space-y-4">
          <div>
            <label className="text-sm font-semibold text-gray-700 block mb-1">{t("mobileNumber")}</label>
            <div className="flex items-center gap-2">
              <span className="text-xl shrink-0">🇲🇾</span>
              <input type="tel" value={phone} onChange={e => handlePhoneChange(e.target.value)}
                className="glass-input w-full px-4 py-2.5 rounded-2xl outline-none text-sm"
                placeholder="+60123456789" />
            </div>
            <p className="text-gray-400 text-xs mt-1.5">{t("myPhoneFormat")}</p>
          </div>
          {error && <p className="text-rose-500 text-xs text-center leading-relaxed">{error}</p>}
          <button onClick={sendOtp} disabled={sending || !isValidPhone}
            className="glass-btn w-full py-3 rounded-2xl text-white font-bold flex items-center justify-center gap-2">
            {sending ? "Sending..." : <><MessageCircle size={16} /> {t("sendResetCode")}</>}
          </button>
          <p className="text-center text-sm text-gray-500">
            {t("hasAccount")} <Link to="/login" className="text-violet-600 font-semibold">{t("signIn")}</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
