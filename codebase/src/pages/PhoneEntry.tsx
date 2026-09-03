import { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { useLang } from "../contexts/LanguageContext";
import pb from "../lib/pocketbase";
import AppLogo from "../components/AppLogo";
import { MessageCircle, ShieldCheck, RefreshCw } from "lucide-react";

const MY_PHONE_REGEX = /^(\+?60)(1[0-9])[0-9]{7,8}$/;

function formatDisplay(val: string): string {
  return val.replace(/[^\d+]/g, "");
}

type Step = "phone" | "otp" | "saving";

export default function PhoneEntry() {
  const { user } = useAuth();
  const { t } = useLang();
  const navigate = useNavigate();
  const [phone, setPhone] = useState("+60");
  const [step, setStep] = useState<Step>("phone");
  const [otpCode, setOtpCode] = useState("");
  const [error, setError] = useState("");
  const [sendingOtp, setSendingOtp] = useState(false);
  const [verifying, setVerifying] = useState(false);
  const [canSkipOtp, setCanSkipOtp] = useState(false);
  const [cooldown, setCooldown] = useState(0);
  const [otpVerified, setOtpVerified] = useState(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const cleanPhone = phone.replace(/[\s-]/g, "");
  const isValidPhone = MY_PHONE_REGEX.test(cleanPhone);

  useEffect(() => {
    return () => { if (timerRef.current) clearInterval(timerRef.current); };
  }, []);

  const startCooldown = () => {
    setCooldown(60);
    timerRef.current = setInterval(() => {
      setCooldown(prev => { if (prev <= 1) { clearInterval(timerRef.current!); return 0; } return prev - 1; });
    }, 1000);
  };

  const handlePhoneChange = (val: string) => {
    const formatted = formatDisplay(val);
    if (!formatted.startsWith("+60") && !formatted.startsWith("60") && formatted.length > 0) {
      if (formatted.startsWith("+")) setPhone("+60");
      else if (formatted.startsWith("0")) setPhone("+6" + formatted);
      else setPhone("+60" + formatted);
    } else {
      setPhone(formatted.startsWith("60") && !formatted.startsWith("+60") ? "+" + formatted : formatted);
    }
    setError("");
  };

  const sendOtp = async () => {
    if (!isValidPhone) { setError(t("invalidMYPhone")); return; }
    setSendingOtp(true);
    setError("");
    try {
      const res = await fetch(`${import.meta.env.VITE_POCKETBASE_URL}/api/auth/request-whatsapp-otp`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ phone: cleanPhone }),
      });
      const data = await res.json();
      if (res.ok && data.ok) {
        setStep("otp");
        startCooldown();
      } else if (data.error === "whatsapp_not_configured") {
        setCanSkipOtp(true);
        setError("WhatsApp OTP is not yet configured. You can save your number without verification for now.");
      } else {
        // Log Meta's raw error detail to console for diagnosis
        if (data.detail) console.error("WhatsApp OTP error detail:", data.detail);
        setError(data.message || t("somethingWrong"));
      }
    } catch {
      setError(t("somethingWrong"));
    } finally { setSendingOtp(false); }
  };

  const verifyOtp = async () => {
    if (otpCode.length !== 6) { setError("Please enter the 6-digit code."); return; }
    setVerifying(true);
    setError("");
    try {
      const res = await fetch(`${import.meta.env.VITE_POCKETBASE_URL}/api/auth/verify-whatsapp-otp`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ phone: cleanPhone, code: otpCode }),
      });
      const data = await res.json();
      if (res.ok && data.ok) {
        setOtpVerified(true);
        await savePhone();
      } else {
        setError(data.message || "Invalid code. Please try again.");
      }
    } catch {
      setError(t("somethingWrong"));
    } finally { setVerifying(false); }
  };

  const savePhone = async () => {
    if (!user) return;
    setStep("saving");
    try {
      await pb.collection("users").update(user.id, { phone: cleanPhone });
      // Fire-and-forget: send WhatsApp welcome message via Meta Cloud API.
      // Navigation is NOT blocked by whether this succeeds or fails.
      fetch(`${import.meta.env.VITE_POCKETBASE_URL}/api/whatsapp/send-welcome`, {
        method: "POST",
        headers: { "Authorization": `Bearer ${pb.authStore.token}` },
      }).catch(() => {});
      navigate("/onboarding", { replace: true });
    } catch { setError(t("somethingWrong")); setStep("otp"); }
  };

  if (step === "otp") return (
    <div className="min-h-screen bg-cream bg-mesh flex items-center justify-center p-4">
      <div className="w-full max-w-sm fade-up">
        <div className="text-center mb-6">
          <div className="flex justify-center mb-3">
            <div className="w-16 h-16 rounded-full bg-green-100 flex items-center justify-center">
              <MessageCircle size={32} className="text-green-600" />
            </div>
          </div>
          <h1 className="text-2xl font-bold text-gray-800">Enter OTP</h1>
          <p className="text-gray-500 mt-1 text-sm">
            We sent a 6-digit code to your WhatsApp<br />
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
            {verifying ? "Verifying..." : <><ShieldCheck size={16} /> Verify Code</>}
          </button>
          <div className="flex items-center justify-between text-sm">
            <button onClick={() => { setStep("phone"); setOtpCode(""); setError(""); }}
              className="text-gray-400 hover:text-gray-600">← Back</button>
            <button onClick={sendOtp} disabled={cooldown > 0 || sendingOtp}
              className="flex items-center gap-1 text-violet-600 disabled:text-gray-300 transition-colors">
              <RefreshCw size={13} className={sendingOtp ? "animate-spin" : ""} />
              {cooldown > 0 ? `Resend in ${cooldown}s` : sendingOtp ? "Sending..." : "Resend OTP"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  if (step === "saving") return (
    <div className="min-h-screen bg-cream bg-mesh flex items-center justify-center">
      <div className="animate-spin rounded-full h-8 w-8 border-2 border-violet-500 border-t-transparent" />
    </div>
  );

  return (
    <div className="min-h-screen bg-cream bg-mesh flex items-center justify-center p-4">
      <div className="w-full max-w-sm fade-up">
        <div className="text-center mb-6">
          <div className="flex justify-center mb-3"><AppLogo size={64} /></div>
          <h1 className="text-2xl font-bold text-gray-800">{t("yourMobileNumber")}</h1>
          <p className="text-gray-500 mt-1 text-sm">{t("mobileRequired")}</p>
        </div>
        <div className="glass-strong rounded-3xl p-6 space-y-4">
          <div>
            <label className="text-sm font-semibold text-gray-700 block mb-1">{t("mobileNumber")}</label>
            <div className="flex items-center gap-2">
              <span className="text-xl shrink-0">🇲🇾</span>
              <input type="tel" value={phone} onChange={e => handlePhoneChange(e.target.value)}
                className={`glass-input w-full px-4 py-2.5 rounded-2xl outline-none text-sm ${error && !canSkipOtp ? "!border-rose-300" : ""}`}
                placeholder="+60123456789" />
            </div>
            <p className="text-gray-400 text-xs mt-1.5">{t("myPhoneFormat")}</p>
          </div>
          {error && <p className={`text-xs text-center leading-relaxed ${canSkipOtp ? "text-amber-600" : "text-rose-500"}`}>{error}</p>}
          <button onClick={sendOtp} disabled={sendingOtp || !isValidPhone}
            className="glass-btn w-full py-3 rounded-2xl text-white font-bold flex items-center justify-center gap-2">
            {sendingOtp ? "Sending..." : <><MessageCircle size={16} /> Verify via WhatsApp OTP</>}
          </button>
          {canSkipOtp && (
            <button onClick={savePhone}
              className="w-full py-2.5 text-sm text-gray-500 hover:text-gray-700 transition-colors border border-gray-200 rounded-2xl">
              Continue without verification
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
