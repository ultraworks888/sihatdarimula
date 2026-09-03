import { useState, useEffect } from "react";
import pb from "../../lib/pocketbase";
import { useLang } from "../../contexts/LanguageContext";
import { defaultVaccines } from "../../data/vaccines";

interface Props { childId: string; userId: string; childDob?: string }

function getAgeInMonths(dob: string): number {
  const birth = new Date(dob);
  const now = new Date();
  return (now.getFullYear() - birth.getFullYear()) * 12 + (now.getMonth() - birth.getMonth());
}

export default function ImmunisationTracker({ childId, userId, childDob }: Props) {
  const { t } = useLang();
  const [records, setRecords] = useState<Record<string, unknown>[]>([]);
  const [loading, setLoading] = useState(true);

  const fetch_ = async () => {
    const r = await pb.collection("immunisations").getFullList({
      filter: pb.filter("child = {:id}", { id: childId }), requestKey: null,
    });
    setRecords(r);
    setLoading(false);
  };
  useEffect(() => { fetch_(); }, [childId]);

  const isCompleted = (name: string) => records.some(r => r.vaccine_name === name && r.is_completed);

  const toggle = async (vaccineName: string, ageMonths: number) => {
    const existing = records.find(r => r.vaccine_name === vaccineName);
    if (existing) {
      await pb.collection("immunisations").update(String(existing.id), {
        is_completed: !existing.is_completed,
        completed_date: !existing.is_completed ? new Date().toISOString() : "",
      });
    } else {
      await pb.collection("immunisations").create({
        user: userId, child: childId, vaccine_name: vaccineName,
        age_months: ageMonths, is_completed: true, completed_date: new Date().toISOString(),
      });
    }
    await fetch_();
  };

  if (loading) return <div className="text-center py-8 text-gray-400">{t("loadingSchedule")}</div>;

  const ageMonths = childDob ? getAgeInMonths(childDob) : null;

  const getVaccineStatus = (vaccineAge: number) => {
    if (ageMonths === null) return null;
    if (ageMonths > vaccineAge + 1) return "overdue";
    if (ageMonths >= vaccineAge - 1 && ageMonths <= vaccineAge + 1) return "due_soon";
    return null;
  };

  const grouped = defaultVaccines.reduce<Record<number, typeof defaultVaccines>>((acc, v) => {
    if (!acc[v.ageMonths]) acc[v.ageMonths] = [];
    acc[v.ageMonths].push(v);
    return acc;
  }, {});

  const ageLabel = (m: number) => {
    if (m === 0) return t("atBirth");
    if (m < 12) return `${m} ${t("months")}`;
    const y = Math.floor(m / 12);
    const rem = m % 12;
    return rem > 0 ? `${y} ${t("year")} ${rem} ${t("months")}` : `${y} ${t(y > 1 ? "years" : "year")}`;
  };

  const total = defaultVaccines.length;
  const done = defaultVaccines.filter(v => isCompleted(v.name)).length;

  return (
    <div className="space-y-4">
      <div className="glass-strong rounded-3xl p-4">
        <h3 className="font-bold text-gray-800 mb-1">💉 {t("immunisationSchedule")}</h3>
        <p className="text-xs text-gray-500 mb-3">{t("tapToMark")}</p>
        <div className="flex items-center gap-3">
          <div className="flex-1 h-2 bg-gray-200/50 rounded-full overflow-hidden backdrop-blur-sm">
            <div className="h-full bg-emerald-500 rounded-full transition-all duration-500" style={{ width: `${(done / total) * 100}%` }} />
          </div>
          <span className="text-sm font-bold text-emerald-600">{done}/{total}</span>
        </div>
      </div>
      {Object.entries(grouped).sort(([a], [b]) => Number(a) - Number(b)).map(([age, vaccines]) => (
        <div key={age} className="glass rounded-3xl p-4">
          <h4 className="font-bold text-violet-600 text-sm mb-3">{ageLabel(Number(age))}</h4>
          <div className="space-y-2">
            {vaccines.map(v => {
              const d = isCompleted(v.name);
              const status = d ? null : getVaccineStatus(v.ageMonths);
              return (
                <button key={v.name} onClick={() => toggle(v.name, v.ageMonths)}
                  className={`w-full flex items-center gap-3 p-3 rounded-2xl text-left transition-all active:scale-[0.98] ${
                    d ? "bg-emerald-500/10" : status === "overdue" ? "bg-rose-500/10 ring-1 ring-rose-200/50" : status === "due_soon" ? "bg-amber-500/10 ring-1 ring-amber-200/50" : "bg-white/30 hover:bg-white/50"
                  }`}>
                  <span className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold shrink-0 ${d ? "bg-emerald-500 text-white" : "bg-gray-200/70 text-gray-400"}`}>
                    {d ? "✓" : ""}
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <p className={`text-sm font-semibold ${d ? "text-emerald-700 line-through" : "text-gray-800"}`}>{v.name}</p>
                      {status === "overdue" && (
                        <span className="bg-rose-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full">{t("overdueLabel")}</span>
                      )}
                      {status === "due_soon" && (
                        <span className="bg-amber-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full">{t("dueSoonLabel")}</span>
                      )}
                    </div>
                    <p className="text-xs text-gray-400">{v.description}</p>
                  </div>
                </button>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
