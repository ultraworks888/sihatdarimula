import { useState } from "react";
import { useSearchParams } from "react-router-dom";
import { useChild } from "../contexts/ChildContext";
import { useAuth } from "../contexts/AuthContext";
import { useLang } from "../contexts/LanguageContext";
import GrowthTracker from "../components/trackers/GrowthTracker";
import NutritionTracker from "../components/trackers/NutritionTracker";
import ActivityTracker from "../components/trackers/ActivityTracker";
import WellbeingTracker from "../components/trackers/WellbeingTracker";
import ImmunisationTracker from "../components/trackers/ImmunisationTracker";

export default function Track() {
  const [searchParams] = useSearchParams();
  const [active, setActive] = useState(searchParams.get("tab") || "growth");
  const { selectedChild } = useChild();
  const { user } = useAuth();
  const { t } = useLang();

  if (!selectedChild || !user) return null;

  const tabs = [
    { id: "growth", icon: "📏", label: t("trackGrowth") },
    { id: "nutrition", icon: "🍼", label: t("trackNutrition") },
    { id: "activity", icon: "🎯", label: t("trackActivity") },
    { id: "wellbeing", icon: "💜", label: t("trackWellbeing") },
    { id: "immunisation", icon: "💉", label: t("trackVaccines") },
  ];

  return (
    <div className="p-4 fade-up">
      <div className="flex gap-1.5 overflow-x-auto pb-3 mb-4 -mx-1 px-1">
        {tabs.map(tab => (
          <button key={tab.id} onClick={() => setActive(tab.id)}
            className={`flex items-center gap-1.5 px-3 py-2 rounded-2xl text-sm font-semibold whitespace-nowrap transition-all duration-200 ${
              active === tab.id ? "glass-btn text-white" : "glass text-gray-500 hover:text-gray-700"
            }`}>
            <span className="text-base">{tab.icon}</span> {tab.label}
          </button>
        ))}
      </div>
      {active === "growth" && <GrowthTracker childId={selectedChild.id} userId={user.id} childDob={selectedChild.date_of_birth} />}
      {active === "nutrition" && <NutritionTracker childId={selectedChild.id} userId={user.id} />}
      {active === "activity" && <ActivityTracker childId={selectedChild.id} userId={user.id} />}
      {active === "wellbeing" && <WellbeingTracker userId={user.id} />}
      {active === "immunisation" && <ImmunisationTracker childId={selectedChild.id} userId={user.id} childDob={selectedChild.date_of_birth} />}
    </div>
  );
}
