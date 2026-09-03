import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { useLang } from "../contexts/LanguageContext";
import pb from "../lib/pocketbase";
import AppLogo from "../components/AppLogo";

export default function Onboarding() {
  const { user } = useAuth();
  const { t } = useLang();
  const navigate = useNavigate();
  const [name, setName] = useState("");
  const [isBorn, setIsBorn] = useState(true);
  const [dob, setDob] = useState("");
  const [dueDate, setDueDate] = useState("");
  const [gender, setGender] = useState("boy");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!user) return;
    setLoading(true);
    setError("");
    try {
      await pb.collection("children").create({
        user: user.id, name, is_born: isBorn,
        date_of_birth: isBorn ? dob : "", due_date: !isBorn ? dueDate : "", gender,
      });
      navigate("/", { replace: true });
    } catch { setError(t("somethingWrong")); }
    finally { setLoading(false); }
  };

  return (
    <div className="min-h-screen bg-cream bg-mesh flex items-center justify-center p-4">
      <div className="w-full max-w-sm fade-up">
        <div className="text-center mb-6">
          <div className="flex justify-center mb-3">
            <AppLogo size={64} />
          </div>
          <h1 className="text-2xl font-bold text-gray-800">{t("welcomeTo")} {t("appName")}!</h1>
          <p className="text-gray-500 mt-1 text-sm">{t("tellUsAbout")}</p>
        </div>
        <form onSubmit={handleSubmit} className="glass-strong rounded-3xl p-6 space-y-4">
          <div>
            <label className="text-sm font-semibold text-gray-700 block mb-1">{t("childName")}</label>
            <input type="text" value={name} onChange={e => setName(e.target.value)} required
              className="glass-input w-full px-4 py-2.5 rounded-2xl outline-none text-sm"
              placeholder={t("babyNamePlaceholder")} />
          </div>
          <div>
            <label className="text-sm font-semibold text-gray-700 block mb-2">{t("status")}</label>
            <div className="flex gap-2">
              <button type="button" onClick={() => setIsBorn(true)}
                className={`flex-1 py-2.5 rounded-2xl text-sm font-semibold transition-all ${isBorn ? "glass-btn text-white" : "glass text-gray-600"}`}>
                {t("alreadyBorn")}
              </button>
              <button type="button" onClick={() => setIsBorn(false)}
                className={`flex-1 py-2.5 rounded-2xl text-sm font-semibold transition-all ${!isBorn ? "glass-btn text-white" : "glass text-gray-600"}`}>
                {t("expecting")}
              </button>
            </div>
          </div>
          {isBorn ? (
            <div>
              <label className="text-sm font-semibold text-gray-700 block mb-1">{t("dateOfBirth")}</label>
              <input type="date" value={dob} onChange={e => setDob(e.target.value)} required
                className="glass-input w-full px-4 py-2.5 rounded-2xl outline-none text-sm" />
            </div>
          ) : (
            <div>
              <label className="text-sm font-semibold text-gray-700 block mb-1">{t("dueDate")}</label>
              <input type="date" value={dueDate} onChange={e => setDueDate(e.target.value)} required
                className="glass-input w-full px-4 py-2.5 rounded-2xl outline-none text-sm" />
            </div>
          )}
          <div>
            <label className="text-sm font-semibold text-gray-700 block mb-2">{t("gender")}</label>
            <div className="flex gap-2">
              {([["boy", `👦 ${t("boy")}`], ["girl", `👧 ${t("girl")}`], ["other", `🌟 ${t("other")}`]] as const).map(([val, label]) => (
                <button key={val} type="button" onClick={() => setGender(val)}
                  className={`flex-1 py-2.5 rounded-2xl text-sm font-semibold transition-all ${gender === val ? "glass-btn text-white" : "glass text-gray-600"}`}>
                  {label}
                </button>
              ))}
            </div>
          </div>
          {error && <p className="text-rose-500 text-sm text-center">{error}</p>}
          <button type="submit" disabled={loading}
            className="glass-btn w-full py-3 rounded-2xl text-white font-bold">
            {loading ? t("adding") : `${t("getStarted")} 🎉`}
          </button>
        </form>
      </div>
    </div>
  );
}
