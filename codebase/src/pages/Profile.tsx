import { useState, useEffect, useRef, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { useChild } from "../contexts/ChildContext";
import { useLang } from "../contexts/LanguageContext";
import type { Language } from "../i18n/translations";
import pb from "../lib/pocketbase";
import AppLogo from "../components/AppLogo";
import { Eye, EyeOff, KeyRound, ChevronDown, ChevronUp, Trophy, Star, X, Award, Share2, Download, Bell } from "lucide-react";
import html2canvas from "html2canvas";
import OneSignal from "react-onesignal";

const langOptions: { code: Language; flag: string; native: string }[] = [
  { code: "en", flag: "🇬🇧", native: "English" },
  { code: "ms", flag: "🇲🇾", native: "Bahasa Malaysia" },
  { code: "zh", flag: "🇨🇳", native: "中文" },
];

const categoryGradients: Record<string, string> = {
  parenting:     "from-violet-500 to-purple-600",
  nutrition:     "from-orange-400 to-amber-500",
  development:   "from-blue-500 to-cyan-500",
  wellbeing:     "from-teal-500 to-emerald-500",
  breastfeeding: "from-pink-500 to-rose-500",
  pregnancy:     "from-rose-400 to-pink-600",
};

interface CompletedEnrollment {
  id: string;
  updated: string;
  expand?: {
    course?: {
      id: string;
      title_en: string;
      title_ms?: string;
      title_zh?: string;
      category?: string;
      thumbnail?: string;
    };
  };
}

export default function Profile() {
  const { user, logout, updateUser } = useAuth();
  const { isAdmin, isSuperAdmin } = useAuth();
  const { children, removeChild, addChild } = useChild();
  const { t, lang, setLang } = useLang();
  const navigate = useNavigate();

  // Child form
  const [showAdd, setShowAdd] = useState(false);
  const [name, setName] = useState("");
  const [isBorn, setIsBorn] = useState(true);
  const [dob, setDob] = useState("");
  const [dueDate, setDueDate] = useState("");
  const [gender, setGender] = useState("boy");
  const [saving, setSaving] = useState(false);

  // Change password
  const [showChangePass, setShowChangePass] = useState(false);
  const [currentPass, setCurrentPass]   = useState("");
  const [newPass, setNewPass]           = useState("");
  const [confirmPass, setConfirmPass]   = useState("");
  const [showCurrent, setShowCurrent]   = useState(false);
  const [showNew, setShowNew]           = useState(false);
  const [showConfirm, setShowConfirm]   = useState(false);
  const [passError, setPassError]       = useState("");
  const [passSuccess, setPassSuccess]   = useState(false);
  const [changingPass, setChangingPass] = useState(false);

  // Achievements
  const [completedCourses, setCompletedCourses] = useState<CompletedEnrollment[]>([]);
  const [selectedCert, setSelectedCert] = useState<CompletedEnrollment | null>(null);
  const [sharing, setSharing] = useState(false);
  const certRef = useRef<HTMLDivElement>(null);

  // Push notifications
  const [pushPermission, setPushPermission] = useState<NotificationPermission>("default");
  const [pushEnabled, setPushEnabled] = useState(false);
  const [pushPrefsId, setPushPrefsId] = useState<string | null>(null);

  useEffect(() => {
    if (!user) return;
    pb.collection("enrollments").getFullList({
      filter: pb.filter("user = {:u} && is_completed = true", { u: user.id }),
      expand: "course",
      sort: "-updated",
      requestKey: null,
    }).then(res => setCompletedCourses(res as unknown as CompletedEnrollment[])).catch(() => {});
  }, [user]);

  // Push notification preference
  useEffect(() => {
    if (!user) return;
    if ("Notification" in window) setPushPermission(Notification.permission);
    pb.collection("notification_preferences").getFirstListItem(
      pb.filter("user = {:u}", { u: user.id }), { requestKey: null }
    ).then(pref => {
      setPushPrefsId(pref.id);
      setPushEnabled(Boolean(pref.push_enabled));
    }).catch(() => {});
  }, [user]);

  const handlePushToggle = async () => {
    if (!("Notification" in window)) return;
    if (pushPermission === "denied") {
      alert(t("pushDenied"));
      return;
    }
    try {
      if (pushEnabled) {
        await OneSignal.User.pushSubscription.optOut();
        if (pushPrefsId) {
          await pb.collection("notification_preferences").update(pushPrefsId, { push_enabled: false });
        }
        setPushEnabled(false);
      } else {
        await OneSignal.User.pushSubscription.optIn();
        const newPermission = Notification.permission;
        setPushPermission(newPermission);
        if (newPermission === "granted") {
          if (pushPrefsId) {
            await pb.collection("notification_preferences").update(pushPrefsId, { push_enabled: true });
          } else if (user) {
            const pref = await pb.collection("notification_preferences").create({ user: user.id, push_enabled: true });
            setPushPrefsId(pref.id);
          }
          setPushEnabled(true);
        }
      }
    } catch (err) {
      console.error("Push notification error:", err);
    }
  };

  const getCourseTitle = (enr: CompletedEnrollment) => {
    const c = enr.expand?.course;
    if (!c) return "—";
    if (lang !== "en") {
      const loc = (c as Record<string, unknown>)[`title_${lang}`];
      if (loc && String(loc).trim()) return String(loc);
    }
    return c.title_en || "—";
  };

  const formatDate = (iso: string) => {
    try {
      return new Date(iso).toLocaleDateString(
        lang === "ms" ? "ms-MY" : lang === "zh" ? "zh-CN" : "en-GB",
        { day: "numeric", month: "long", year: "numeric" }
      );
    } catch { return iso; }
  };

  const handleShareCert = async (mode: "share" | "save") => {
    if (!certRef.current || !selectedCert) return;
    setSharing(true);
    try {
      const canvas = await html2canvas(certRef.current, {
        scale: 3,
        useCORS: true,
        backgroundColor: "#fefce8",
        logging: false,
      });
      const blob = await new Promise<Blob>(res => canvas.toBlob(b => res(b!), "image/png", 1));
      const courseName = getCourseTitle(selectedCert).replace(/\s+/g, "_").slice(0, 40);
      const fileName = `certificate_${courseName}.png`;
      const file = new File([blob], fileName, { type: "image/png" });

      if (mode === "save") {
        // Always download
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url; a.download = fileName; a.click();
        URL.revokeObjectURL(url);
      } else {
        // Share via Web Share API (shows WhatsApp, etc. on mobile)
        if (navigator.canShare?.({ files: [file] })) {
          await navigator.share({
            files: [file],
            title: t("certificateOf"),
            text: `${t("congratulations")} ${t("certCompleted")} "${getCourseTitle(selectedCert)}" — ${t("appName")}`,
          });
        } else if (navigator.share) {
          // Text-only share fallback
          await navigator.share({
            title: t("certificateOf"),
            text: `${t("congratulations")} ${t("certCompleted")} "${getCourseTitle(selectedCert)}" — ${t("appName")}`,
          });
        } else {
          // Last resort: WhatsApp link
          const text = encodeURIComponent(
            `${t("congratulations")} ${t("certCompleted")} "${getCourseTitle(selectedCert)}" — ${t("appName")}`
          );
          window.open(`https://wa.me/?text=${text}`, "_blank");
        }
      }
    } finally {
      setSharing(false);
    }
  };

  const handleAdd = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      await addChild({ name, is_born: isBorn, date_of_birth: isBorn ? dob : "", due_date: !isBorn ? dueDate : "", gender });
      setShowAdd(false);
      setName(""); setDob(""); setDueDate("");
    } finally { setSaving(false); }
  };

  const handleLanguageChange = async (newLang: Language) => {
    setLang(newLang);
    try { await pb.collection("users").update(user!.id, { language: newLang }); } catch {}
  };

  const handleChangePassword = async (e: FormEvent) => {
    e.preventDefault();
    setPassError(""); setPassSuccess(false);
    if (newPass.length < 8) { setPassError(t("passwordTooShort")); return; }
    if (newPass !== confirmPass) { setPassError(t("passwordsNotMatch")); return; }
    setChangingPass(true);
    try {
      await pb.collection("users").update(user!.id, {
        oldPassword: currentPass,
        password: newPass,
        passwordConfirm: confirmPass,
      });
      setPassSuccess(true);
      setCurrentPass(""); setNewPass(""); setConfirmPass("");
      setTimeout(() => { setPassSuccess(false); setShowChangePass(false); }, 3000);
    } catch {
      setPassError(t("wrongPassword"));
    } finally { setChangingPass(false); }
  };

  return (
    <>
    <div className="p-4 space-y-5 fade-up pb-8">
      {/* User info */}
      <div className="glass-strong rounded-3xl p-5 text-center">
        <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl mx-auto border border-white/30" style={{
          background: "linear-gradient(135deg, rgba(139,92,246,0.7), rgba(244,114,182,0.7))",
          backdropFilter: "blur(12px)",
          boxShadow: "0 4px 16px rgba(139,92,246,0.2)",
        }}>🤱</div>
        <h2 className="font-bold text-gray-800 mt-3 text-lg">{user?.name || "Mom"}</h2>
        <p className="text-gray-500 text-sm">{user?.email}</p>
        {user?.phone && <p className="text-gray-400 text-xs mt-1">🇲🇾 {user.phone}</p>}
      </div>

      {/* ── Achievements ── */}
      <div>
        <div className="flex items-center gap-2 mb-3">
          <Trophy size={18} className="text-amber-500" />
          <h3 className="font-bold text-gray-800">{t("achievements")}</h3>
          {completedCourses.length > 0 && (
            <span className="ml-auto text-xs font-bold text-amber-600 bg-amber-50 px-2.5 py-0.5 rounded-full">
              {completedCourses.length}
            </span>
          )}
        </div>

        {completedCourses.length === 0 ? (
          <div className="glass rounded-3xl p-5 text-center">
            <Award size={36} className="text-gray-300 mx-auto mb-2" />
            <p className="text-gray-400 text-sm leading-relaxed">{t("noCertificates")}</p>
          </div>
        ) : (
          <div className="flex gap-3 overflow-x-auto pb-1 -mx-1 px-1 snap-x snap-mandatory">
            {completedCourses.map(enr => {
              const cat = enr.expand?.course?.category ?? "parenting";
              const grad = categoryGradients[cat] ?? categoryGradients.parenting;
              return (
                <button key={enr.id} onClick={() => setSelectedCert(enr)}
                  className={`snap-start shrink-0 w-44 rounded-3xl bg-gradient-to-br ${grad} p-4 flex flex-col items-start gap-2 shadow-lg active:scale-95 transition-transform`}>
                  {/* Badge */}
                  <div className="w-10 h-10 rounded-2xl bg-white/20 flex items-center justify-center">
                    <Trophy size={20} className="text-white" />
                  </div>
                  {/* Stars */}
                  <div className="flex gap-0.5">
                    {[0,1,2].map(i => <Star key={i} size={10} className="text-yellow-200 fill-yellow-200" />)}
                  </div>
                  {/* Title */}
                  <p className="text-white font-bold text-xs leading-snug line-clamp-3 text-left">
                    {getCourseTitle(enr)}
                  </p>
                  {/* Date */}
                  <p className="text-white/60 text-[10px] mt-auto">
                    {formatDate(enr.updated)}
                  </p>
                </button>
              );
            })}
          </div>
        )}
      </div>

      {/* Settings */}
      <div className="glass rounded-3xl p-4">
        <h3 className="font-bold text-gray-800 mb-3">{t("settings")}</h3>
        <div className="space-y-3">
          <div>
            <label className="text-sm font-semibold text-gray-600 block mb-2">{t("language")}</label>
            <div className="flex gap-2">
              {langOptions.map(l => (
                <button key={l.code} onClick={() => handleLanguageChange(l.code)}
                  className={`flex-1 flex items-center justify-center gap-1.5 py-2 rounded-2xl text-xs font-semibold transition-all duration-200 ${
                    lang === l.code
                      ? "glass-btn !py-2 text-white"
                      : "glass text-gray-600 hover:scale-[1.03]"
                  }`}>
                  <span>{l.flag}</span> {l.native}
                </button>
              ))}
            </div>
          </div>
          <div className="flex items-center justify-between py-2 border-t border-white/30">
            <span className="text-sm text-gray-600 font-medium">🇲🇾 {t("phone")}</span>
            <span className="text-sm text-gray-800">{user?.phone || "—"}</span>
          </div>

          {/* Change Password */}
          <div className="border-t border-white/30">
            <button onClick={() => { setShowChangePass(v => !v); setPassError(""); setPassSuccess(false); }}
              className="w-full flex items-center justify-between py-2.5 group">
              <div className="flex items-center gap-2">
                <KeyRound size={16} className="text-gray-500" />
                <span className="text-sm font-semibold text-gray-700">{t("changePassword")}</span>
              </div>
              {showChangePass ? <ChevronUp size={16} className="text-gray-400" /> : <ChevronDown size={16} className="text-gray-400" />}
            </button>
            {showChangePass && (
              <form onSubmit={handleChangePassword} className="pb-2 space-y-3">
                <div className="relative">
                  <input type={showCurrent ? "text" : "password"} value={currentPass}
                    onChange={e => { setCurrentPass(e.target.value); setPassError(""); }}
                    placeholder={t("currentPassword")} required
                    className="glass-input w-full px-3 py-2.5 pr-10 rounded-2xl text-sm outline-none" />
                  <button type="button" onClick={() => setShowCurrent(v => !v)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-violet-500 transition-colors">
                    {showCurrent ? <EyeOff size={15} /> : <Eye size={15} />}
                  </button>
                </div>
                <div className="relative">
                  <input type={showNew ? "text" : "password"} value={newPass}
                    onChange={e => { setNewPass(e.target.value); setPassError(""); }}
                    placeholder={t("newPassword")} required
                    className="glass-input w-full px-3 py-2.5 pr-10 rounded-2xl text-sm outline-none" />
                  <button type="button" onClick={() => setShowNew(v => !v)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-violet-500 transition-colors">
                    {showNew ? <EyeOff size={15} /> : <Eye size={15} />}
                  </button>
                </div>
                <div className="relative">
                  <input type={showConfirm ? "text" : "password"} value={confirmPass}
                    onChange={e => { setConfirmPass(e.target.value); setPassError(""); }}
                    placeholder={t("confirmNewPassword")} required
                    className="glass-input w-full px-3 py-2.5 pr-10 rounded-2xl text-sm outline-none" />
                  <button type="button" onClick={() => setShowConfirm(v => !v)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-violet-500 transition-colors">
                    {showConfirm ? <EyeOff size={15} /> : <Eye size={15} />}
                  </button>
                </div>
                {passError && <p className="text-rose-500 text-xs text-center">{passError}</p>}
                {passSuccess && <p className="text-emerald-600 text-xs text-center font-semibold">{t("passwordChanged")}</p>}
                <button type="submit" disabled={changingPass || !currentPass || !newPass || !confirmPass}
                  className="glass-btn w-full py-2.5 rounded-2xl text-white font-bold text-sm">
                  {changingPass ? t("saving") : t("changePassword")}
                </button>
              </form>
            )}
          </div>

          {isAdmin && (
            <button onClick={() => navigate("/admin")}
              className="w-full flex items-center justify-between py-2.5 border-t border-white/30 group">
              <div className="flex items-center gap-2">
                <span className="text-lg">🛡️</span>
                <div className="text-left">
                  <span className="text-sm font-bold text-violet-700">Admin Dashboard</span>
                  <p className="text-[10px] text-violet-400/70">{isSuperAdmin ? "Super Admin" : "Admin"} · Manage app</p>
                </div>
              </div>
              <span className="text-gray-400 group-hover:text-violet-500 transition">→</span>
            </button>
          )}
          <button onClick={() => navigate("/notifications")}
            className="w-full flex items-center justify-between py-2.5 border-t border-white/30 group">
            <div className="flex items-center gap-2">
              <span className="text-lg">🔔</span>
              <span className="text-sm font-semibold text-gray-700">{t("notifications")}</span>
            </div>
            <span className="text-gray-400 group-hover:text-violet-500 transition">→</span>
          </button>
          <button onClick={() => navigate("/notification-history")}
            className="w-full flex items-center justify-between py-2.5 border-t border-white/30 group">
            <div className="flex items-center gap-2">
              <span className="text-lg">📨</span>
              <span className="text-sm font-semibold text-gray-700">{t("messageHistory")}</span>
            </div>
            <span className="text-gray-400 group-hover:text-violet-500 transition">→</span>
          </button>

          {/* Push Notifications toggle */}
          {"Notification" in window && (
            <div className="flex items-center justify-between py-3 border-t border-white/30">
              <div className="flex items-center gap-2.5 min-w-0 mr-3">
                <Bell size={16} className={pushEnabled && pushPermission === "granted" ? "text-violet-500" : "text-gray-400"} />
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-gray-700">{t("pushNotifications")}</p>
                  <p className="text-[10px] text-gray-400 leading-snug mt-0.5">
                    {pushPermission === "denied" ? t("pushBlockedLabel") : t("pushDesc")}
                  </p>
                </div>
              </div>
              <button
                onClick={handlePushToggle}
                disabled={pushPermission === "denied"}
                className={`shrink-0 px-3.5 py-1.5 rounded-full text-xs font-bold transition-all ${
                  pushEnabled && pushPermission === "granted"
                    ? "bg-violet-100 text-violet-700"
                    : pushPermission === "denied"
                    ? "bg-gray-100 text-gray-400 cursor-not-allowed"
                    : "glass-btn text-white !py-1.5"
                }`}
              >
                {pushEnabled && pushPermission === "granted" ? t("pushEnabledLabel") : t("enable")}
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Children */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-bold text-gray-800">{t("myChildren")}</h3>
          <button onClick={() => setShowAdd(!showAdd)} className="text-violet-600 text-sm font-bold">
            {showAdd ? t("cancel") : t("addChild")}
          </button>
        </div>
        {showAdd && (
          <form onSubmit={handleAdd} className="glass-strong rounded-3xl p-4 space-y-3 mb-3">
            <input type="text" value={name} onChange={e => setName(e.target.value)} required placeholder={t("babyNamePlaceholder")}
              className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
            <div className="flex gap-2">
              <button type="button" onClick={() => setIsBorn(true)}
                className={`flex-1 py-2 rounded-2xl text-xs font-semibold transition-all ${isBorn ? "glass-btn text-white !py-2" : "glass text-gray-600"}`}>{t("born")}</button>
              <button type="button" onClick={() => setIsBorn(false)}
                className={`flex-1 py-2 rounded-2xl text-xs font-semibold transition-all ${!isBorn ? "glass-btn text-white !py-2" : "glass text-gray-600"}`}>{t("expecting")}</button>
            </div>
            {isBorn ? (
              <input type="date" value={dob} onChange={e => setDob(e.target.value)} required
                className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
            ) : (
              <input type="date" value={dueDate} onChange={e => setDueDate(e.target.value)} required
                className="glass-input w-full px-3 py-2 rounded-2xl text-sm outline-none" />
            )}
            <div className="flex gap-2">
              {([["boy", `👦 ${t("boy")}`], ["girl", `👧 ${t("girl")}`], ["other", `🌟 ${t("other")}`]] as const).map(([v, label]) => (
                <button key={v} type="button" onClick={() => setGender(v)}
                  className={`flex-1 py-2 rounded-2xl text-xs font-semibold transition-all ${gender === v ? "glass-btn text-white !py-2" : "glass text-gray-600"}`}>{label}</button>
              ))}
            </div>
            <button type="submit" disabled={saving}
              className="glass-btn w-full py-2.5 rounded-2xl text-white font-bold text-sm">{saving ? t("adding") : t("addChild")}</button>
          </form>
        )}
        <div className="space-y-2">
          {children.map(child => (
            <div key={child.id} className="glass rounded-2xl p-4 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <span className="text-2xl">{child.is_born ? (child.gender === "girl" ? "👧" : "👦") : "🤰"}</span>
                <div>
                  <p className="font-bold text-gray-800">{child.name}</p>
                  <p className="text-xs text-gray-500">
                    {child.is_born ? `${t("born")}: ${new Date(child.date_of_birth).toLocaleDateString()}` : `${t("dueDate")}: ${new Date(child.due_date).toLocaleDateString()}`}
                  </p>
                </div>
              </div>
              {children.length > 1 && (
                <button onClick={() => { if (confirm(`${t("remove")} ${child.name}? ${t("removeConfirm")}`)) removeChild(child.id); }}
                  className="text-rose-400 text-xs font-bold">{t("remove")}</button>
              )}
            </div>
          ))}
        </div>
      </div>

      <div className="glass rounded-3xl p-4">
        <div className="flex items-center gap-3 mb-2">
          <AppLogo size={40} />
          <div>
            <h4 className="font-bold text-violet-800 text-sm">{t("appName")}</h4>
            <p className="text-violet-500 text-[11px]">{t("appNameAlt")}</p>
          </div>
        </div>
        <p className="text-gray-600 text-xs leading-relaxed">{t("aboutDescription")}</p>
      </div>

      <button onClick={() => { logout(); navigate("/login", { replace: true }); }}
        className="glass w-full py-3 rounded-2xl text-gray-600 font-bold text-sm hover:scale-[1.01] active:scale-[0.99] transition-all">
        {t("signOut")}
      </button>
    </div>

    {/* ── Certificate Modal ── */}
    {selectedCert && (
      <div className="fixed inset-0 z-50 flex items-center justify-center p-5 bg-black/60 backdrop-blur-sm"
        onClick={() => setSelectedCert(null)}>
        <div onClick={e => e.stopPropagation()}
          className="relative w-full max-w-sm rounded-3xl overflow-hidden shadow-2xl"
          style={{ background: "linear-gradient(160deg, #fefce8 0%, #fff7ed 50%, #fdf4ff 100%)" }}>

          {/* Close */}
          <button onClick={() => setSelectedCert(null)}
            className="absolute top-4 right-4 z-10 w-8 h-8 rounded-full bg-black/10 flex items-center justify-center hover:bg-black/20 transition-colors">
            <X size={16} className="text-gray-600" />
          </button>

          {/* Capturable certificate area */}
          <div ref={certRef} style={{ background: "linear-gradient(160deg, #fefce8 0%, #fff7ed 50%, #fdf4ff 100%)" }}>
            {/* Top gradient band */}
            <div className={`h-2 w-full bg-gradient-to-r ${categoryGradients[selectedCert.expand?.course?.category ?? "parenting"] ?? categoryGradients.parenting}`} />

            <div className="p-7 flex flex-col items-center text-center">
              {/* App logo + title */}
              <AppLogo size={48} />
              <p className="text-[10px] font-black uppercase tracking-[0.2em] text-gray-400 mt-3 mb-1">
                {t("appName")}
              </p>

              {/* Decorative divider */}
              <div className="flex items-center gap-2 w-full my-3">
                <div className="flex-1 h-px bg-amber-200" />
                <Star size={12} className="text-amber-400 fill-amber-400 shrink-0" />
                <Trophy size={14} className="text-amber-500 shrink-0" />
                <Star size={12} className="text-amber-400 fill-amber-400 shrink-0" />
                <div className="flex-1 h-px bg-amber-200" />
              </div>

              {/* Certificate heading */}
              <h2 className="font-black text-gray-800 text-lg tracking-wide uppercase mb-4">
                {t("certificateOf")}
              </h2>

              {/* Certify text */}
              <p className="text-gray-500 text-xs mb-1">{t("certCertify")}</p>
              <p className="font-black text-2xl text-violet-700 leading-tight mb-1">
                {user?.name || "—"}
              </p>
              <p className="text-gray-500 text-xs mb-3">{t("certCompleted")}</p>

              {/* Course name banner */}
              <div className={`w-full rounded-2xl bg-gradient-to-br ${categoryGradients[selectedCert.expand?.course?.category ?? "parenting"]} p-4 mb-5`}>
                <p className="text-white font-black text-base leading-snug">
                  {getCourseTitle(selectedCert)}
                </p>
              </div>

              {/* Stars row */}
              <div className="flex gap-1.5 mb-5">
                {[0,1,2,3,4].map(i => <Star key={i} size={16} className="text-amber-400 fill-amber-400" />)}
              </div>

              {/* Bottom divider */}
              <div className="flex items-center gap-2 w-full mb-4">
                <div className="flex-1 h-px bg-amber-200" />
                <Award size={12} className="text-amber-400 shrink-0" />
                <div className="flex-1 h-px bg-amber-200" />
              </div>

              {/* Completion date */}
              <p className="text-gray-400 text-[11px]">
                {t("completedOn")} {formatDate(selectedCert.updated)}
              </p>
            </div>

            {/* Bottom gradient band */}
            <div className={`h-2 w-full bg-gradient-to-r ${categoryGradients[selectedCert.expand?.course?.category ?? "parenting"] ?? categoryGradients.parenting}`} />
          </div>{/* end certRef */}

          {/* Share / Save buttons — outside the captured area */}
          <div className="flex gap-3 p-4">
            <button onClick={() => handleShareCert("share")} disabled={sharing}
              className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-2xl font-bold text-sm text-white transition-all active:scale-95 disabled:opacity-60
                bg-gradient-to-r ${categoryGradients[selectedCert.expand?.course?.category ?? "parenting"]}`}>
              <Share2 size={16} />
              {sharing ? t("generating") : t("shareAchievement")}
            </button>
            <button onClick={() => handleShareCert("save")} disabled={sharing}
              className="flex items-center justify-center gap-2 px-4 py-3 rounded-2xl font-bold text-sm bg-gray-100 text-gray-700 active:scale-95 disabled:opacity-60 transition-all">
              <Download size={16} />
              {t("saveAsImage")}
            </button>
          </div>
        </div>
      </div>
    )}
    </>
  );
}
