import { Link } from "react-router-dom";
import { useLang } from "../contexts/LanguageContext";
import AppLogo from "../components/AppLogo";

export default function NotFound() {
  const { t } = useLang();
  return (
    <div className="min-h-screen bg-cream bg-mesh flex items-center justify-center p-4">
      <div className="text-center fade-up">
        <div className="flex justify-center mb-4 opacity-40">
          <AppLogo size={80} />
        </div>
        <h1 className="text-2xl font-bold text-gray-800 mb-2">{t("pageNotFound")}</h1>
        <p className="text-gray-500 mb-6">{t("pageNotFoundDesc")}</p>
        <Link to="/" className="glass-btn inline-block px-6 py-3 rounded-2xl text-white font-bold">
          {t("goHome")}
        </Link>
      </div>
    </div>
  );
}
